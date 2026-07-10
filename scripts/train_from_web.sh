#!/bin/bash
# train_from_web.sh - تدريب Super Agent من الإنترنت بمصادر متعددة
# يشغل حاوية Docker مؤقتة للتدريب

echo "=== Super Agent - التدريب من الإنترنت ==="
echo "بدء جمع البيانات من مصادر متعددة..."
echo ""

# قائمة المصادر العربية
AR_SOURCES=(
    "https://ar.wikipedia.org/wiki/الذكاء_الاصطناعي"
    "https://ar.wikipedia.org/wiki/تعلم_الآلة"
    "https://ar.wikipedia.org/wiki/شبكة_عصبية_اصطناعية"
    "https://ar.wikipedia.org/wiki/معالجة_اللغات_الطبيعية"
    "https://ar.wikipedia.org/wiki/برمجة"
    "https://ar.wikipedia.org/wiki/حاسوب"
    "https://ar.wikipedia.org/wiki/إنترنت"
    "https://ar.wikipedia.org/wiki/لغة_برمجة"
    "https://ar.wikipedia.org/wiki/خوارزمية"
    "https://ar.wikipedia.org/wiki/بيانات_ضخمة"
    "https://ar.wikipedia.org/wiki/روبوت"
    "https://ar.wikipedia.org/wiki/ترجمة_آلية"
    "https://ar.wikipedia.org/wiki/نظام_خبير"
)

# قائمة المصادر الإنجليزية
EN_SOURCES=(
    "https://en.wikipedia.org/wiki/Artificial_intelligence"
    "https://en.wikipedia.org/wiki/Machine_learning"
    "https://en.wikipedia.org/wiki/Neural_network"
    "https://en.wikipedia.org/wiki/Natural_language_processing"
    "https://en.wikipedia.org/wiki/Transformer_(deep_learning_architecture)"
    "https://en.wikipedia.org/wiki/Programming_language"
    "https://en.wikipedia.org/wiki/Computer_science"
    "https://en.wikipedia.org/wiki/Algorithm"
    "https://en.wikipedia.org/wiki/Big_data"
    "https://en.wikipedia.org/wiki/Robotics"
    "https://en.wikipedia.org/wiki/Deep_learning"
    "https://en.wikipedia.org/wiki/Data_science"
    "https://en.wikipedia.org/wiki/Zig_(programming_language)"
)

# مصادر إضافية متنوعة
EXTRA_SOURCES=(
    "https://ar.wikipedia.org/wiki/رياضيات"
    "https://ar.wikipedia.org/wiki/فيزياء"
    "https://ar.wikipedia.org/wiki/كيمياء"
    "https://ar.wikipedia.org/wiki/أحياء"
    "https://ar.wikipedia.org/wiki/تاريخ"
    "https://ar.wikipedia.org/wiki/جغرافيا"
    "https://ar.wikipedia.org/wiki/فلسفة"
    "https://ar.wikipedia.org/wiki/أدب"
    "https://ar.wikipedia.org/wiki/شعر"
    "https://ar.wikipedia.org/wiki/موسيقى"
)

ALL_SOURCES=("${AR_SOURCES[@]}" "${EN_SOURCES[@]}" "${EXTRA_SOURCES[@]}")

echo "عدد المصادر: ${#ALL_SOURCES[@]}"
echo ""

# بناء حجة URLs
URLS_ARG=""
for url in "${ALL_SOURCES[@]}"; do
    URLS_ARG="$URLS_ARG $url"
done

echo "بدء التدريب من ${#ALL_SOURCES[@]} مصدر..."
echo "سيستغرق هذا عدة دقائق..."
echo ""

# تشغيل التدريب في حاوية Docker
docker compose run --rm zig-backend ./train-agent --max-pages 50 $URLS_ARG

echo ""
echo "=== اكتمل التدريب! ==="
echo "إعادة تشغيل الخادم لتحميل النموذج الجديد..."
docker compose restart zig-backend

echo "انتظار بدء الخادم..."
sleep 5

echo "التحقق من النموذج:"
curl -s http://localhost:8080/api/stats

echo ""
echo "=== تم! ==="
