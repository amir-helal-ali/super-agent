# Dockerfile لواجهة Next.js Frontend - Super Agent
# متعدد المراحل للإنتاج

# === المرحلة 1: الـ dependencies ===
FROM node:20-slim AS deps

WORKDIR /app

# نسخ package files
COPY package.json package-lock.json* ./

# تثبيت الـ dependencies
RUN npm install --legacy-peer-deps

# === المرحلة 2: البناء ===
FROM node:20-slim AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# متغيرات البيئة للبناء
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production
ENV DISABLE_ESLINT_PLUGIN=true
ENV NEXT_TYPE_CHECK=false

# بناء المشروع (تجاهل lint و type errors)
RUN npx next build --no-lint

# === المرحلة 3: الإنتاج ===
FROM node:20-slim AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

# إنشاء مستخدم غير جذر
RUN addgroup --system --gid 1001 nodejs \
    && adduser --system --uid 1001 nextjs

# نسخ الملفات المطلوبة
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

# متغير للـ Zig backend
ENV ZIG_BACKEND_URL=http://zig-backend:8080

CMD ["node", "server.js"]
