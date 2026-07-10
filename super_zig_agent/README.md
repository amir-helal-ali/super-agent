# Super Agent - وكيل ذكاء اصطناعي خارق بلغة Zig

وكيل ذكاء اصطناعي خفيف الوزن مبني بالكامل بلغة **Zig**، يعمل على مواصفات منخفضة جداً:
- **RAM**: 2GB فقط
- **معالج**: 4 cores (بدون GPU)
- **بدون كارت شاشة**
- **بدون اعتماديات خارجية** - كل شيء مدمج في Zig

## المميزات

- **نموذج لغوي مدمج**: Mini-GPT بُني من الصفر في Zig (طبقات Transformer، Attention، Embeddings)
- **مُجزّئ تلقائي**: Tokenizer يتعلم الكلمات الجديدة تلقائياً
- **ذاكرة دائمة**: نظام ذاكرة بسيط بدون SQLite - ملفات JSON
- **تعلّم من الإنترنت**: زاحف ويب مدمج يجلب النصوص ويتعلم منها
- **أدوات داخلية**: حاسبة آمنة، بحث ويب، استرجاع ذاكرة
- **بدون مكتبات خارجية**: كل شيء في مكتبة Zig القياسية

## البنية

```
super_zig_agent/
├── build.zig              # إعداد البناء
├── src/
│   ├── main.zig           # نقطة دخول CLI
│   ├── train.zig          # أداة التدريب
│   ├── agent.zig          # الوكيل الرئيسي
│   ├── model.zig          # نموذج Mini-GPT
│   ├── tokenizer.zig      # مُجزّئ تلقائي
│   ├── memory.zig         # ذاكرة دائمة
│   ├── trainer.zig        # محرك التدريب
│   ├── tests.zig          # اختبارات
│   ├── nn/                # الشبكة العصبية
│   │   ├── tensor.zig     # عمليات الموترات
│   │   ├── linear.zig     # طبقة Linear
│   │   ├── embedding.zig  # Embeddings + Positional
│   │   ├── attention.zig  # Multi-Head Attention
│   │   └── transformer.zig # كتلة Transformer
│   ├── tools/             # أدوات الوكيل
│   │   └── calculator.zig # حاسبة آمنة
│   └── web/               # أدوات الويب
│       ├── http.zig       # عميل HTTP
│       └── crawler.zig    # زاحف ويب
└── data/                  # بيانات النموذج والذاكرة
```

## البناء

```bash
# تثبيت Zig 0.14.0
curl -sL https://ziglang.org/download/0.14.0/zig-linux-x86_64-0.14.0.tar.xz | tar -xJ
export PATH=$PWD/zig-linux-x86_64-0.14.0:$PATH

# بناء المشروع
cd super_zig_agent
zig build

# النتيجة في zig-out/bin/
```

## الاستخدام

### 1. المحادثة التفاعلية
```bash
./zig-out/bin/super-agent
# أو
./zig-out/bin/super-agent --lang ar
```

### 2. رسالة واحدة (من stdin)
```bash
echo "مرحبا" | ./zig-out/bin/super-agent --chat
echo "2 + 3 * 4" | ./zig-out/bin/super-agent --chat
```

### 3. عرض الإحصائيات
```bash
./zig-out/bin/super-agent --stats
```

### 4. التعلم من نص
```bash
cat corpus.txt | ./zig-out/bin/super-agent --learn
```

### 5. تدريب النموذج
```bash
# تدريب أساسي
./zig-out/bin/train-agent

# تدريب من ملف
./zig-out/bin/train-agent --file corpus.txt

# تدريب من الإنترنت
./zig-out/bin/train-agent https://example.com https://wikipedia.org

# تدريب مستمر
./zig-out/bin/train-agent --continuous https://wikipedia.org
```

## أمثلة

```
$ echo "مرحبا" | ./zig-out/bin/super-agent --chat
مرحبا بك! أنا Super Agent - وكيل ذكاء اصطناعي خارق خفيف الوزن. كيف يمكنني مساعدتك؟

$ echo "2 + 3 * 4" | ./zig-out/bin/super-agent --chat
14

$ echo "(15 + 5) * 2 / 4" | ./zig-out/bin/super-agent --chat
10

$ echo "من انت" | ./zig-out/bin/super-agent --chat
أنا Super Agent - وكيل ذكاء اصطناعي مبني بلغة Zig، أعمل على 2GB RAM ومعالج 4 cores بدون GPU. أتعلم من الإنترنت تلقائياً.
```

## المواصفات التقنية

| العنصر | القيمة |
|--------|--------|
| حجم النموذج | ~330K معامل (config افتراضي) |
| Embedding Dim | 128 |
| عدد الطبقات | 2 |
| عدد Heads | 4 |
| Max Seq Len | 128 |
| FFN Ratio | 2 |
| اللغة الافتراضية | العربية |
| الاعتماديات | Zig stdlib فقط |

## تطوير مستقبلي

- [ ] Backpropagation كامل لتحسين التدريب
- [ ] BPE tokenizer أكثر تطوراً
- [ ] HTTP Server mode لاستخدام كـ API
- [ ] Quantization INT8 لتقليل الذاكرة
- [ ] دعم streaming للتوليد

## الترخيص

مفتوح المصدر للاستخدام التعليمي والتجاري.
