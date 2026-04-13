#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RUN_DIR="$PROJECT_ROOT/logs/dev/run"
SERVER_PID_FILE="$RUN_DIR/server.pid"
FRONTEND_PID_FILE="$RUN_DIR/frontend.pid"

stop_process_group() {
    local pid_file="$1"
    local label="$2"

    if [ ! -f "$pid_file" ]; then
        echo "$label is not running"
        return 0
    fi

    local pid
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [ -z "$pid" ]; then
        rm -f "$pid_file"
        echo "$label pid file was empty"
        return 0
    fi

    if ! kill -0 "$pid" >/dev/null 2>&1; then
        rm -f "$pid_file"
        echo "$label was already stopped"
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

stop_process_group "$FRONTEND_PID_FILE" "frontend"
stop_process_group "$SERVER_PID_FILE" "backend"
