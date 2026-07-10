// src/fuzzy.zig - مطابقة ضبابية للأسئلة
// يجد أقرب سؤال في قاعدة المعرفة حتى مع الأخطاء الإملائية
const std = @import("std");

/// حساب نسبة التشابه بين نصين (0-100)
pub fn similarity(a: []const u8, b: []const u8) usize {
    if (a.len == 0 or b.len == 0) return 0;

    // تطبيع: تحويل لـ lowercase وإزالة المسافات الزائدة
    var a_words = std.mem.tokenizeAny(u8, a, " \t\n\r.,;:!?'\"()[]{}");
    var b_words = std.mem.tokenizeAny(u8, b, " \t\n\r.,;:!?'\"()[]{}");

    var a_list = std.ArrayList([]const u8).init(std.heap.page_allocator);
    defer a_list.deinit();
    var b_list = std.ArrayList([]const u8).init(std.heap.page_allocator);
    defer b_list.deinit();

    while (a_words.next()) |w| a_list.append(w) catch {};
    while (b_words.next()) |w| b_list.append(w) catch {};

    if (a_list.items.len == 0 or b_list.items.len == 0) return 0;

    // عد الكلمات المشتركة
    var matches: usize = 0;
    for (a_list.items) |aw| {
        for (b_list.items) |bw| {
            if (wordMatch(aw, bw)) {
                matches += 1;
                break;
            }
        }
    }

    // النسبة المئوية بناءً على أقصر نص
    const min_len = @min(a_list.items.len, b_list.items.len);
    return matches * 100 / min_len;
}

/// هل الكلمتان متطابقتان أو متشابهتان؟
fn wordMatch(a: []const u8, b: []const u8) bool {
    if (a.len == 0 or b.len == 0) return false;

    // تطابق تام
    if (std.mem.eql(u8, a, b)) return true;

    // تطابق case-insensitive للإنجليزية
    if (std.ascii.eqlIgnoreCase(a, b)) return true;

    // إذا كانت إحداهما جزء من الأخرى
    if (a.len >= 3 and b.len >= 3) {
        if (std.mem.indexOf(u8, a, b) != null) return true;
        if (std.mem.indexOf(u8, b, a) != null) return true;
    }

    // تشابه تقريبي (Levenshtein مبسط)
    if (a.len >= 3 and b.len >= 3) {
        const diff: usize = if (a.len > b.len) a.len - b.len else b.len - a.len;
        if (diff <= 2) {
            // عد الأحرف المختلفة
            var diff_chars: usize = 0;
            const min_len = @min(a.len, b.len);
            var i: usize = 0;
            while (i < min_len) : (i += 1) {
                if (a[i] != b[i]) diff_chars += 1;
            }
            if (diff_chars <= 2) return true;
        }
    }

    return false;
}

/// البحث عن أفضل تطابق في قائمة
pub fn bestMatch(query: []const u8, candidates: []const []const u8) ?usize {
    var best_idx: ?usize = null;
    var best_score: usize = 0;

    for (candidates, 0..) |cand, i| {
        const score = similarity(query, cand);
        if (score > best_score and score >= 50) {
            best_score = score;
            best_idx = i;
        }
    }

    return best_idx;
}
