"""
memory.py - نظام الذاكرة خفيف الوزن
يستخدم SQLite + تشفير بسيط للبحث الدلالي
لا يحتاج أي مكتبات ثقيلة - مثالي لـ 2GB RAM
"""
import sqlite3
import json
import hashlib
import re
from typing import List, Dict, Optional, Any
from datetime import datetime
from pathlib import Path
from collections import Counter

from ..config import MemoryConfig


class SimpleTokenizer:
    """مُجزّئ بسيط يدعم العربية والإنجليزية - بدون مكتبات ثقيلة"""

    # كلمات وقف شائعة (عربي + إنجليزي)
    STOPWORDS = {
        # العربية
        "في", "من", "إلى", "على", "عن", "مع", "هذا", "هذه", "ذلك", "التي",
        "الذي", "كان", "كانت", "قد", "لقد", "ما", "ماذا", "كيف", "أين",
        "هو", "هي", "هم", "نحن", "أنا", "أنت", "لا", "نعم", "إذا",
        # الإنجليزية
        "the", "a", "an", "is", "are", "was", "were", "be", "been",
        "have", "has", "had", "do", "does", "did", "will", "would",
        "could", "should", "may", "might", "must", "can", "of", "in",
        "on", "at", "to", "for", "with", "by", "from", "as", "this",
        "that", "these", "those", "it", "they", "we", "you", "he", "she",
    }

    @classmethod
    def tokenize(cls, text: str) -> List[str]:
        """تجزئة النص إلى رموز"""
        # إزالة التشكيل العربي والرموز الخاصة
        text = re.sub(r'[\u064B-\u0652\u0670]', '', text)
        # تجزئة على كل ما ليس حرف/رقم
        tokens = re.findall(r'[\u0600-\u06FF\u0750-\u077F\w]+', text.lower())
        # فلترة كلمات الوقف والكلمات القصيرة
        return [
            t for t in tokens
            if t not in cls.STOPWORDS and len(t) > 1
        ]


class Memory:
    """نظام الذاكرة الرئيسي"""

    def __init__(self, config: MemoryConfig):
        self.config = config
        # إنشاء المجلد إن لم يكن موجوداً
        Path(config.db_path).parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _init_db(self):
        """تهيئة قاعدة البيانات"""
        with sqlite3.connect(self.config.db_path) as conn:
            conn.executescript("""
                CREATE TABLE IF NOT EXISTS conversations (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id TEXT NOT NULL,
                    role TEXT NOT NULL,
                    content TEXT NOT NULL,
                    timestamp TEXT NOT NULL,
                    metadata TEXT
                );

                CREATE TABLE IF NOT EXISTS memory_facts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    key TEXT UNIQUE NOT NULL,
                    content TEXT NOT NULL,
                    source TEXT,
                    timestamp TEXT NOT NULL,
                    access_count INTEGER DEFAULT 0
                );

                CREATE TABLE IF NOT EXISTS memory_tokens (
                    fact_id INTEGER NOT NULL,
                    token TEXT NOT NULL,
                    count INTEGER DEFAULT 1,
                    FOREIGN KEY (fact_id) REFERENCES memory_facts(id) ON DELETE CASCADE
                );

                CREATE INDEX IF NOT EXISTS idx_session ON conversations(session_id);
                CREATE INDEX IF NOT EXISTS idx_token ON memory_tokens(token);
                CREATE INDEX IF NOT EXISTS idx_fact ON memory_facts(key);

                CREATE VIRTUAL TABLE IF NOT EXISTS memory_fts USING fts5(
                    content, content='memory_facts', content_rowid='id'
                );
            """)

    def add_message(
        self,
        session_id: str,
        role: str,
        content: str,
        metadata: Optional[Dict] = None
    ):
        """إضافة رسالة للمحادثة"""
        with sqlite3.connect(self.config.db_path) as conn:
            conn.execute(
                """INSERT INTO conversations
                   (session_id, role, content, timestamp, metadata)
                   VALUES (?, ?, ?, ?, ?)""",
                (
                    session_id, role, content,
                    datetime.utcnow().isoformat(),
                    json.dumps(metadata or {})
                )
            )

    def get_history(
        self,
        session_id: str,
        limit: Optional[int] = None
    ) -> List[Dict]:
        """استرجاع تاريخ المحادثة"""
        limit = limit or self.config.short_term_limit
        with sqlite3.connect(self.config.db_path) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute(
                """SELECT role, content, timestamp, metadata
                   FROM conversations
                   WHERE session_id = ?
                   ORDER BY id DESC
                   LIMIT ?""",
                (session_id, limit)
            ).fetchall()

        # ترتيب زمني صحيح (من الأقدم للأحدث)
        rows = list(reversed(rows))
        return [
            {
                "role": r["role"],
                "content": r["content"],
                "timestamp": r["timestamp"],
                "metadata": json.loads(r["metadata"] or "{}"),
            }
            for r in rows
        ]

    def remember(
        self,
        key: str,
        content: str,
        source: str = "user"
    ) -> bool:
        """حفظ معلومة في الذاكرة طويلة المدى"""
        tokens = SimpleTokenizer.tokenize(content)
        token_counts = Counter(tokens)

        with sqlite3.connect(self.config.db_path) as conn:
            try:
                cur = conn.execute(
                    """INSERT OR REPLACE INTO memory_facts
                       (key, content, source, timestamp, access_count)
                       VALUES (?, ?, ?, ?, 0)""",
                    (key, content, source, datetime.utcnow().isoformat())
                )
                fact_id = cur.lastrowid

                # إذا كان استبدال، احذف الرموز القديمة
                if cur.rowcount == 0:
                    existing = conn.execute(
                        "SELECT id FROM memory_facts WHERE key = ?", (key,)
                    ).fetchone()
                    if existing:
                        fact_id = existing[0]
                        conn.execute(
                            "DELETE FROM memory_tokens WHERE fact_id = ?",
                            (fact_id,)
                        )

                # إدراج الرموز الجديدة
                conn.executemany(
                    """INSERT INTO memory_tokens (fact_id, token, count)
                       VALUES (?, ?, ?)""",
                    [(fact_id, tok, cnt) for tok, cnt in token_counts.items()]
                )

                # تحديث FTS
                conn.execute(
                    "INSERT OR REPLACE INTO memory_fts(rowid, content) VALUES (?, ?)",
                    (fact_id, content)
                )
                return True
            except sqlite3.Error as e:
                print(f"Memory error: {e}")
                return False

    def recall(self, query: str, top_k: Optional[int] = None) -> List[Dict]:
        """استرجاع المعلومات ذات الصلة من الذاكرة طويلة المدى"""
        top_k = top_k or self.config.long_term_top_k
        tokens = SimpleTokenizer.tokenize(query)

        if not tokens:
            # استخدم FTS كبديل
            return self._recall_fts(query, top_k)

        # حساب درجات التشابه باستخدام TF-IDF مبسط
        placeholders = ",".join("?" * len(tokens))
        with sqlite3.connect(self.config.db_path) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute(
                f"""SELECT m.id, m.key, m.content, m.source,
                           SUM(t.count) as score
                    FROM memory_tokens t
                    JOIN memory_facts m ON t.fact_id = m.id
                    WHERE t.token IN ({placeholders})
                    GROUP BY m.id
                    ORDER BY score DESC
                    LIMIT ?""",
                (*tokens, top_k)
            ).fetchall()

        return [
            {
                "key": r["key"],
                "content": r["content"],
                "source": r["source"],
                "score": r["score"],
            }
            for r in rows
        ]

    def _recall_fts(self, query: str, top_k: int) -> List[Dict]:
        """بحث بالنص الكامل كاحتياط"""
        # تنظيف الاستعلام
        clean = re.sub(r'[^\w\s\u0600-\u06FF]', ' ', query).strip()
        if not clean:
            return []
        fts_query = " OR ".join(clean.split())

        with sqlite3.connect(self.config.db_path) as conn:
            conn.row_factory = sqlite3.Row
            try:
                rows = conn.execute(
                    """SELECT m.id, m.key, m.content, m.source,
                              bm25(memory_fts) as score
                       FROM memory_fts
                       JOIN memory_facts m ON m.id = memory_fts.rowid
                       WHERE memory_fts MATCH ?
                       ORDER BY score
                       LIMIT ?""",
                    (fts_query, top_k)
                ).fetchall()
            except sqlite3.OperationalError:
                return []

        return [
            {
                "key": r["key"],
                "content": r["content"],
                "source": r["source"],
                "score": -r["score"],
            }
            for r in rows
        ]

    def forget(self, key: str) -> bool:
        """نسيان معلومة"""
        with sqlite3.connect(self.config.db_path) as conn:
            cur = conn.execute(
                "DELETE FROM memory_facts WHERE key = ?", (key,)
            )
            return cur.rowcount > 0

    def list_facts(self, limit: int = 100) -> List[Dict]:
        """سرد كل المعلومات المحفوظة"""
        with sqlite3.connect(self.config.db_path) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute(
                """SELECT key, content, source, timestamp, access_count
                   FROM memory_facts
                   ORDER BY timestamp DESC
                   LIMIT ?""",
                (limit,)
            ).fetchall()
        return [dict(r) for r in rows]

    def clear_session(self, session_id: str):
        """مسح محادثة معينة"""
        with sqlite3.connect(self.config.db_path) as conn:
            conn.execute(
                "DELETE FROM conversations WHERE session_id = ?",
                (session_id,)
            )

    def stats(self) -> Dict:
        """إحصائيات الذاكرة"""
        with sqlite3.connect(self.config.db_path) as conn:
            conv_count = conn.execute(
                "SELECT COUNT(*) FROM conversations"
            ).fetchone()[0]
            fact_count = conn.execute(
                "SELECT COUNT(*) FROM memory_facts"
            ).fetchone()[0]
            session_count = conn.execute(
                "SELECT COUNT(DISTINCT session_id) FROM conversations"
            ).fetchone()[0]
        return {
            "conversations": conv_count,
            "facts": fact_count,
            "sessions": session_count,
            "db_size_bytes": Path(self.config.db_path).stat().st_size
                             if Path(self.config.db_path).exists() else 0,
        }
