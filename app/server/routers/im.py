import asyncio
import base64
import json
import logging
import secrets
import uuid
from typing import Any, Dict, Optional

import httpx
import websockets
from fastapi import APIRouter, Path as FastApiPath, Request
from pydantic import BaseModel, Field

from common.core.render import Response
from common.core.request_identity import get_request_role, get_request_user_id
from common.models.agent import AgentConfigDao
from mcp_servers.im_server.agent_config import (
    IMESSAGE_PROVIDER,
    find_agent_by_provider_id,
    get_agent_im_config,
)

logger = logging.getLogger(__name__)

im_router = APIRouter(prefix="/api/im", tags=["im"])


class ProviderConfigRequest(BaseModel):
    enabled: bool = Field(default=False)
    config: Dict[str, Any] = Field(default_factory=dict)


class ProviderConfigResponse(BaseModel):
    provider: str
    enabled: bool
    config: Dict[str, Any]
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


class TestConnectionRequest(BaseModel):
    config: Optional[Dict[str, Any]] = Field(default=None)


class TestConnectionResponse(BaseModel):
    success: bool
    message: str
    details: Optional[Dict[str, Any]] = None


class WeChatPersonalQRCodeResponse(BaseModel):
    qrcode: str
    qrcode_url: str
    expires_in: int = 300


class WeChatPersonalStatusResponse(BaseModel):
    status: str
    bot_token: Optional[str] = None
    bot_id: Optional[str] = None
    baseurl: Optional[str] = None


async def _authorize_agent(agent_id: str, http_request: Request):
    dao = AgentConfigDao()
    agent = await dao.get_by_id(agent_id)
    if not agent:
        return None, await Response.error(code=404, message=f"Agent '{agent_id}' 不存在")

    user_id = get_request_user_id(http_request)
    role = get_request_role(http_request)
    if role != "admin" and agent.user_id and agent.user_id != user_id:
        return None, await Response.error(code=403, message="无权管理该 Agent 的 IM 配置")

    return agent, None


async def _is_agent_default(agent_id: str) -> bool:
    dao = AgentConfigDao()
    agent = await dao.get_by_id(agent_id)
    return bool(agent and agent.is_default)


async def _validate_provider_config(agent_id: str, provider: str, config: Dict[str, Any], enabled: bool = False):
    if provider == IMESSAGE_PROVIDER and enabled:
        if not await _is_agent_default(agent_id):
            raise ValueError("iMessage 只能配置在默认 Agent 上")

        allowed_senders = config.get("allowed_senders", []) if config else []
        if not allowed_senders:
            raise ValueError("iMessage 必须至少配置一个监听发送者")


def _extract_config_request(config_request: Any) -> tuple[bool, Dict[str, Any]]:
    if isinstance(config_request, ProviderConfigRequest):
        return config_request.enabled, config_request.config or {}
    if isinstance(config_request, dict):
        return bool(config_request.get("enabled", False)), config_request.get("config", {}) or {}
    return False, {}


@im_router.get("/agent/{agent_id}/im_channels")
async def get_agent_im_channels(
    agent_id: str = FastApiPath(..., description="Agent ID"),
    http_request: Request = None,
):
    agent, error = await _authorize_agent(agent_id, http_request)
    if error:
        return error

    try:
        agent_config = get_agent_im_config(agent_id)
        channels = agent_config.get_all_channels()
        is_default = bool(agent.is_default)
        result_channels = {}

        for provider, channel_data in channels.items():
            if provider == IMESSAGE_PROVIDER and not is_default:
                continue

            result_channels[provider] = ProviderConfigResponse(
                provider=provider,
                enabled=channel_data.get("enabled", False),
                config=channel_data.get("config", {}),
                updated_at=channel_data.get("updated_at"),
            )

        return await Response.succ(
            data={
                "agent_id": agent_id,
                "is_default": is_default,
                "channels": result_channels,
            },
            message="获取成功",
        )
    except Exception as e:
        logger.error(f"[IM Agent] Failed to get channels for {agent_id}: {e}", exc_info=True)
        return await Response.error(code=500, message=f"获取配置失败: {str(e)}")


@im_router.post("/agent/{agent_id}/im_channels")
async def save_agent_im_channels(
    agent_id: str = FastApiPath(..., description="Agent ID"),
    channels: Optional[Dict[str, ProviderConfigRequest]] = None,
    http_request: Request = None,
):
    _, error = await _authorize_agent(agent_id, http_request)
    if error:
        return error

    try:
        agent_config = get_agent_im_config(agent_id)
        existing_channels = agent_config.get_all_channels()
        results = []
        restarted = []

        for provider, config_request in (channels or {}).items():
            enabled, provider_config = _extract_config_request(config_request)
            try:
                await _validate_provider_config(agent_id, provider, provider_config, enabled)

                id_field_map = {
                    "wechat_work": "bot_id",
                    "dingtalk": "client_id",
                    "feishu": "app_id",
                }
                id_field = id_field_map.get(provider)
                id_value = provider_config.get(id_field) if id_field else None
                if enabled and id_value:
                    existing_agent = find_agent_by_provider_id(
                        provider,
                        id_value,
                        exclude_agent_id=agent_id,
                    )
                    if existing_agent:
                        results.append(
                            {
                                "provider": provider,
                                "status": "skipped",
                                "error": f"{provider} 的 {id_field} '{id_value}' 已被 Agent '{existing_agent}' 使用",
                            }
                        )
                        continue

                existing_channel = existing_channels.get(provider)
                changed = (
                    existing_channel is None
                    or existing_channel.get("enabled", False) != enabled
                    or existing_channel.get("config", {}) != provider_config
                )

                success = agent_config.set_provider_config(
                    provider=provider,
                    enabled=enabled,
                    config=provider_config,
                )
                if not success:
                    results.append({"provider": provider, "status": "failed", "error": "保存失败"})
                    continue

                results.append({"provider": provider, "status": "saved" if changed else "unchanged"})

                if changed:
                    try:
                        from mcp_servers.im_server.service_manager import get_service_manager

                        manager = get_service_manager()
                        await manager.start()
                        if enabled:
                            if await manager.restart_channel(agent_id, provider):
                                restarted.append(provider)
                        else:
                            await manager.stop_channel(agent_id, provider)
                            restarted.append(f"{provider}(stopped)")
                    except Exception as manage_error:
                        logger.warning(
                            f"[IM Agent] Failed to manage channel {provider} for {agent_id}: {manage_error}"
                        )
            except ValueError as ve:
                results.append({"provider": provider, "status": "skipped", "error": str(ve)})

        return await Response.succ(
            data={"agent_id": agent_id, "results": results, "restarted": restarted},
            message="保存成功",
        )
    except Exception as e:
        logger.error(f"[IM Agent] Failed to save channels for {agent_id}: {e}", exc_info=True)
        return await Response.error(code=500, message=f"保存配置失败: {str(e)}")


@im_router.post("/agent/{agent_id}/im_channels/{provider}/test")
async def test_agent_im_connection(
    request: TestConnectionRequest,
    agent_id: str = FastApiPath(..., description="Agent ID"),
    provider: str = FastApiPath(..., description="Provider type"),
    http_request: Request = None,
):
    _, error = await _authorize_agent(agent_id, http_request)
    if error:
        return error

    try:
        if request.config:
            config = request.config
        else:
            all_channels = get_agent_im_config(agent_id).get_all_channels()
            channel_data = all_channels.get(provider, {})
            config = channel_data.get("config", {})

        if not config:
            return await Response.error(code=404, message=f"未找到 {provider} 配置")

        if provider == "wechat_work":
            bot_id = config.get("bot_id")
            secret = config.get("secret")
            if not bot_id or not secret:
                return await Response.succ(
                    data=TestConnectionResponse(success=False, message="缺少 Bot ID 或 Secret 配置", details={}),
                    message="配置不完整",
                )

            try:
                async def test_wechat_connection():
                    async with websockets.connect("wss://openws.work.weixin.qq.com", ping_interval=None) as ws:
                        await ws.send(
                            json.dumps(
                                {
                                    "cmd": "aibot_subscribe",
                                    "headers": {"req_id": str(uuid.uuid4())},
                                    "body": {"bot_id": bot_id, "secret": secret},
                                }
                            )
                        )
                        response = await asyncio.wait_for(ws.recv(), timeout=10)
                        data = json.loads(response)
                        return data.get("errcode", -1), data.get("errmsg", "未知错误")

                errcode, errmsg = await asyncio.wait_for(test_wechat_connection(), timeout=15)
                if errcode == 0:
                    return await Response.succ(
                        data=TestConnectionResponse(
                            success=True,
                            message="企业微信连接测试成功",
                            details={"bot_id": bot_id},
                        ),
                        message="连接测试成功",
                    )

                if errcode == 40014:
                    message = "Bot ID 或 Secret 无效，请检查配置"
                else:
                    message = f"连接测试失败: {errmsg} (错误码: {errcode})"
                return await Response.succ(
                    data=TestConnectionResponse(success=False, message=message, details={"errcode": errcode}),
                    message="连接测试失败",
                )
            except asyncio.TimeoutError:
                return await Response.succ(
                    data=TestConnectionResponse(success=False, message="连接超时，请检查网络连接", details={}),
                    message="连接测试失败",
                )
            except Exception as provider_error:
                return await Response.succ(
                    data=TestConnectionResponse(success=False, message=f"连接测试失败: {str(provider_error)}", details={}),
                    message="连接测试失败",
                )

        if provider == "dingtalk":
            client_id = config.get("client_id") or config.get("app_key")
            client_secret = config.get("client_secret") or config.get("app_secret")
            if not client_id or not client_secret:
                return await Response.succ(
                    data=TestConnectionResponse(success=False, message="缺少 Client ID 或 Client Secret 配置", details={}),
                    message="配置不完整",
                )

            try:
                async with httpx.AsyncClient(timeout=15.0) as client:
                    resp = await client.get(
                        "https://oapi.dingtalk.com/gettoken",
                        params={"appkey": client_id, "appsecret": client_secret},
                    )
                    data = resp.json()

                if data.get("errcode") == 0:
                    access_token = data.get("access_token")
                    return await Response.succ(
                        data=TestConnectionResponse(
                            success=True,
                            message="钉钉连接测试成功，凭证有效",
                            details={
                                "client_id": client_id,
                                "token_preview": access_token[:10] + "..." if access_token else None,
                            },
                        ),
                        message="连接测试成功",
                    )

                return await Response.succ(
                    data=TestConnectionResponse(
                        success=False,
                        message=f"连接测试失败: {data.get('errmsg', '未知错误')} (错误码: {data.get('errcode')})",
                        details={"errcode": data.get("errcode")},
                    ),
                    message="连接测试失败",
                )
            except httpx.TimeoutException:
                return await Response.succ(
                    data=TestConnectionResponse(success=False, message="连接超时，请检查网络连接", details={}),
                    message="连接测试失败",
                )
            except Exception as provider_error:
                return await Response.succ(
                    data=TestConnectionResponse(success=False, message=f"连接测试失败: {str(provider_error)}", details={}),
                    message="连接测试失败",
                )

        if provider == "feishu":
            app_id = config.get("app_id")
            app_secret = config.get("app_secret")
            if not app_id or not app_secret:
                return await Response.succ(
                    data=TestConnectionResponse(success=False, message="缺少 App ID 或 App Secret 配置", details={}),
                    message="配置不完整",
                )

            try:
                async with httpx.AsyncClient(timeout=15.0) as client:
                    resp = await client.post(
                        "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal",
                        json={"app_id": app_id, "app_secret": app_secret},
                    )
                    data = resp.json()

                if data.get("code") == 0:
                    token = data.get("tenant_access_token")
                    return await Response.succ(
                        data=TestConnectionResponse(
                            success=True,
                            message="飞书连接测试成功，凭证有效",
                            details={
                                "app_id": app_id,
                                "token_preview": token[:10] + "..." if token else None,
                            },
                        ),
                        message="连接测试成功",
                    )

                return await Response.succ(
                    data=TestConnectionResponse(
                        success=False,
                        message=f"连接测试失败: {data.get('msg', '未知错误')} (错误码: {data.get('code')})",
                        details={"code": data.get("code")},
                    ),
                    message="连接测试失败",
                )
            except httpx.TimeoutException:
                return await Response.succ(
                    data=TestConnectionResponse(success=False, message="连接超时，请检查网络连接", details={}),
                    message="连接测试失败",
                )
            except Exception as provider_error:
                return await Response.succ(
                    data=TestConnectionResponse(success=False, message=f"连接测试失败: {str(provider_error)}", details={}),
                    message="连接测试失败",
                )

        if provider == "wechat_personal":
            bot_token = config.get("bot_token")
            bot_id = config.get("bot_id")
            if not bot_token:
                return await Response.succ(
                    data=TestConnectionResponse(success=False, message="缺少 Bot Token 配置", details={}),
                    message="配置不完整",
                )
            if "@im.bot:" not in bot_token:
                return await Response.succ(
                    data=TestConnectionResponse(success=False, message="Bot Token 格式不正确，请检查是否复制完整", details={}),
                    message="配置格式错误",
                )
            return await Response.succ(
                data=TestConnectionResponse(
                    success=True,
                    message="微信个人号配置格式正确，启动后将自动连接",
                    details={
                        "bot_id": bot_id,
                        "token_preview": bot_token[:20] + "..." if len(bot_token) > 20 else bot_token,
                    },
                ),
                message="配置检查通过",
            )

        if provider == "imessage":
            return await Response.succ(
                data=TestConnectionResponse(
                    success=True,
                    message="iMessage 配置正确（本地模式无需连接测试）",
                    details={"mode": "database_poll"},
                ),
                message="配置检查通过",
            )

        return await Response.error(code=400, message=f"不支持的 Provider: {provider}")
    except Exception as e:
        logger.error(f"[IM Agent] Failed to test {provider} for {agent_id}: {e}", exc_info=True)
        return await Response.error(code=500, message=f"测试连接失败: {str(e)}")


@im_router.post("/agent/{agent_id}/im_channels/wechat_personal/qrcode")
async def get_wechat_personal_qrcode(
    agent_id: str = FastApiPath(..., description="Agent ID"),
    http_request: Request = None,
):
    _, error = await _authorize_agent(agent_id, http_request)
    if error:
        return error

    try:
        base_url = "https://ilinkai.weixin.qq.com"
        headers = {
            "X-WECHAT-UIN": base64.b64encode(str(secrets.randbits(32)).encode()).decode(),
        }

        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                f"{base_url}/ilink/bot/get_bot_qrcode",
                params={"bot_type": "3"},
                headers=headers,
            )
            response.raise_for_status()
            qr_resp = response.json()

        if not qr_resp or qr_resp.get("ret") != 0:
            return await Response.error(code=500, message="获取二维码失败")

        qrcode = qr_resp.get("qrcode", "")
        qrcode_url = qr_resp.get("qrcode_img_content", "")
        if not qrcode or not qrcode_url:
            return await Response.error(code=500, message="获取二维码失败：响应数据不完整")

        return await Response.succ(
            data=WeChatPersonalQRCodeResponse(
                qrcode=qrcode,
                qrcode_url=qrcode_url,
                expires_in=300,
            ),
            message="获取二维码成功",
        )
    except Exception as e:
        logger.error(f"[IM Agent] Failed to get WeChat personal QR code for {agent_id}: {e}", exc_info=True)
        return await Response.error(code=500, message=f"获取二维码失败: {str(e)}")


@im_router.post("/agent/{agent_id}/im_channels/wechat_personal/qrcode/status")
async def check_wechat_personal_qrcode_status(
    request: Dict[str, Any],
    agent_id: str = FastApiPath(..., description="Agent ID"),
    http_request: Request = None,
):
    _, error = await _authorize_agent(agent_id, http_request)
    if error:
        return error

    qrcode = request.get("qrcode")
    if not qrcode:
        return await Response.error(code=400, message="缺少 qrcode 参数")

    try:
        base_url = "https://ilinkai.weixin.qq.com"
        headers = {
            "X-WECHAT-UIN": base64.b64encode(str(secrets.randbits(32)).encode()).decode(),
        }

        async with httpx.AsyncClient(timeout=35.0) as client:
            try:
                response = await client.get(
                    f"{base_url}/ilink/bot/get_qrcode_status",
                    params={"qrcode": qrcode},
                    headers=headers,
                )
                response.raise_for_status()
                status_resp = response.json()
            except httpx.ReadTimeout:
                return await Response.succ(
                    data=WeChatPersonalStatusResponse(status="wait"),
                    message="等待扫码",
                )

        status_code = status_resp.get("status", "wait")
        if status_code == "confirmed":
            return await Response.succ(
                data=WeChatPersonalStatusResponse(
                    status=status_code,
                    bot_token=status_resp.get("bot_token"),
                    bot_id=status_resp.get("ilink_bot_id"),
                    baseurl=status_resp.get("baseurl", base_url),
                ),
                message="登录成功",
            )
        if status_code == "expired":
            return await Response.succ(
                data=WeChatPersonalStatusResponse(status=status_code),
                message="二维码已过期",
            )
        if status_code == "scaned":
            return await Response.succ(
                data=WeChatPersonalStatusResponse(status=status_code),
                message="已扫码，等待确认",
            )
        return await Response.succ(
            data=WeChatPersonalStatusResponse(status=status_code),
            message="等待扫码",
        )
    except Exception as e:
        logger.error(f"[IM Agent] Failed to check WeChat personal QR status for {agent_id}: {e}", exc_info=True)
        return await Response.error(code=500, message=f"检查状态失败: {str(e)}")
