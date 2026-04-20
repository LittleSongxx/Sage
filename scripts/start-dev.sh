#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs/dev"
RUN_DIR="$LOG_DIR/run"
SERVER_LOG="$LOG_DIR/server.log"
FRONTEND_LOG="$LOG_DIR/frontend.log"
SERVER_PID_FILE="$RUN_DIR/server.pid"
FRONTEND_PID_FILE="$RUN_DIR/frontend.pid"

mkdir -p "$RUN_DIR"

USE_UV="${USE_UV:-0}"
USE_UV="$(printf '%s' "$USE_UV" | tr '[:upper:]' '[:lower:]')"
CONDA_ENV_NAME="${CONDA_ENV_NAME:-sage}"
PYTHON_CMD=""
PYTHON_SOURCE=""
TOTAL_STAGES=6
CURRENT_STAGE="Initializing"
STAGE_INDEX=0

print_banner() {
    printf '\nSage dev startup\n'
    printf 'Project root: %s\n' "$PROJECT_ROOT"
}

start_stage() {
    STAGE_INDEX=$((STAGE_INDEX + 1))
    CURRENT_STAGE="$1"
    printf '\n[%d/%d] %s\n' "$STAGE_INDEX" "$TOTAL_STAGES" "$CURRENT_STAGE"
}

log_info() {
    printf '  - %s\n' "$1"
}

log_ok() {
    printf '  [ok] %s\n' "$1"
}

log_warn() {
    printf '  [warn] %s\n' "$1"
}

log_fail() {
    printf '  [fail] %s\n' "$1" >&2
}

begin_wait() {
    printf '  - %s' "$1"
}

wait_tick() {
    printf '.'
}

end_wait() {
    printf ' %s\n' "$1"
}

print_link() {
    printf '  %s: %s\n' "$1" "$2"
}

setup_python_runtime() {
    if [ -n "${PYTHON_BIN:-}" ]; then
        PYTHON_CMD="$PYTHON_BIN"
        PYTHON_SOURCE="PYTHON_BIN"
        return 0
    fi

    if [ "${CONDA_DEFAULT_ENV:-}" = "$CONDA_ENV_NAME" ] && command -v python >/dev/null 2>&1; then
        PYTHON_CMD="python"
        PYTHON_SOURCE="active conda env ($CONDA_ENV_NAME)"
        return 0
    fi

    if command -v conda >/dev/null 2>&1; then
        local conda_base conda_sh
        conda_base="$(conda info --base 2>/dev/null || true)"
        conda_sh="${conda_base%/}/etc/profile.d/conda.sh"
        if [ -n "$conda_base" ] && [ -f "$conda_sh" ]; then
            set +u
            . "$conda_sh"
            if conda activate "$CONDA_ENV_NAME" >/dev/null 2>&1; then
                set -u
                PYTHON_CMD="python"
                PYTHON_SOURCE="conda env ($CONDA_ENV_NAME)"
                return 0
            fi
            set -u
        fi
        echo "Failed to activate conda environment: $CONDA_ENV_NAME"
        echo "Set PYTHON_BIN explicitly if you want to use a different Python."
        exit 1
    fi

    if [ -n "${VIRTUAL_ENV:-}" ] && command -v python >/dev/null 2>&1; then
        PYTHON_CMD="python"
        PYTHON_SOURCE="active virtualenv"
        return 0
    fi
    if command -v python >/dev/null 2>&1; then
        PYTHON_CMD="python"
        PYTHON_SOURCE="python on PATH"
        return 0
    fi
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_CMD="python3"
        PYTHON_SOURCE="python3 on PATH"
        return 0
    fi

    echo "Python not found. Set PYTHON_BIN or install Python >= 3.10."
    exit 1
}

normalize_bool() {
    printf '%s' "${1:-0}" | tr '[:upper:]' '[:lower:]'
}

normalize_base_path() {
    local raw="${1:-/sage/}"
    if [ -z "$raw" ] || [ "$raw" = "/" ]; then
        printf '/'
        return
    fi
    raw="${raw#/}"
    raw="${raw%/}"
    printf '/%s/' "$raw"
}

is_pid_running() {
    local pid_file="$1"
    if [ ! -f "$pid_file" ]; then
        return 1
    fi
    local pid
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [ -z "$pid" ]; then
        return 1
    fi
    kill -0 "$pid" 2>/dev/null
}

cleanup_stale_pid() {
    local pid_file="$1"
    if [ -f "$pid_file" ] && ! is_pid_running "$pid_file"; then
        rm -f "$pid_file"
    fi
}

split_host_port_from_url() {
    local input="$1"
    local without_scheme="${input#*://}"
    local host_port="${without_scheme%%/*}"
    local host="${host_port%%:*}"
    local port="${host_port##*:}"
    printf '%s %s\n' "$host" "$port"
}

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_fail "Missing required command: $cmd"
        exit 1
    fi
}

require_python_version() {
    local version major minor
    version="$($PYTHON_CMD --version 2>&1 | awk '{print $2}')"
    major="$(printf '%s' "$version" | cut -d. -f1)"
    minor="$(printf '%s' "$version" | cut -d. -f2)"
    if [ "$major" -lt 3 ] || { [ "$major" -eq 3 ] && [ "$minor" -lt 10 ]; }; then
        log_fail "Python version must be >= 3.10, current: $version"
        exit 1
    fi
    log_ok "Python: $version ($PYTHON_SOURCE)"
}

require_node_version() {
    local version major
    version="$(node --version 2>&1 | sed 's/^v//')"
    major="$(printf '%s' "$version" | cut -d. -f1)"
    if [ "$major" -lt 18 ]; then
        log_fail "Node.js version must be >= 18, current: $version"
        exit 1
    fi
    log_ok "Node.js: $version"
}

load_project_env() {
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        log_fail "Missing $PROJECT_ROOT/.env"
        exit 1
    fi
    set -a
    . "$PROJECT_ROOT/.env"
    set +a
    log_ok "Loaded $PROJECT_ROOT/.env"
}

ensure_python_dependencies() {
    if [ "$USE_UV" = "1" ] || [ "$USE_UV" = "true" ] || [ "$USE_UV" = "yes" ]; then
        require_command uv
        FASTAPI_CHECK_CMD=(uv run --python "$PYTHON_CMD" python -c "import fastapi, uvicorn")
        INSTALL_CMD=(uv pip install --python "$PYTHON_CMD" -r requirements.txt --index-url https://mirrors.aliyun.com/pypi/simple/)
        SERVER_CMD=(uv run --python "$PYTHON_CMD" python -m app.server.main)
    else
        FASTAPI_CHECK_CMD=("$PYTHON_CMD" -c "import fastapi, uvicorn")
        INSTALL_CMD=("$PYTHON_CMD" -m pip install -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com)
        SERVER_CMD=("$PYTHON_CMD" -m app.server.main)
    fi

    if ! "${FASTAPI_CHECK_CMD[@]}" >/dev/null 2>&1; then
        log_info "Installing Python dependencies"
        "${INSTALL_CMD[@]}"
        log_ok "Python dependencies installed"
    else
        log_ok "Python dependencies already available"
    fi
}

ensure_frontend_dependencies() {
    if [ ! -d "$PROJECT_ROOT/app/server/web/node_modules" ]; then
        log_info "Installing frontend dependencies"
        (
            cd "$PROJECT_ROOT/app/server/web"
            npm install
        )
        log_ok "Frontend dependencies installed"
    else
        log_ok "Frontend dependencies already available"
    fi
}

require_tcp_service() {
    local host="$1"
    local port="$2"
    local name="$3"
    begin_wait "Checking $name ($host:$port)"
    if ! timeout 2 bash -lc "</dev/tcp/$host/$port" >/dev/null 2>&1; then
        end_wait "failed"
        log_fail "$name is not reachable at $host:$port"
        exit 1
    fi
    end_wait "ok"
}

curl_local() {
    local url="$1"
    local timeout_seconds="${2:-3}"
    curl --noproxy "*" -fsS --max-time "$timeout_seconds" "$url"
}

is_tcp_port_open() {
    local host="$1"
    local port="$2"
    timeout 2 bash -lc "</dev/tcp/$host/$port" >/dev/null 2>&1
}

find_available_local_port() {
    local host="$1"
    local start_port="$2"
    local label="$3"
    local max_attempts="${4:-50}"
    local port="$start_port"
    local attempts=0
    while [ "$attempts" -lt "$max_attempts" ]; do
        if ! is_tcp_port_open "$host" "$port"; then
            printf '%s\n' "$port"
            return 0
        fi
        port=$((port + 1))
        attempts=$((attempts + 1))
    done
    log_fail "Could not find an available local port for $label starting from $start_port"
    exit 1
}

is_sage_backend_response() {
    local url="$1"
    local response
    response="$(curl_local "$url/api/health" 3 2>/dev/null || true)"
    if [ -z "$response" ]; then
        return 1
    fi
    printf '%s' "$response" | grep -q '"status"' &&
        printf '%s' "$response" | grep -q '"timestamp"' &&
        printf '%s' "$response" | grep -q '"service"'
}

require_http_service() {
    local url="$1"
    local name="$2"
    local max_wait="${3:-60}"
    begin_wait "Waiting for $name ($url)"
    for _ in $(seq 1 "$max_wait"); do
        if curl_local "$url" 3 >/dev/null 2>&1; then
            end_wait "ok"
            return 0
        fi
        wait_tick
        sleep 1
    done
    end_wait "failed"
    log_fail "$name is not reachable at $url"
    exit 1
}

warn_tcp_service() {
    local host="$1"
    local port="$2"
    local name="$3"
    if ! timeout 2 bash -lc "</dev/tcp/$host/$port" >/dev/null 2>&1; then
        log_warn "$name is not reachable at $host:$port"
    else
        log_ok "$name is reachable at $host:$port"
    fi
}

stop_process_group() {
    local pid_file="$1"
    local label="$2"
    if [ ! -f "$pid_file" ]; then
        return 0
    fi
    local pid
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [ -z "$pid" ]; then
        rm -f "$pid_file"
        return 0
    fi
    if ! kill -0 "$pid" >/dev/null 2>&1; then
        rm -f "$pid_file"
        return 0
    fi
    kill -TERM -- "-$pid" >/dev/null 2>&1 || kill -TERM "$pid" >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        if ! kill -0 "$pid" >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done
    if kill -0 "$pid" >/dev/null 2>&1; then
        kill -KILL -- "-$pid" >/dev/null 2>&1 || kill -KILL "$pid" >/dev/null 2>&1 || true
    fi
    rm -f "$pid_file"
    echo "Stopped $label"
}

wait_for_backend() {
    local url="$1"
    local pid="$2"
    begin_wait "Waiting for backend health ($url/api/health)"
    for _ in $(seq 1 60); do
        if is_sage_backend_response "$url"; then
            end_wait "ok"
            return 0
        fi
        if ! kill -0 "$pid" >/dev/null 2>&1; then
            end_wait "failed"
            return 1
        fi
        wait_tick
        sleep 1
    done
    end_wait "failed"
    return 1
}

wait_for_frontend() {
    local port="$1"
    local base_path="$2"
    local pid="$3"
    begin_wait "Waiting for frontend page (http://127.0.0.1:${port}${base_path})"
    for _ in $(seq 1 60); do
        if curl_local "http://127.0.0.1:${port}${base_path}" 3 >/dev/null 2>&1; then
            end_wait "ok"
            return 0
        fi
        if [ "$base_path" != "/" ] && curl_local "http://127.0.0.1:${port}/" 3 >/dev/null 2>&1; then
            end_wait "ok"
            return 0
        fi
        if ! kill -0 "$pid" >/dev/null 2>&1; then
            end_wait "failed"
            return 1
        fi
        wait_tick
        sleep 1
    done
    end_wait "failed"
    return 1
}

print_banner

start_stage "Checking existing local services"
cleanup_stale_pid "$SERVER_PID_FILE"
cleanup_stale_pid "$FRONTEND_PID_FILE"

if is_pid_running "$SERVER_PID_FILE" || is_pid_running "$FRONTEND_PID_FILE"; then
    log_fail "Existing dev processes detected. Run $PROJECT_ROOT/scripts/stop-dev.sh first."
    exit 1
fi
log_ok "No conflicting local Sage dev processes found"

start_stage "Preparing runtime"
require_command curl
require_command node
require_command npm
require_command timeout
setup_python_runtime
require_python_version
require_node_version

start_stage "Loading project environment"
cd "$PROJECT_ROOT"
load_project_env
ensure_python_dependencies
ensure_frontend_dependencies

BACKEND_PORT="${BACKEND_PORT:-${SAGE_PORT:-8080}}"
FRONTEND_PORT="${FRONTEND_PORT:-5173}"
FRONTEND_BASE_PATH="$(normalize_base_path "${FRONTEND_BASE_PATH:-${VITE_SAGE_WEB_BASE_PATH:-/sage/}}")"
FRONTEND_API_PREFIX="${FRONTEND_API_PREFIX:-${VITE_BACKEND_API_PREFIX:-/dev-api}}"
FRONTEND_TRACE_URL="${FRONTEND_TRACE_URL:-${VITE_SAGE_TRACE_WEB_URL:-http://127.0.0.1:30051/jaeger/}}"
MYSQL_HOST_RUNTIME="${SAGE_MYSQL_HOST_OVERRIDE:-127.0.0.1}"
MYSQL_PORT_RUNTIME="${SAGE_MYSQL_PORT_OVERRIDE:-30052}"
ES_URL_RUNTIME="${SAGE_ELASTICSEARCH_URL_OVERRIDE:-http://127.0.0.1:30053}"
S3_ENDPOINT_RUNTIME="${SAGE_S3_ENDPOINT_OVERRIDE:-http://127.0.0.1:30054}"
JAEGER_ENDPOINT_RUNTIME="${SAGE_TRACE_JAEGER_URL_OVERRIDE:-http://127.0.0.1:4317}"
JAEGER_PUBLIC_RUNTIME="${SAGE_TRACE_JAEGER_PUBLIC_URL_OVERRIDE:-${SAGE_TRACE_JAEGER_PUBLIC_URL:-http://127.0.0.1:30051/jaeger}}"
EMBEDDING_BASE_RUNTIME="${SAGE_EMBEDDING_BASE_URL_OVERRIDE:-${SAGE_EMBEDDING_BASE_URL:-}}"

if [ -z "${SAGE_EMBEDDING_BASE_URL_OVERRIDE:-}" ] && { [ -z "$EMBEDDING_BASE_RUNTIME" ] || printf '%s' "$EMBEDDING_BASE_RUNTIME" | grep -q 'sage-embedding'; }; then
    EMBEDDING_BASE_RUNTIME="http://127.0.0.1:30056/v1"
fi

if is_sage_backend_response "http://127.0.0.1:${BACKEND_PORT}"; then
    log_fail "Sage backend already responds at http://127.0.0.1:${BACKEND_PORT}"
    exit 1
fi

if is_tcp_port_open "127.0.0.1" "$BACKEND_PORT"; then
    original_backend_port="$BACKEND_PORT"
    BACKEND_PORT="$(find_available_local_port "127.0.0.1" $((BACKEND_PORT + 1)) "backend")"
    log_warn "Backend port $original_backend_port is already in use by another local service; switching to $BACKEND_PORT"
fi

if is_tcp_port_open "127.0.0.1" "$FRONTEND_PORT"; then
    original_frontend_port="$FRONTEND_PORT"
    FRONTEND_PORT="$(find_available_local_port "127.0.0.1" $((FRONTEND_PORT + 1)) "frontend")"
    log_warn "Frontend port $original_frontend_port is already in use by another local service; switching to $FRONTEND_PORT"
fi

BACKEND_URL="http://127.0.0.1:${BACKEND_PORT}"
FRONTEND_URL="http://127.0.0.1:${FRONTEND_PORT}${FRONTEND_BASE_PATH}"

start_stage "Checking Docker-backed dependencies"
export SAGE_PORT="$BACKEND_PORT"
export SAGE_MYSQL_HOST="$MYSQL_HOST_RUNTIME"
export SAGE_MYSQL_PORT="$MYSQL_PORT_RUNTIME"
export SAGE_ELASTICSEARCH_URL="$ES_URL_RUNTIME"
export SAGE_S3_ENDPOINT="$S3_ENDPOINT_RUNTIME"
export SAGE_TRACE_JAEGER_URL="$JAEGER_ENDPOINT_RUNTIME"
export SAGE_TRACE_JAEGER_ENDPOINT="$JAEGER_ENDPOINT_RUNTIME"
export SAGE_TRACE_JAEGER_PUBLIC_URL="$JAEGER_PUBLIC_RUNTIME"

if [ -n "$EMBEDDING_BASE_RUNTIME" ]; then
    export SAGE_EMBEDDING_BASE_URL="$EMBEDDING_BASE_RUNTIME"
fi

log_info "Backend URL: $BACKEND_URL"
log_info "Frontend URL: $FRONTEND_URL"
log_info "Elasticsearch URL: $ES_URL_RUNTIME"
log_info "RustFS URL: $S3_ENDPOINT_RUNTIME"
log_info "Embedding URL: $EMBEDDING_BASE_RUNTIME"

if [ "${SAGE_DB_TYPE:-file}" = "mysql" ]; then
    require_tcp_service "$MYSQL_HOST_RUNTIME" "$MYSQL_PORT_RUNTIME" "MySQL"
fi

if [ -n "${SAGE_ELASTICSEARCH_URL:-}" ]; then
    require_http_service "$ES_URL_RUNTIME" "Elasticsearch"
fi

if [ -n "${SAGE_S3_ENDPOINT:-}" ]; then
    require_http_service "${S3_ENDPOINT_RUNTIME%/}/health" "RustFS"
fi

read -r JAEGER_HOST JAEGER_PORT < <(split_host_port_from_url "$JAEGER_ENDPOINT_RUNTIME")
warn_tcp_service "$JAEGER_HOST" "$JAEGER_PORT" "Jaeger OTLP"

if [ -n "$EMBEDDING_BASE_RUNTIME" ] && printf '%s' "$EMBEDDING_BASE_RUNTIME" | grep -q '127.0.0.1:30056'; then
    require_http_service "http://127.0.0.1:30056/health" "Embedding"
fi

if is_sage_backend_response "$BACKEND_URL"; then
    log_fail "Backend already responds at $BACKEND_URL"
    exit 1
fi

: > "$SERVER_LOG"
: > "$FRONTEND_LOG"

start_stage "Starting backend"
(
    cd "$PROJECT_ROOT"
    setsid "${SERVER_CMD[@]}" >>"$SERVER_LOG" 2>&1 < /dev/null &
    echo $! > "$SERVER_PID_FILE"
)
SERVER_PID="$(cat "$SERVER_PID_FILE")"
log_info "Backend PID: $SERVER_PID"

if ! wait_for_backend "$BACKEND_URL" "$SERVER_PID"; then
    log_fail "Backend failed to start. Check $SERVER_LOG"
    stop_process_group "$SERVER_PID_FILE" "backend"
    exit 1
fi

start_stage "Starting frontend"
(
    cd "$PROJECT_ROOT/app/server/web"
    env \
        VITE_SAGE_API_BASE_URL="$BACKEND_URL" \
        VITE_BACKEND_API_PREFIX="$FRONTEND_API_PREFIX" \
        VITE_SAGE_WEB_BASE_PATH="$FRONTEND_BASE_PATH" \
        VITE_SAGE_TRACE_WEB_URL="$FRONTEND_TRACE_URL" \
        setsid npm run dev -- --host 127.0.0.1 --port "$FRONTEND_PORT" >>"$FRONTEND_LOG" 2>&1 < /dev/null &
    echo $! > "$FRONTEND_PID_FILE"
)
FRONTEND_PID="$(cat "$FRONTEND_PID_FILE")"
log_info "Frontend PID: $FRONTEND_PID"

if ! wait_for_frontend "$FRONTEND_PORT" "$FRONTEND_BASE_PATH" "$FRONTEND_PID"; then
    log_fail "Frontend failed to start. Check $FRONTEND_LOG"
    stop_process_group "$FRONTEND_PID_FILE" "frontend"
    stop_process_group "$SERVER_PID_FILE" "backend"
    exit 1
fi

printf '\nStartup complete\n'
print_link "Frontend" "$FRONTEND_URL"
print_link "Backend" "$BACKEND_URL"
print_link "Backend health" "$BACKEND_URL/api/health"
print_link "Backend log" "$SERVER_LOG"
print_link "Frontend log" "$FRONTEND_LOG"
print_link "Stop script" "$PROJECT_ROOT/scripts/stop-dev.sh"
