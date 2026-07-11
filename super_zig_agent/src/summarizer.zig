// src/summarizer.zig - ملخص المحادثة التلقائي
const std = @import("std");
const context_mod = @import("context.zig");

pub fn summarize(allocator: std.mem.Allocator, ctx: *context_mod.ConversationContext) ![]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try buf.appendSlice("📋 ملخص المحادثة:\n\n");

    // معلومات المستخدم
    if (ctx.getUserName()) |name| {
        try buf.writer().print("👤 المستخدم: {s}\n", .{name});
    }
    if (ctx.getUserLocation()) |loc| {
        try buf.writer().print("📍 الموقع: {s}\n", .{loc});
    }

    // عد الرسائل
    const msg_count = ctx.history.items.len;
    try buf.writer().print("💬 عدد الرسائل: {d}\n\n", .{msg_count});

    // استخراج المواضيع الرئيسية
    var topics = std.ArrayList([]const u8).init(allocator);
    defer topics.deinit();

    const topic_keywords = [_]struct { kw: []const u8, topic: []const u8 }{
        .{ .kw = "ذكاء اصطناعي", .topic = "الذكاء الاصطناعي" },
        .{ .kw = "برمجة", .topic = "البرمجة" },
        .{ .kw = "zig", .topic = "Zig" },
        .{ .kw = "حساب", .topic = "الحساب" },
        .{ .kw = "ترجم", .topic = "الترجمة" },
        .{ .kw = "طقس", .topic = "الطقس" },
        .{ .kw = "دولار", .topic = "العملات" },
        .{ .kw = "ملف", .topic = "الملفات" },
        .{ .kw = "رياضيات", .topic = "الرياضيات" },
        .{ .kw = "فيزياء", .topic = "الفيزياء" },
        .{ .kw = "كيمياء", .topic = "الكيمياء" },
        .{ .kw = "تاريخ", .topic = "التاريخ" },
        .{ .kw = "docker", .topic = "Docker" },
        .{ .kw = "git", .topic = "Git" },
        .{ .kw = "linux", .topic = "Linux" },
        .{ .kw = "python", .topic = "Python" },
        .{ .kw = "react", .topic = "React" },
        .{ .kw = "javascript", .topic = "JavaScript" },
    };

    for (ctx.history.items) |entry| {
        for (topic_keywords) |tk| {
            if (std.mem.indexOf(u8, entry.content, tk.kw) != null) {
                // تجنب التكرار
                var found = false;
                for (topics.items) |t| {
                    if (std.mem.eql(u8, t, tk.topic)) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    try topics.append(tk.topic);
                }
            }
        }
    }

    if (topics.items.len > 0) {
        try buf.appendSlice("📌 المواضيع التي ناقشناها:\n");
        for (topics.items) |topic| {
            try buf.writer().print("  • {s}\n", .{topic});
        }
    }

    // آخر 3 رسائل
    if (msg_count > 0) {
        try buf.appendSlice("\n🔄 آخر الرسائل:\n");
        const start = if (msg_count > 3) msg_count - 3 else 0;
        for (ctx.history.items[start..]) |entry| {
            const short_len = @min(entry.content.len, 60);
            try buf.writer().print("  {s}: {s}", .{ entry.role, entry.content[0..short_len] });
            if (entry.content.len > 60) try buf.appendSlice("...");
            try buf.append('\n');
        }
    }

    return buf.toOwnedSlice();
}
