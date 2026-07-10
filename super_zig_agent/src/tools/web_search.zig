// src/tools/web_search.zig - بحث ويب فعّال
const std = @import("std");
const web = @import("../web/mod.zig");

/// بحث في الويب وإرجاع ملخص النتائج
pub fn search(allocator: std.mem.Allocator, query: []const u8) ![]u8 {
    // استخدام DuckDuckGo HTML
    const search_url = try std.fmt.allocPrint(allocator, "https://html.duckduckgo.com/html/?q={s}", .{query});
    defer allocator.free(search_url);

    var response = web.fetch(allocator, search_url, 512 * 1024) catch {
        return std.fmt.allocPrint(allocator, "تعذر البحث في الإنترنت. تحقق من الاتصال.", .{});
    };
    defer response.deinit();

    if (response.status != 200) {
        return std.fmt.allocPrint(allocator, "فشل البحث (HTTP {d})", .{response.status});
    }

    // استخراج النص
    const text = web.extractText(allocator, response.body) catch {
        return std.fmt.allocPrint(allocator, "تعذر تحليل نتائج البحث.", .{});
    };
    defer allocator.free(text);

    // اقتطاع لأول 1500 حرف
    const max_len = @min(text.len, 1500);
    return std.fmt.allocPrint(allocator, "🔍 نتائج البحث عن '{s}':\n\n{s}", .{ query, text[0..max_len] });
}

/// كشف هل الطلب يحتاج بحث ويب
pub fn needsWebSearch(input: []const u8) bool {
    const indicators = [_][]const u8{
        "ابحث عن", "بحث عن", "search for", "google",
        "اخر اخبار", "آخر أخبار", "latest news",
        "ما هو سعر", "كم سعر", "what is the price",
        "من هو", "who is", "tell me about",
    };
    for (indicators) |ind| {
        if (std.mem.indexOf(u8, input, ind) != null) return true;
    }
    return false;
}

/// استخراج استعلام البحث من الرسالة
pub fn extractQuery(input: []const u8) []const u8 {
    const markers = [_][]const u8{ "ابحث عن ", "بحث عن ", "search for ", "google " };
    for (markers) |m| {
        if (std.mem.indexOf(u8, input, m)) |pos| {
            return std.mem.trim(u8, input[pos + m.len ..], " \t\n.؟?");
        }
    }
    return input;
}
