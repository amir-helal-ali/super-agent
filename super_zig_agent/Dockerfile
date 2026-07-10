# Dockerfile لخادم Zig Backend - Super Agent
# متعدد المراحل للحصول على أصغر صورة ممكنة

# === المرحلة 1: بناء Zig ===
FROM debian:bookworm-slim AS zig-builder

# تثبيت الـ dependencies الأساسية
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    xz-utils \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# تثبيت Zig 0.14.0
WORKDIR /tmp
RUN curl -sL https://ziglang.org/download/0.14.0/zig-linux-x86_64-0.14.0.tar.xz -o zig.tar.xz \
    && tar -xf zig.tar.xz \
    && mv zig-linux-x86_64-0.14.0 /opt/zig \
    && ln -sf /opt/zig/zig /usr/local/bin/zig \
    && rm zig.tar.xz \
    && zig version

# نسخ كود المصدر
WORKDIR /app
COPY super_zig_agent/ ./super_zig_agent/

# بناء المشروع بـ ReleaseFast
WORKDIR /app/super_zig_agent
RUN zig build --release=fast

# === المرحلة 2: الصورة النهائية ===
FROM debian:bookworm-slim AS runtime

# تثبيت الـ dependencies الضرورية فقط للتشغيل
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libgcc-s1 \
    && rm -rf /var/lib/apt/lists/*

# إنشاء مستخدم غير جذر
RUN useradd -m -s /bin/bash agent

# نسخ الـ binary من مرحلة البناء
COPY --from=zig-builder /app/super_zig_agent/zig-out/bin/super-agent /app/super-agent
COPY --from=zig-builder /app/super_zig_agent/zig-out/bin/train-agent /app/train-agent

# إنشاء مجلدات البيانات
RUN mkdir -p /app/data/model /app/data/memory /app/data/workspace \
    && chown -R agent:agent /app

# التبديل للمستخدم agent
USER agent
WORKDIR /app

# المنفذ
EXPOSE 8080

# متغيرات البيئة
ENV ZIG_SERVER_PORT=8080
ENV ZIG_MODEL_DIR=/app/data/model
ENV ZIG_MEMORY_DIR=/app/data/memory

# حجم البيانات
VOLUME ["/app/data"]

# التحقق من الصحة
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://127.0.0.1:8080/api/stats || exit 1

# تشغيل الخادم
CMD ["./super-agent", "--server"]
