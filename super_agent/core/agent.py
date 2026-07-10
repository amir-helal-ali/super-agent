"""
agent.py - الوكيل الرئيسي بنمط ReAct
Reasoning + Acting: يفكر، ينفذ، يراقب، يكرر
"""
import json
import re
import logging
from typing import AsyncIterator, Dict, Any, List, Optional

from ..config import AgentConfig
from .llm import LLMBackend
from .memory import Memory
from ..tools import ToolRegistry

logger = logging.getLogger(__name__)


# النظام الأساسي - يوجه سلوك الوكيل
SYSTEM_PROMPT = """أنت {name} - وكيل ذكاء اصطناعي خارق يعمل على أجهزة منخفضة الإمكانيات.

## مهمتك
مساعدة المستخدم بأفضل شكل ممكن باستخدام الأدوات المتاحة. تفكّر خطوة بخطوة ثم نفّذ.

## لغتك
- أجب بنفس لغة المستخدم (عربي/إنجليزي).
- إذا سأل بالعربية، أجب بالعربية.
- استخدم لغة واضحة ومختصرة.

## نمط التفكير (ReAct)
عند الحاجة لاستخدام أداة، استخدم الصيغة التالية بدقة:

```thought
<تفكيرك حول المشكلة وما يجب فعله>
```

```action
{{
  "tool": "اسم_الأداة",
  "parameters": {{ ... }}
}}
```

بعد رؤية نتيجة الأداة، فكّر مجدداً ثم إما:
- استخدم أداة أخرى بنفس الصيغة
- أو أعطِ الإجابة النهائية بهذا الشكل:

```final
<إجابتك النهائية للمستخدم>
```

## الأدوات المتاحة
{tools_description}

## القيود
- لا تخترع معلومات. إن لم تعرف، استخدم web_search.
- لا تستخدم أداة إلا إذا كانت ضرورية فعلاً.
- أقصى عدد من الخطوات: {max_iterations}.
- كن مختصراً في تفكيرك وركز على الحل.
"""


class SuperAgent:
    """الوكيل الخارق"""

    def __init__(
        self,
        config: Optional[AgentConfig] = None,
        tools: Optional[ToolRegistry] = None,
        memory: Optional[Memory] = None,
        llm: Optional[LLMBackend] = None,
    ):
        self.config = config or AgentConfig.from_env()
        self.memory = memory or Memory(self.config.memory)
        self.llm = llm or LLMBackend(self.config.llm)
        self.tools = tools or ToolRegistry(self.config)

        # بناء وصف الأدوات
        self._tools_description = self._build_tools_description()

    def _build_tools_description(self) -> str:
        """بناء وصف الأدوات من المخططات"""
        lines = []
        for schema in self.tools.get_schemas():
            name = schema["name"]
            desc = schema.get("description", "")
            params = schema.get("parameters", {}).get("properties", {})
            params_str = ", ".join(params.keys()) if params else "بدون"
            lines.append(f"- **{name}**({params_str}): {desc}")
        return "\n".join(lines)

    def _build_system_prompt(self) -> str:
        """بناء رسالة النظام"""
        return SYSTEM_PROMPT.format(
            name=self.config.name,
            tools_description=self._tools_description,
            max_iterations=self.config.max_iterations,
        )

    def _build_context_messages(
        self, user_message: str, session_id: str
    ) -> List[Dict[str, str]]:
        """بناء سياق المحادثة"""
        messages: List[Dict[str, str]] = []

        # 1. رسالة النظام
        messages.append({
            "role": "system",
            "content": self._build_system_prompt(),
        })

        # 2. ذاكرة طويلة المدى - استرجاع ما يخص السؤال
        relevant = self.memory.recall(user_message)
        if relevant:
            facts_text = "\n".join(
                f"- {f['key']}: {f['content']}" for f in relevant
            )
            messages.append({
                "role": "system",
                "content": f"معلومات تخص المستخدم من الذاكرة:\n{facts_text}",
            })

        # 3. تاريخ المحادثة الأخير
        history = self.memory.get_history(session_id)
        messages.extend(history)

        # 4. الرسالة الحالية
        messages.append({"role": "user", "content": user_message})

        return messages

    async def chat(
        self,
        message: str,
        session_id: str = "default",
        stream: bool = False,
    ) -> Any:
        """
        محادثة مع الوكيل

        Args:
            message: رسالة المستخدم
            session_id: معرف الجلسة (للذاكرة)
            stream: بث الرد
        """
        # حفظ رسالة المستخدم
        self.memory.add_message(session_id, "user", message)

        # بناء السياق
        messages = self._build_context_messages(message, session_id)

        # حلقة ReAct
        if stream:
            return self._chat_stream(messages, session_id)
        else:
            return await self._chat_complete(messages, session_id)

    async def _chat_complete(
        self, messages: List[Dict], session_id: str
    ) -> Dict[str, Any]:
        """محادثة كاملة (غير متدفقة)"""
        all_steps: List[Dict] = []
        current_messages = list(messages)
        final_answer = None
        total_tokens = 0

        for iteration in range(self.config.max_iterations):
            # استدعاء LLM
            try:
                response = await self.llm.chat(current_messages, stream=False)
            except Exception as e:
                logger.error(f"LLM error: {e}")
                return {
                    "answer": f"عذراً، حدث خطأ: {e}",
                    "steps": all_steps,
                    "session_id": session_id,
                }

            content = response.get("content", "")
            total_tokens += response.get("usage", 0) if isinstance(
                response.get("usage"), int
            ) else 0

            # تحليل الرد
            parsed = self._parse_response(content)

            if parsed["type"] == "final":
                final_answer = parsed["content"]
                all_steps.append({
                    "iteration": iteration + 1,
                    "type": "final",
                    "content": final_answer,
                })
                break

            elif parsed["type"] == "action":
                thought = parsed.get("thought", "")
                tool_name = parsed["action"]["tool"]
                tool_params = parsed["action"].get("parameters", {})

                # تنفيذ الأداة
                tool_result = await self.tools.call(tool_name, **tool_params)

                step = {
                    "iteration": iteration + 1,
                    "type": "action",
                    "thought": thought,
                    "tool": tool_name,
                    "parameters": tool_params,
                    "result": tool_result,
                }
                all_steps.append(step)

                # إضافة رد المساعد ونتيجة الأداة للسياق
                current_messages.append({
                    "role": "assistant",
                    "content": content,
                })
                current_messages.append({
                    "role": "user",
                    "content": f"نتيجة الأداة {tool_name}:\n```json\n{json.dumps(tool_result, ensure_ascii=False, default=str)[:2000]}\n```\n\nتابع التفكير وأعطِ الإجابة النهائية أو استخدم أداة أخرى.",
                })

            else:
                # رد مباشر بدون ReAct
                final_answer = content
                all_steps.append({
                    "iteration": iteration + 1,
                    "type": "direct",
                    "content": content,
                })
                break
        else:
            final_answer = (
                "وصلت للحد الأقصى من الخطوات. آخر إجابة: "
                + (parsed.get("content", "") if 'parsed' in locals() else "")
            )

        # حفظ رد الوكيل
        self.memory.add_message(session_id, "assistant", final_answer)

        # محاولة استخراج معلومات للحفظ في الذاكرة طويلة المدى
        self._maybe_remember_facts(message, final_answer, session_id)

        return {
            "answer": final_answer,
            "steps": all_steps,
            "iterations": len(all_steps),
            "session_id": session_id,
            "tokens": total_tokens,
        }

    async def _chat_stream(
        self, messages: List[Dict], session_id: str
    ) -> AsyncIterator[Dict]:
        """محادثة متدفقة"""
        # للتبسيط: نبث خطوة بخطوة
        result = await self._chat_complete(messages, session_id)
        for step in result["steps"]:
            yield {"type": "step", "data": step}
        yield {"type": "final", "data": result}

    def _parse_response(self, content: str) -> Dict[str, Any]:
        """تحليل رد LLM واستخراج thought/action/final"""
        # محاولة العثور على final
        final_match = re.search(
            r"```final\s*(.*?)\s*```", content, re.DOTALL | re.IGNORECASE
        )
        if final_match:
            return {"type": "final", "content": final_match.group(1).strip()}

        # محاولة العثور على thought + action
        thought_match = re.search(
            r"```thought\s*(.*?)\s*```", content, re.DOTALL | re.IGNORECASE
        )
        action_match = re.search(
            r"```action\s*(.*?)\s*```", content, re.DOTALL | re.IGNORECASE
        )

        if action_match:
            try:
                action_data = json.loads(action_match.group(1).strip())
                thought = thought_match.group(1).strip() if thought_match else ""
                return {
                    "type": "action",
                    "thought": thought,
                    "action": action_data,
                }
            except json.JSONDecodeError as e:
                logger.warning(f"Failed to parse action JSON: {e}")

        # إذا كان الرد مباشراً بدون علامات
        # نعتبره إجابة نهائية
        return {"type": "direct", "content": content.strip()}

    def _maybe_remember_facts(
        self, user_msg: str, agent_response: str, session_id: str
    ):
        """استخراج وحفظ المعلومات المهمة في الذاكرة طويلة المدى"""
        # أنماط بسيطة لاكتشاف المعلومات
        patterns = [
            # "اسمي X" / "my name is X"
            (r"(?:اسمي|أنا اسمي|my name is)\s+([A-Za-z\u0600-\u06FF\s]+?)[.،,!؟?]?", "user_name"),
            # "أعيش في X" / "I live in X"
            (r"(?:أعيش في|أسكن في|I live in)\s+([A-Za-z\u0600-\u06FF\s]+?)[.،,!؟?]?", "user_location"),
            # "أعمل X" / "I work as"
            (r"(?:أعمل|أشتغل|I work as|I am a)\s+([A-Za-z\u0600-\u06FF\s]+?)[.،,!؟?]?", "user_job"),
            # "تذكر أن X"
            (r"(?:تذكر أن|احفظ أن|remember that)\s+(.+?)[.،!؟?]?$", "fact"),
        ]

        for pattern, key_prefix in patterns:
            matches = re.findall(pattern, user_msg, re.IGNORECASE)
            for i, value in enumerate(matches):
                value = value.strip()
                if 2 <= len(value) <= 200:
                    key = f"{key_prefix}_{session_id}" if key_prefix != "fact" else f"fact_{hash(value) & 0xFFFFFF:x}"
                    self.memory.remember(key, value, source="auto_extracted")

    async def close(self):
        """إغلاق الموارد"""
        await self.llm.close()

    def stats(self) -> Dict[str, Any]:
        """إحصائيات الوكيل"""
        return {
            "memory": self.memory.stats(),
            "tools": self.tools.list_names(),
            "config": {
                "backend": self.config.llm.backend,
                "model": (
                    self.config.llm.ollama_model
                    if self.config.llm.backend == "local"
                    else self.config.llm.api_model
                ),
                "max_iterations": self.config.max_iterations,
            },
        }
