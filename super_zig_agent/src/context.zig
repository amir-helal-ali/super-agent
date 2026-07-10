// src/context.zig - نظام سياق المحادثة
// يتذكر آخر الرسائل ويستخرج معلومات عن المستخدم
const std = @import("std");

pub const ContextEntry = struct {
    role: []const u8,
    content: []const u8,
    timestamp: i64,
};

pub const ConversationContext = struct {
    history: std.ArrayList(ContextEntry),
    user_facts: std.StringHashMap([]u8),
    allocator: std.mem.Allocator,
    max_history: usize,

    pub fn init(allocator: std.mem.Allocator) ConversationContext {
        return .{
            .history = std.ArrayList(ContextEntry).init(allocator),
            .user_facts = std.StringHashMap([]u8).init(allocator),
            .allocator = allocator,
            .max_history = 10,
        };
    }

    pub fn deinit(self: *ConversationContext) void {
        self.history.deinit();
        var iter = self.user_facts.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.user_facts.deinit();
    }

    pub fn addMessage(self: *ConversationContext, role: []const u8, content: []const u8) !void {
        const content_owned = try self.allocator.dupe(u8, content);
        try self.history.append(.{
            .role = role,
            .content = content_owned,
            .timestamp = std.time.timestamp(),
        });

        // الاحتفاظ بآخر max_history رسائل فقط
        if (self.history.items.len > self.max_history) {
            const old = self.history.orderedRemove(0);
            self.allocator.free(old.content);
        }

        // استخراج معلومات عن المستخدم
        self.extractUserInfo(content) catch {};
    }

    fn extractUserInfo(self: *ConversationContext, text: []const u8) !void {
        // "اسمي أحمد"
        const name_patterns = [_][]const u8{ "اسمي ", "أنا اسمي ", "my name is " };
        for (name_patterns) |pat| {
            if (std.mem.indexOf(u8, text, pat)) |pos| {
                const start = pos + pat.len;
                var end = start;
                while (end < text.len and text[end] != ' ' and text[end] != '.' and text[end] != '\n' and text[end] != '،') {
                    end += 1;
                }
                if (end > start) {
                    const name = try self.allocator.dupe(u8, text[start..end]);
                    const key = try self.allocator.dupe(u8, "user_name");
                    try self.user_facts.put(key, name);
                }
            }
        }

        // "أعيش في القاهرة"
        const location_patterns = [_][]const u8{ "أعيش في ", "أسكن في ", "I live in " };
        for (location_patterns) |pat| {
            if (std.mem.indexOf(u8, text, pat)) |pos| {
                const start = pos + pat.len;
                var end = start;
                while (end < text.len and text[end] != ' ' and text[end] != '.' and text[end] != '\n' and text[end] != '،') {
                    end += 1;
                }
                if (end > start) {
                    const loc = try self.allocator.dupe(u8, text[start..end]);
                    const key = try self.allocator.dupe(u8, "user_location");
                    try self.user_facts.put(key, loc);
                }
            }
        }
    }

    pub fn getUserName(self: *ConversationContext) ?[]const u8 {
        return self.user_facts.get("user_name");
    }

    pub fn getUserLocation(self: *ConversationContext) ?[]const u8 {
        return self.user_facts.get("user_location");
    }

    pub fn getContextString(self: *ConversationContext, allocator: std.mem.Allocator) ![]u8 {
        var buf = std.ArrayList(u8).init(allocator);
        defer buf.deinit();

        // معلومات المستخدم
        if (self.user_facts.get("user_name")) |name| {
            try buf.writer().print("اسم المستخدم: {s}\n", .{name});
        }
        if (self.user_facts.get("user_location")) |loc| {
            try buf.writer().print("موقع المستخدم: {s}\n", .{loc});
        }

        // آخر 3 رسائل
        const start = if (self.history.items.len > 3) self.history.items.len - 3 else 0;
        try buf.appendSlice("آخر المحادثة:\n");
        for (self.history.items[start..]) |entry| {
            try buf.writer().print("{s}: {s}\n", .{ entry.role, entry.content });
        }

        return buf.toOwnedSlice();
    }

    /// كشف ما إذا كان السؤال يشير لرسالة سابقة
    pub fn isFollowUpQuestion(input: []const u8) bool {
        const followup_indicators = [_][]const u8{
            "وماذا عن", "وماذا لو", "كيف ذلك", "explain more", "أكثر",
            "مثال", "give example", "وبعد ذلك", "ثم ماذا",
            "لماذا", "كيف", "what about", "and then",
        };
        for (followup_indicators) |ind| {
            if (std.mem.indexOf(u8, input, ind) != null) return true;
        }
        return false;
    }
};
