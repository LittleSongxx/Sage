import json
import os
from typing import Any, Dict, List

from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client

from .base import BaseSearchProvider, SearchResult, ImageResult


class DashScopeProvider(BaseSearchProvider):
    name = "dashscope"
    env_key = "DASHSCOPE_SEARCH_API_KEY"
    supports_images = False
    supports_time_range = False

    endpoint = "https://dashscope.aliyuncs.com/api/v1/mcps/WebSearch/mcp"
    tool_name = "bailian_web_search"

    @classmethod
    def resolve_api_key(cls) -> str:
        return (
            os.environ.get(cls.env_key)
            or os.environ.get("SAGE_DEFAULT_LLM_API_KEY")
            or ""
        ).strip()

    @classmethod
    def get_required_env_vars(cls) -> dict:
        return {
            cls.env_key: {
                "description": "DashScope 联网搜索 MCP API Key，未设置时会回退到 SAGE_DEFAULT_LLM_API_KEY",
                "required": False,
                "url": "https://bailian.console.aliyun.com/cn-beijing/?tab=app",
            },
            "SAGE_DEFAULT_LLM_API_KEY": {
                "description": "Sage 默认 LLM API Key，DashScope 搜索 provider 会将其作为回退凭据",
                "required": False,
                "url": "https://help.aliyun.com/zh/model-studio/get-api-key",
            },
        }

    @classmethod
    def get_config_example(cls) -> str:
        return """# DashScope 联网搜索 MCP
export DASHSCOPE_SEARCH_API_KEY=your_dashscope_api_key_here
# 或复用 Sage 默认 LLM Key
export SAGE_DEFAULT_LLM_API_KEY=your_dashscope_api_key_here"""

    async def search_web(self, query: str, count: int, time_range: str = "") -> List[SearchResult]:
        payload = await self._call_search_tool(query=query, count=count)
        pages = payload.get("pages", [])

        results = []
        for item in pages:
            if not isinstance(item, dict):
                continue
            results.append(
                SearchResult(
                    title=item.get("title", ""),
                    url=item.get("url", ""),
                    snippet=item.get("snippet", ""),
                    source=item.get("hostname", ""),
                )
            )
        return results

    async def search_images(self, query: str, count: int, time_range: str = "") -> List[ImageResult]:
        return []

    async def _call_search_tool(self, query: str, count: int) -> Dict[str, Any]:
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }

        async with streamablehttp_client(self.endpoint, headers=headers) as (read, write, _):
            async with ClientSession(read, write) as session:
                await session.initialize()
                result = await session.call_tool(
                    self.tool_name,
                    {
                        "query": query,
                        "count": max(1, min(count, 10)),
                    },
                )

        if result.isError:
            raise Exception(self._extract_error_message(result.model_dump()))

        return self._extract_payload(result.model_dump())

    def _extract_payload(self, result: Dict[str, Any]) -> Dict[str, Any]:
        content = result.get("content", [])
        for item in content:
            if not isinstance(item, dict):
                continue
            text = item.get("text")
            if not isinstance(text, str) or not text.strip():
                continue
            payload = json.loads(text)
            status = payload.get("status")
            if status not in (0, "0", None):
                raise Exception(f"DashScope WebSearch MCP returned status={status}")
            return payload
        raise Exception("DashScope WebSearch MCP 返回内容为空")

    def _extract_error_message(self, result: Dict[str, Any]) -> str:
        content = result.get("content", [])
        texts = []
        for item in content:
            if isinstance(item, dict) and isinstance(item.get("text"), str):
                texts.append(item["text"])
        return "\n".join(texts).strip() or "DashScope WebSearch MCP 调用失败"
