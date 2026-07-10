"""
llm.py - طبقة نموذج اللغة الموحدة
تدعم وضعين: Ollama محلي أو API سحابي
كلاهما خفيف الوزن ولا يحتاج GPU
"""
import json
import logging
from typing import AsyncIterator, Optional, List, Dict, Any

import httpx

from ..config import LLMConfig

logger = logging.getLogger(__name__)


class LLMBackend:
    """واجهة موحدة لطبقة LLM"""

    def __init__(self, config: LLMConfig):
        self.config = config
        self.client = httpx.AsyncClient(timeout=config.timeout)

    async def chat(
        self,
        messages: List[Dict[str, str]],
        stream: bool = False,
        **kwargs
    ) -> Any:
        """إرسال محادثة وإرجاع الرد"""
        if self.config.backend == "local":
            return await self._chat_ollama(messages, stream, **kwargs)
        else:
            return await self._chat_api(messages, stream, **kwargs)

    async def _chat_ollama(
        self,
        messages: List[Dict[str, str]],
        stream: bool,
        **kwargs
    ) -> Any:
        """التواصل مع Ollama المحلي - خفيف جداً على RAM"""
        url = f"{self.config.ollama_host}/api/chat"
        payload = {
            "model": self.config.ollama_model,
            "messages": messages,
            "stream": stream,
            "options": {
                "num_predict": kwargs.get("max_tokens", self.config.max_tokens),
                "temperature": kwargs.get("temperature", self.config.temperature),
                # تقييد استهلاك RAM
                "num_ctx": 4096,
                "num_thread": 4,
            },
        }

        try:
            if stream:
                return self._stream_ollama(payload)
            else:
                resp = await self.client.post(url, json=payload)
                resp.raise_for_status()
                data = resp.json()
                return {
                    "content": data.get("message", {}).get("content", ""),
                    "role": "assistant",
                    "usage": data.get("eval_count", 0),
                }
        except httpx.ConnectError:
            logger.error("Ollama غير مشغل. شغّل: ollama serve")
            raise RuntimeError(
                "Ollama غير متاح. شغّل 'ollama serve' أو غيّر backend إلى 'api'"
            )

    async def _stream_ollama(self, payload: dict):
        """بث الرد من Ollama"""
        async with self.client.stream(
            "POST",
            f"{self.config.ollama_host}/api/chat",
            json=payload
        ) as resp:
            async for line in resp.aiter_lines():
                if line:
                    data = json.loads(line)
                    chunk = data.get("message", {}).get("content", "")
                    if chunk:
                        yield {"content": chunk, "role": "assistant"}
                    if data.get("done"):
                        break

    async def _chat_api(
        self,
        messages: List[Dict[str, str]],
        stream: bool,
        **kwargs
    ) -> Any:
        """التواصل مع API السحابي - أخف استهلاك للذاكرة"""
        if not self.config.api_base_url:
            # استخدام z-ai-web-dev-sdk كاحتياط
            return await self._chat_zai_sdk(messages, stream, **kwargs)

        url = self.config.api_base_url
        headers = {
            "Authorization": f"Bearer {self.config.api_key}",
            "Content-Type": "application/json",
        }
        payload = {
            "model": self.config.api_model,
            "messages": messages,
            "stream": stream,
            "max_tokens": kwargs.get("max_tokens", self.config.max_tokens),
            "temperature": kwargs.get("temperature", self.config.temperature),
        }

        if stream:
            return self._stream_api(url, headers, payload)

        resp = await self.client.post(url, json=payload, headers=headers)
        resp.raise_for_status()
        data = resp.json()
        return {
            "content": data["choices"][0]["message"]["content"],
            "role": "assistant",
            "usage": data.get("usage", {}),
        }

    async def _stream_api(self, url: str, headers: dict, payload: dict):
        async with self.client.stream(
            "POST", url, json=payload, headers=headers
        ) as resp:
            async for line in resp.aiter_lines():
                if line.startswith("data: "):
                    chunk_data = line[6:]
                    if chunk_data == "[DONE]":
                        break
                    try:
                        data = json.loads(chunk_data)
                        delta = data["choices"][0].get("delta", {})
                        if "content" in delta:
                            yield {"content": delta["content"], "role": "assistant"}
                    except json.JSONDecodeError:
                        continue

    async def _chat_zai_sdk(
        self,
        messages: List[Dict[str, str]],
        stream: bool,
        **kwargs
    ) -> Any:
        """استخدام z-ai-web-dev-sdk عند عدم توفر API مباشر"""
        try:
            from zai import ZaiClient
        except ImportError:
            raise RuntimeError(
                "z-ai-web-dev-sdk غير مثبت. ثبته: npm install z-ai-web-dev-sdk"
            )

        # هذا يتطلب استدعاء Node.js subprocess
        # للحفاظ على البساطة، نستخدم CLI
        import subprocess

        # تحويل الرسائل لـ prompt مباشر
        prompt_parts = []
        system_msg = ""
        for msg in messages:
            if msg["role"] == "system":
                system_msg = msg["content"]
            else:
                prompt_parts.append(f"{msg['role']}: {msg['content']}")
        prompt = "\n\n".join(prompt_parts)

        cmd = ["npx", "z-ai-web-dev-sdk", "chat"]
        if system_msg:
            cmd.extend(["--system", system_msg])
        cmd.extend(["--prompt", prompt])

        try:
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=kwargs.get(
                    "timeout", self.config.timeout
                )
            )
            if result.returncode != 0:
                raise RuntimeError(f"ZAI SDK error: {result.stderr}")
            return {
                "content": result.stdout.strip(),
                "role": "assistant",
                "usage": {},
            }
        except FileNotFoundError:
            raise RuntimeError("Node.js غير مثبت أو z-ai-web-dev-sdk غير متاح")

    async def close(self):
        await self.client.aclose()
