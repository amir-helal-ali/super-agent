# Super Agent - وكيل ذكاء اصطناعي خارق

وكيل ذكاء اصطناعي خفيف الوزن مبني بلغة **Zig** مع واجهة **React/Next.js**، يعمل على 2GB RAM بدون GPU.

## المميزات

- 🚀 **خادم Zig خفيف**: 30-50 MB RAM فقط
- 🎨 **واجهة React**: Next.js 16 + TypeScript + shadcn/ui
- 🔄 **WebSocket**: real-time chat
- 🧠 **نموذج Mini-GPT**: Transformer مع backpropagation كامل
- 🛠️ **أدوات مدمجة**: حاسبة، مترجم (AR/EN/FR/ES)، وقت، ملفات، نظام
- 🐳 **Docker**: تشغيل بضغطة واحدة

## التشغيل السريع بـ Docker

### المتطلبات
- Docker 20+ و Docker Compose

### 1. تشغيل كل الخدمات
```bash
# بناء وتشغيل
docker-compose up -d --build

# عرض السجلات
docker-compose logs -f

# إيقاف
docker-compose down
```

### 2. الوصول
- **الواجهة**: http://localhost:3000
- **API مباشر**: http://localhost:8080/api/stats

### 3. مع Caddy (للإنتاج)
```bash
docker-compose --profile production up -d --build
```

## التشغيل اليدوي (بدون Docker)

### خادم Zig
```bash
cd super_zig_agent

# تثبيت Zig 0.14.0
curl -sL https://ziglang.org/download/0.14.0/zig-linux-x86_64-0.14.0.tar.xz | tar -xJ
export PATH=$PWD/zig-linux-x86_64-0.14.0:$PATH

# بناء وتشغيل
zig build --release=fast
./zig-out/bin/super-agent --server
```

### واجهة React
```bash
# في terminal آخر
npm install --legacy-peer-deps
npm run dev
```

## بنية المشروع

```
super-agent/
├── docker-compose.yml          # Docker orchestration
├── Dockerfile                  # Next.js frontend
├── next.config.js              # Next.js config
├── package.json                # Frontend dependencies
├── src/                        # React/Next.js code
│   ├── app/                    # App router
│   │   ├── page.tsx            # Main chat interface
│   │   ├── layout.tsx          # Root layout
│   │   └── api/agent/[...path]/route.ts  # API proxy
│   ├── components/ui/          # shadcn/ui components
│   └── lib/agent-api.ts        # API helper
├── super_zig_agent/            # Zig backend
│   ├── Dockerfile              # Zig backend Docker
│   ├── build.zig               # Build config
│   ├── src/
│   │   ├── main.zig            # Entry point
│   │   ├── agent.zig           # Main agent logic
│   │   ├── stable_server.zig   # HTTP + WebSocket server
│   │   ├── nn/                 # Neural network (Transformer)
│   │   ├── tools/              # Tools (calculator, translator, etc.)
│   │   └── web/                # Web crawler
│   └── README.md               # Zig backend details
└── README.md                   # This file
```

## API Endpoints

| Endpoint | Method | الوصف |
|----------|--------|--------|
| `/api/stats` | GET | إحصائيات الوكيل |
| `/api/chat` | POST | محادثة مع الوكيل |
| `/api/sessions` | GET/POST | إدارة الجلسات |
| `/api/sessions/{id}` | GET/DELETE | جلسة محددة |
| `/api/learn` | POST | تعلم من نص |
| `/api/model/train` | POST | تدريب النموذج |
| `/api/generate` | POST | توليد نص |
| `/api/tools` | GET | قائمة الأدوات |
| `/api/memory` | GET | الذاكرة المحفوظة |

## WebSocket

```javascript
// الاتصال بالـ WebSocket
const ws = new WebSocket('ws://localhost:8080/')

// إرسال رسالة
ws.send(JSON.stringify({ message: 'مرحبا' }))

// استقبال الرد
ws.onmessage = (event) => {
  const data = JSON.parse(event.data)
  console.log(data.answer, data.tools)
}
```

## متطلبات السيرفر

| المستوى | RAM | CPU | التكلفة |
|---------|-----|-----|---------|
| الحد الأدنى | 512MB | 1 vCPU | $4/شهر |
| المُوصى به | 2GB | 2-4 cores | $7-12/شهر |
| المجاني | 24GB | 4 ARM cores | Oracle Cloud |

تفاصيل كاملة: [`download/SERVER_REQUIREMENTS.md`](download/SERVER_REQUIREMENTS.md)

## التقنيات

### Backend (Zig)
- Zig 0.14.0
- Mini-GPT Transformer (5,800+ سطر Zig)
- Autograd + Adam optimizer
- WebSocket server
- SQLite-free memory (JSON)

### Frontend (React)
- Next.js 16 (App Router)
- React 19 + TypeScript 5
- Tailwind CSS 4 + shadcn/ui
- Lucide icons + Sonner toasts

## الترخيص

MIT License - حر للاستخدام التجاري والتعليمي.
