// src/responses.zig - ردود سياقية ذكية ومتنوعة
const std = @import("std");

// ردود ترحيب متنوعة
const GREETINGS = [_][]const u8{
    "مرحبا بك! كيف يمكنني مساعدتك اليوم؟",
    "أهلا وسهلا! أنا هنا لمساعدتك. ماذا تريد أن تعرف؟",
    "السلام عليكم! أنا Super Agent جاهز لأسئلتك.",
    "مرحبا! سعيد برؤيتك. كيف أساعدك؟",
};

// ردود شكر متنوعة
const THANKS = [_][]const u8{
    "العفو! سعيد بمساعدتك. 😊",
    "لا شكر على واجب! هل لديك سؤال آخر؟",
    "على الرحب والسعة! أنا هنا دائماً.",
    "أي خدمة! لا تتردد في السؤال.",
};

// ردود وداع متنوعة
const FAREWELLS = [_][]const u8{
    "إلى اللقاء! كان من دواعي سروري مساعدتك. 👋",
    "وداعاً! عُد متى شئت.",
    "مع السلامة! أتطلع لرؤيتك مرة أخرى.",
    "إلى اللقاء! استمر في التعلم والاكتشاف.",
};

// ردود عدم الفهم
const CONFUSED = [_][]const u8{
    "لم أفهم رسالتك تماماً. هل يمكنك إعادة الصياغة؟",
    "عذراً، لم أتمكن من فهم سؤالك. جرّب صياغة مختلفة.",
    "سؤالك غير واضح لي. هل يمكنك التوضيح أكثر؟",
    "أحتاج لمزيد من التوضيح. ماذا تقصد بالضبط؟",
};

/// الحصول على رد عشوائي من قائمة
pub fn randomResponse(responses: []const []const u8) []const u8 {
    if (responses.len == 0) return "";
    var rng = std.Random.DefaultPrng.init(@bitCast(std.time.timestamp()));
    const idx = rng.random().uintLessThan(usize, responses.len);
    return responses[idx];
}

pub fn greeting() []const u8 {
    return randomResponse(&GREETINGS);
}

pub fn thanks() []const u8 {
    return randomResponse(&THANKS);
}

pub fn farewell() []const u8 {
    return randomResponse(&FAREWELLS);
}

pub fn confused() []const u8 {
    return randomResponse(&CONFUSED);
}

/// رد مقترح بناءً على نوع السؤال
pub fn suggestResponse(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    // اقتراحات بناءً على كلمات مفتاحية
    if (std.mem.indexOf(u8, input, "كيف") != null) {
        return std.fmt.allocPrint(allocator,
            \\{s}
            \\
            \\جرّب أن تسأل:
            \\• كيف أتعلم البرمجة؟
            \\• كيف يعمل الذكاء الاصطناعي؟
            \\• كيف أستخدم الحاسبة؟
            , .{confused()});
    }

    if (std.mem.indexOf(u8, input, "ما") != null or std.mem.indexOf(u8, input, "ماذا") != null) {
        return std.fmt.allocPrint(allocator,
            \\{s}
            \\
            \\جرّب أن تسأل:
            \\• ما هو الذكاء الاصطناعي؟
            \\• ما هي لغة Zig؟
            \\• ما هي الخوارزمية؟
            \\• ما هي الفلسفة؟
            , .{confused()});
    }

    if (std.mem.indexOf(u8, input, "لماذا") != null) {
        return std.fmt.allocPrint(allocator,
            \\{s}
            \\
            \\جرّب:
            \\• لماذا Zig سريعة؟
            \\• لماذا التعلم الآلي مهم؟
            , .{confused()});
    }

    // رد عام مع اقتراحات
    return std.fmt.allocPrint(allocator,
        \\{s}
        \\
        \\الأوامر المتاحة:
        \\• 'مساعدة' - عرض كل الأوامر
        \\• 'sqrt(25)+10' - حساب
        \\• 'كم الساعة' - وقت
        \\• 'طقس في القاهرة' - طقس
        \\• 'سعر الدولار' - عملات
        \\• 'ترجم للإنجليزية: مرحبا' - ترجمة
        \\• 'ما هو الذكاء الاصطناعي' - معلومات
        \\• 'اسمي أحمد' - تعريف بالنفس
        \\• 'اخبرني نكتة' - ترفيه
        , .{confused()});
}
