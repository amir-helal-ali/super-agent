"""
file_ops.py - أدوات معالجة الملفات (آمنة - داخل مجلد العمل فقط)
"""
import os
import shutil
from pathlib import Path
from typing import Dict, Any, List


# مجلد العمل المسموح - لمنع الوصول لخارج النظام
WORKSPACE = Path(os.getenv("AGENT_WORKSPACE", str(Path.home() / "super_agent_workspace")))
WORKSPACE.mkdir(parents=True, exist_ok=True)


def _safe_path(relative_path: str) -> Path:
    """التأكد من أن المسار داخل مجلد العمل فقط"""
    target = (WORKSPACE / relative_path).resolve()
    # منع المسارات الخارجة
    if not str(target).startswith(str(WORKSPACE)):
        raise ValueError(f"مسار غير مسموح: {relative_path}")
    return target


def read_file(path: str) -> Dict[str, Any]:
    """قراءة ملف نصي"""
    try:
        target = _safe_path(path)
        if not target.exists():
            return {"success": False, "error": f"الملف غير موجود: {path}"}
        if not target.is_file():
            return {"success": False, "error": f"ليس ملفاً: {path}"}

        content = target.read_text(encoding="utf-8", errors="replace")
        size = target.stat().st_size

        return {
            "success": True,
            "path": path,
            "content": content,
            "size": size,
            "lines": len(content.splitlines()),
        }
    except Exception as e:
        return {"success": False, "path": path, "error": str(e)}


def write_file(path: str, content: str) -> Dict[str, Any]:
    """كتابة ملف نصي"""
    try:
        target = _safe_path(path)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        return {
            "success": True,
            "path": path,
            "size": len(content),
            "absolute_path": str(target),
        }
    except Exception as e:
        return {"success": False, "path": path, "error": str(e)}


def list_files(path: str = ".") -> Dict[str, Any]:
    """سرد الملفات في مجلد"""
    try:
        target = _safe_path(path)
        if not target.exists():
            return {"success": False, "error": f"المجلد غير موجود: {path}"}
        if not target.is_dir():
            return {"success": False, "error": f"ليس مجلداً: {path}"}

        entries: List[Dict] = []
        for entry in sorted(target.iterdir()):
            entries.append({
                "name": entry.name,
                "type": "dir" if entry.is_dir() else "file",
                "size": entry.stat().st_size if entry.is_file() else None,
            })

        return {
            "success": True,
            "path": path,
            "count": len(entries),
            "entries": entries,
        }
    except Exception as e:
        return {"success": False, "path": path, "error": str(e)}


def create_directory(path: str) -> Dict[str, Any]:
    """إنشاء مجلد"""
    try:
        target = _safe_path(path)
        target.mkdir(parents=True, exist_ok=True)
        return {"success": True, "path": path, "absolute_path": str(target)}
    except Exception as e:
        return {"success": False, "path": path, "error": str(e)}


def delete_file(path: str) -> Dict[str, Any]:
    """حذف ملف أو مجلد"""
    try:
        target = _safe_path(path)
        if not target.exists():
            return {"success": False, "error": f"غير موجود: {path}"}
        if target.is_dir():
            shutil.rmtree(target)
        else:
            target.unlink()
        return {"success": True, "path": path}
    except Exception as e:
        return {"success": False, "path": path, "error": str(e)}


TOOL_SCHEMAS = [
    {
        "name": "read_file",
        "description": "قراءة محتوى ملف نصي من مساحة العمل.",
        "parameters": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "مسار الملف النسبي داخل مساحة العمل",
                }
            },
            "required": ["path"],
        },
    },
    {
        "name": "write_file",
        "description": "كتابة أو إنشاء ملف نصي في مساحة العمل.",
        "parameters": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "مسار الملف النسبي"},
                "content": {"type": "string", "description": "محتوى الملف"},
            },
            "required": ["path", "content"],
        },
    },
    {
        "name": "list_files",
        "description": "سرد محتويات مجلد في مساحة العمل.",
        "parameters": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "مسار المجلد (افتراضي: الجذر)",
                    "default": ".",
                }
            },
            "required": [],
        },
    },
    {
        "name": "create_directory",
        "description": "إنشاء مجلد جديد في مساحة العمل.",
        "parameters": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "مسار المجلد"}
            },
            "required": ["path"],
        },
    },
    {
        "name": "delete_file",
        "description": "حذف ملف أو مجلد من مساحة العمل.",
        "parameters": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "مسار العنصر"}
            },
            "required": ["path"],
        },
    },
]
