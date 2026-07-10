"""
code_runner.py - تشغيل كود Python بشكل آمن
⚠️ يحتاج تفعيلاً يدوياً - خطر أمني محتمل
"""
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Dict, Any


def run_python(code: str, timeout: int = 10) -> Dict[str, Any]:
    """
    تشغيل كود Python في عملية منفصلة مع timeout

    Args:
        code: كود Python
        timeout: المهلة بالثواني
    """
    try:
        # كتابة الكود لملف مؤقت
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".py", delete=False, encoding="utf-8"
        ) as f:
            f.write(code)
            temp_path = f.name

        try:
            result = subprocess.run(
                [sys.executable, temp_path],
                capture_output=True,
                text=True,
                timeout=timeout,
                env={"PATH": "/usr/bin:/usr/local/bin"},
            )
            return {
                "success": result.returncode == 0,
                "stdout": result.stdout[:5000],  # اقتطاع
                "stderr": result.stderr[:5000],
                "returncode": result.returncode,
            }
        finally:
            Path(temp_path).unlink(missing_ok=True)

    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "error": f"انتهت المهلة ({timeout} ثانية)",
            "stdout": "",
            "stderr": "TIMEOUT",
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "stdout": "",
            "stderr": str(e),
        }


TOOL_SCHEMA = {
    "name": "run_python",
    "description": "تنفيذ كود Python وإرجاع المخرجات. ⚠️ خطر أمني - استخدم بحذر.",
    "parameters": {
        "type": "object",
        "properties": {
            "code": {"type": "string", "description": "كود Python للتنفيذ"},
            "timeout": {
                "type": "integer",
                "description": "المهلة بالثواني (افتراضي 10)",
                "default": 10,
            },
        },
        "required": ["code"],
    },
}
