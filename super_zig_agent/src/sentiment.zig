// src/sentiment.zig - تحليل المشاعر بالعربية والإنجليزية
const std = @import("std");

pub const Sentiment = enum { positive, negative, neutral, angry, sad, happy };

const POSITIVE_WORDS = [_][]const u8{
    "جيد", "ممتاز", "رائع", "جميل", "سعيد", "شكرا", "أحب", "حب", "مذهل",
    "مفيد", "نجاح", "أفضل", "تحسن", "فرح", "مبهر", "مميز", "إبداع",
    "good", "great", "excellent", "amazing", "love", "happy", "awesome",
    "nice", "wonderful", "perfect", "brilliant", "fantastic", "thanks",
};

const NEGATIVE_WORDS = [_][]const u8{
    "سيء", "فظيع", "حزين", "غاضب", "كره", "أكره", "مشكلة", "خطأ",
    "فشل", "صعب", "مستحيل", "تعب", "مرهق", "محبط", "خائب",
    "bad", "terrible", "hate", "awful", "horrible", "wrong", "fail",
    "difficult", "impossible", "tired", "frustrated", "disappointed",
};

const ANGRY_WORDS = [_][]const u8{
    "غاضب", "حانق", "غضبان", "أسفن", "مستفز", "أحمق", "غبي",
    "angry", "furious", "mad", "annoyed", "irritated", "stupid",
};

const SAD_WORDS = [_][]const u8{
    "حزين", "مكتئب", "تعبان", "يائس", "وحيد", "بكاء", "دموع",
    "sad", "depressed", "lonely", "crying", "hopeless", "miserable",
};

const HAPPY_WORDS = [_][]const u8{
    "سعيد", "فرحان", "مبسوط", "متحمس", "مسرور", "مبتهاج",
    "happy", "excited", "joyful", "delighted", "thrilled", "cheerful",
};

/// تحليل مشاعر النص
pub fn analyze(text: []const u8) Sentiment {
    var positive_score: usize = 0;
    var negative_score: usize = 0;
    var angry_score: usize = 0;
    var sad_score: usize = 0;
    var happy_score: usize = 0;

    for (POSITIVE_WORDS) |word| {
        if (std.mem.indexOf(u8, text, word) != null) positive_score += 1;
    }
    for (NEGATIVE_WORDS) |word| {
        if (std.mem.indexOf(u8, text, word) != null) negative_score += 1;
    }
    for (ANGRY_WORDS) |word| {
        if (std.mem.indexOf(u8, text, word) != null) angry_score += 1;
    }
    for (SAD_WORDS) |word| {
        if (std.mem.indexOf(u8, text, word) != null) sad_score += 1;
    }
    for (HAPPY_WORDS) |word| {
        if (std.mem.indexOf(u8, text, word) != null) happy_score += 1;
    }

    // تحديد المشاعر
    if (happy_score > 0 and happy_score >= positive_score) return .happy;
    if (angry_score > 0 and angry_score >= negative_score) return .angry;
    if (sad_score > 0 and sad_score >= negative_score) return .sad;
    if (positive_score > negative_score) return .positive;
    if (negative_score > positive_score) return .negative;
    return .neutral;
}

/// رد مناسب حسب المشاعر
pub fn responseForSentiment(s: Sentiment) []const u8 {
    return switch (s) {
        .happy => "أرى أنك سعيد! 🎉 هذا رائع! كيف أساعدك؟",
        .sad => "أشعر أنك حزين 😢 أنا هنا لك. هل تريد التحدث عن شيء؟",
        .angry => "يبدو أنك منزعج 😤 خذ نفساً عميقاً. كيف يمكنني المساعدة؟",
        .positive => "إيجابي! 👍 كيف يمكنني مساعدتك؟",
        .negative => "أفهم أن الأمور صعبة الآن. دعنا نحلها معاً 💪",
        .neutral => "",
    };
}
