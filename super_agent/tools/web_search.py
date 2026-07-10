"""
web_search.py - أداة البحث في الويب
تستخدم DuckDuckGo Lite (بدون API key) كخيار افتراضي
"""
import re
from typing import Dict, Any, List
from urllib.parse import quote_plus

import httpx
from bs4 import BeautifulSoup


HEADERS = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept-Language": "ar,en-US;q=0.9,en;q=0.8",
}


async def search(query: str, max_results: int = 5) -> Dict[str, Any]:
    """
    البحث في DuckDuckGo بدون مفتاح API

    Args:
        query: استعلام البحث
        max_results: أقصى عدد للنتائج

    Returns:
        dict يحتوي على النتائج
    """
    results: List[Dict] = []

    try:
        async with httpx.AsyncClient(timeout=15, follow_redirects=True) as client:
            # DuckDuckGo HTML (خفيف)
            url = "https://html.duckduckgo.com/html/"
            data = {"q": query, "kl": "ar"}

            resp = await client.post(url, data=data, headers=HEADERS)
            resp.raise_for_status()

            soup = BeautifulSoup(resp.text, "html.parser")

            for item in soup.select(".result")[:max_results]:
                title_el = item.select_one(".result__title a")
                snippet_el = item.select_one(".result__snippet")
                url_el = item.select_one(".result__url")

                if not title_el:
                    continue

                title = title_el.get_text(strip=True)
                # DuckDuckGo يستخدم redirect - نستخرج URL الفعلي
                href = title_el.get("href", "")
                actual_url = _extract_ddg_url(href)

                snippet = snippet_el.get_text(strip=True) if snippet_el else ""
                display_url = url_el.get_text(strip=True) if url_el else actual_url

                results.append({
                    "title": title,
                    "url": actual_url,
                    "snippet": snippet,
                    "display_url": display_url,
                })

        return {
            "success": True,
            "query": query,
            "count": len(results),
            "results": results,
        }

    except Exception as e:
        return {
            "success": False,
            "query": query,
            "error": str(e),
            "results": [],
        }


def _extract_ddg_url(redirect_url: str) -> str:
    """استخراج URL الفعلي من رابط DuckDuckGo المُعاد توجيهه"""
    # شكل: //duckduckgo.com/l/?uddg=<encoded_url>&...
    match = re.search(r"uddg=([^&]+)", redirect_url)
    if match:
        from urllib.parse import unquote
        return unquote(match.group(1))
    return redirect_url


async def fetch_page(url: str, max_chars: int = 3000) -> Dict[str, Any]:
    """
    جلب محتوى صفحة ويب

    Args:
        url: رابط الصفحة
        max_chars: أقصى عدد من الأحرف
    """
    try:
        async with httpx.AsyncClient(timeout=15, follow_redirects=True) as client:
            resp = await client.get(url, headers=HEADERS)
            resp.raise_for_status()

            soup = BeautifulSoup(resp.text, "html.parser")

            # إزالة العناصر غير المهمة
            for tag in soup(["script", "style", "nav", "footer", "header"]):
                tag.decompose()

            # استخراج العنوان
            title = soup.title.string.strip() if soup.title and soup.title.string else ""

            # استخراج النص
            text = soup.get_text(separator="\n", strip=True)
            # إزالة الأسطر الفارغة المتكررة
            lines = [line for line in text.split("\n") if line.strip()]
            text = "\n".join(lines)

            # اقتطاع
            if len(text) > max_chars:
                text = text[:max_chars] + "..."

            return {
                "success": True,
                "url": url,
                "title": title,
                "content": text,
                "length": len(text),
            }
    except Exception as e:
        return {
            "success": False,
            "url": url,
            "error": str(e),
        }


TOOL_SCHEMA_SEARCH = {
    "name": "web_search",
    "description": "البحث في الويب عن معلومات حديثة. استخدم للحصول على معلومات لم تكن تعرفها أو للتحقق من الحقائق.",
    "parameters": {
        "type": "object",
        "properties": {
            "query": {"type": "string", "description": "استعلام البحث"},
            "max_results": {
                "type": "integer",
                "description": "أقصى عدد للنتائج (افتراضي 5)",
                "default": 5,
            },
        },
        "required": ["query"],
    },
}

TOOL_SCHEMA_FETCH = {
    "name": "fetch_page",
    "description": "قراءة محتوى صفحة ويب من رابط معين.",
    "parameters": {
        "type": "object",
        "properties": {
            "url": {"type": "string", "description": "رابط الصفحة"},
            "max_chars": {
                "type": "integer",
                "description": "أقصى عدد من الأحرف (افتراضي 3000)",
                "default": 3000,
            },
        },
        "required": ["url"],
    },
}
