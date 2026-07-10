"""
tools/__init__.py - تسجيل كل الأدوات في سجل موحد
"""
from typing import Dict, Callable, List, Any
import asyncio
import inspect

from .calculator import calculate, TOOL_SCHEMA as CALC_SCHEMA
from .web_search import (
    search as web_search,
    fetch_page,
    TOOL_SCHEMA_SEARCH,
    TOOL_SCHEMA_FETCH,
)
from .file_ops import (
    read_file, write_file, list_files, create_directory,
    delete_file, TOOL_SCHEMAS as FILE_SCHEMAS
)
from .code_runner import run_python, TOOL_SCHEMA as CODE_SCHEMA


class ToolRegistry:
    """سجل الأدوات - يربط أسماء الأدوات بالوظائف والمخططات"""

    def __init__(self, config=None):
        self._tools: Dict[str, Callable] = {}
        self._schemas: List[Dict] = []
        self._async_tools: set = set()

        # تسجيل الأدوات الافتراضية
        self.register("calculator", calculate, CALC_SCHEMA, is_async=False)
        self.register("web_search", web_search, TOOL_SCHEMA_SEARCH, is_async=True)
        self.register("fetch_page", fetch_page, TOOL_SCHEMA_FETCH, is_async=True)

        # أدوات الملفات
        for schema in FILE_SCHEMAS:
            name = schema["name"]
            func = {
                "read_file": read_file,
                "write_file": write_file,
                "list_files": list_files,
                "create_directory": create_directory,
                "delete_file": delete_file,
            }[name]
            self.register(name, func, schema, is_async=False)

        # أداة تشغيل الكود (مغلقة افتراضياً)
        if config and getattr(config, "enable_code_exec", False):
            self.register(
                "run_python", run_python, CODE_SCHEMA, is_async=False
            )

    def register(
        self,
        name: str,
        func: Callable,
        schema: Dict,
        is_async: bool = False
    ):
        """تسجيل أداة جديدة"""
        self._tools[name] = func
        self._schemas.append(schema)
        if is_async:
            self._async_tools.add(name)

    def get_schemas(self) -> List[Dict]:
        """إرجاع مخططات كل الأدوات (لإرسالها للـ LLM)"""
        return self._schemas

    def list_names(self) -> List[str]:
        return list(self._tools.keys())

    async def call(self, name: str, **kwargs) -> Any:
        """استدعاء أداة بالاسم"""
        if name not in self._tools:
            return {"success": False, "error": f"أداة غير معروفة: {name}"}

        func = self._tools[name]
        try:
            if name in self._async_tools or inspect.iscoroutinefunction(func):
                return await func(**kwargs)
            else:
                # تشغيل الدالة المتزامنة في thread منفصل
                loop = asyncio.get_event_loop()
                return await loop.run_in_executor(None, lambda: func(**kwargs))
        except TypeError as e:
            # إعادة المحاولة بإزالة المعاملات غير المتوقعة
            return {"success": False, "error": f"معاملات غير صحيحة: {e}"}
        except Exception as e:
            return {"success": False, "error": str(e)}
