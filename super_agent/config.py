"""
config.py - إعدادات النظام
يدعم وضعين: نموذج محلي (Ollama) أو API سحابي
"""
import os
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class LLMConfig:
    """إعدادات نموذج اللغة"""
    # الوضع: "local" لـ Ollama أو "api" للسحابة
    backend: str = os.getenv("AGENT_LLM_BACKEND", "api")

    # إعدادات Ollama المحلي
    ollama_host: str = os.getenv("OLLAMA_HOST", "http://localhost:11434")
    ollama_model: str = os.getenv("OLLAMA_MODEL", "llama3.2:1b")  # خفيف جداً

    # إعدادات API السحابي
    api_base_url: str = os.getenv("AGENT_API_BASE", "")
    api_model: str = os.getenv("AGENT_API_MODEL", "glm-4-flash")
    api_key: str = os.getenv("AGENT_API_KEY", "")

    # حدود التوليد
    max_tokens: int = 2048
    temperature: float = 0.7
    timeout: int = 60


@dataclass
class MemoryConfig:
    """إعدادات الذاكرة"""
    db_path: str = os.getenv(
        "AGENT_DB_PATH",
        str(Path.home() / ".super_agent" / "memory.db")
    )
    # أقصى عدد للرسائل في السياق القصير
    short_term_limit: int = 20
    # أقصى عدد لنتائج البحث في الذاكرة طويلة المدى
    long_term_top_k: int = 5


@dataclass
class AgentConfig:
    """الإعدادات الرئيسية للوكيل"""
    llm: LLMConfig = field(default_factory=LLMConfig)
    memory: MemoryConfig = field(default_factory=MemoryConfig)

    # أقصى عدد لخطوات ReAct لمنع الحلقات اللانهائية
    max_iterations: int = 8

    # اسم الوكيل
    name: str = "Super Agent"
    language: str = "ar"  # العربية كلغة افتراضية

    # تفعيل الأدوات
    enable_web_search: bool = True
    enable_code_exec: bool = False  # خطر - يتطلب تفعيلاً يدوياً
    enable_file_ops: bool = True

    @classmethod
    def from_env(cls) -> "AgentConfig":
        """تحميل الإعدادات من متغيرات البيئة"""
        return cls()


# إعدادات افتراضية عامية
DEFAULT_CONFIG = AgentConfig.from_env()
