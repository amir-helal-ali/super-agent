// src/long_term_memory.zig - ذاكرة طويلة المدى
// يتذكر معلومات عن المستخدم بشكل دائم
const std = @import("std");

pub const Fact = struct {
    key: []u8,
    value: []u8,
    category: FactCategory,
    timestamp: i64,
    confidence: f32,
};

pub const FactCategory = enum {
    personal,      // اسم، عمر، جنس
    location,      // مدينة، دولة
    interest,      // اهتمامات، هوايات
    profession,    // مهنة، دراسة
    preference,    // تفضيلات
    knowledge,     // معلومات تعلمها
    conversation,  // محادثات سابقة
};

pub const LongTermMemory = struct {
    allocator: std.mem.Allocator,
    facts: std.ArrayList(Fact),
    file_path: []const u8,

    pub fn init(allocator: std.mem.Allocator, file_path: []const u8) !LongTermMemory {
        var ltm = LongTermMemory{
            .allocator = allocator,
            .facts = std.ArrayList(Fact).init(allocator),
            .file_path = try allocator.dupe(u8, file_path),
        };
        ltm.load() catch {};
        return ltm;
    }

    pub fn deinit(self: *LongTermMemory) void {
        for (self.facts.items) |f| {
            self.allocator.free(f.key);
            self.allocator.free(f.value);
        }
        self.facts.deinit();
        self.allocator.free(self.file_path);
    }

    /// حفظ معلومة جديدة
    pub fn remember(self: *LongTermMemory, key: []const u8, value: []const u8, category: FactCategory) !void {
        // تحديث إذا موجودة
        for (self.facts.items) |*f| {
            if (std.mem.eql(u8, f.key, key)) {
                self.allocator.free(f.value);
                f.value = try self.allocator.dupe(u8, value);
                f.category = category;
                f.timestamp = std.time.timestamp();
                f.confidence = 1.0;
                try self.save();
                return;
            }
        }

        // إضافة جديدة
        try self.facts.append(.{
            .key = try self.allocator.dupe(u8, key),
            .value = try self.allocator.dupe(u8, value),
            .category = category,
            .timestamp = std.time.timestamp(),
            .confidence = 1.0,
        });
        try self.save();
    }

    /// استرجاع معلومة
    pub fn recall(self: *LongTermMemory, key: []const u8) ?[]const u8 {
        for (self.facts.items) |f| {
            if (std.mem.eql(u8, f.key, key)) return f.value;
        }
        return null;
    }

    /// استرجاع كل المعلومات في فئة
    pub fn recallByCategory(self: *LongTermMemory, cat: FactCategory) std.ArrayList(Fact) {
        var results = std.ArrayList(Fact).init(self.allocator);
        for (self.facts.items) |f| {
            if (f.category == cat) {
                results.append(f) catch {};
            }
        }
        return results;
    }

    /// استخراج معلومات تلقائياً من رسالة المستخدم
    pub fn extractAndStore(self: *LongTermMemory, text: []const u8) void {
        // "اسمي امير"
        if (std.mem.indexOf(u8, text, "اسمي ") != null) {
            const pos = std.mem.indexOf(u8, text, "اسمي ").?;
            const start = pos + 5;
            var end = start;
            while (end < text.len and text[end] != ' ' and text[end] != '.' and text[end] != '\n' and text[end] != '،') {
                end += 1;
            }
            if (end > start) {
                self.remember("user_name", text[start..end], .personal) catch {};
            }
        }

        // "أعيش في القاهرة"
        if (std.mem.indexOf(u8, text, "أعيش في ") != null) {
            const pos = std.mem.indexOf(u8, text, "أعيش في ").?;
            const start = pos + 8;
            var end = start;
            while (end < text.len and text[end] != ' ' and text[end] != '.' and text[end] != '\n' and text[end] != '،') {
                end += 1;
            }
            if (end > start) {
                self.remember("user_location", text[start..end], .location) catch {};
            }
        }

        // "أحب البرمجة"
        if (std.mem.indexOf(u8, text, "أحب ") != null) {
            const pos = std.mem.indexOf(u8, text, "أحب ").?;
            const start = pos + 4;
            var end = start;
            while (end < text.len and text[end] != '.' and text[end] != '\n' and text[end] != '،') {
                end += 1;
            }
            if (end > start) {
                self.remember("user_interest", text[start..end], .interest) catch {};
            }
        }

        // "أعمل مبرمج"
        if (std.mem.indexOf(u8, text, "أعمل ") != null) {
            const pos = std.mem.indexOf(u8, text, "أعمل ").?;
            const start = pos + 5;
            var end = start;
            while (end < text.len and text[end] != '.' and text[end] != '\n' and text[end] != '،') {
                end += 1;
            }
            if (end > start) {
                self.remember("user_profession", text[start..end], .profession) catch {};
            }
        }

        // "أدرس علوم حاسب"
        if (std.mem.indexOf(u8, text, "أدرس ") != null) {
            const pos = std.mem.indexOf(u8, text, "أدرس ").?;
            const start = pos + 5;
            var end = start;
            while (end < text.len and text[end] != '.' and text[end] != '\n' and text[end] != '،') {
                end += 1;
            }
            if (end > start) {
                self.remember("user_study", text[start..end], .profession) catch {};
            }
        }

        // "عمري 25"
        if (std.mem.indexOf(u8, text, "عمري ") != null) {
            const pos = std.mem.indexOf(u8, text, "عمري ").?;
            const start = pos + 5;
            var end = start;
            while (end < text.len and text[end] != ' ' and text[end] != '.' and text[end] != '\n') {
                end += 1;
            }
            if (end > start) {
                self.remember("user_age", text[start..end], .personal) catch {};
            }
        }
    }

    /// توليد رد مخصص بناءً على المعلومات المحفوظة
    pub fn personalizeGreeting(self: *LongTermMemory, allocator: std.mem.Allocator) ![]u8 {
        const name = self.recall("user_name");
        const location = self.recall("user_location");
        const interest = self.recall("user_interest");

        var buf = std.ArrayList(u8).init(allocator);
        defer buf.deinit();

        if (name) |n| {
            try buf.writer().print("أهلاً {s}!", .{n});
        } else {
            try buf.appendSlice("مرحباً!");
        }

        if (location) |loc| {
            try buf.writer().print(" 🌍 من {s}", .{loc});
        }

        if (interest) |intr| {
            try buf.writer().print(" ❤️ أعرف أنك تحب {s}", .{intr});
        }

        if (buf.items.len == 0) {
            try buf.appendSlice("مرحباً بك!");
        }

        return buf.toOwnedSlice();
    }

    /// حفظ في ملف
    fn save(self: *LongTermMemory) !void {
        const file = std.fs.cwd().createFile(self.file_path, .{}) catch return;
        defer file.close();
        var writer = file.writer();

        for (self.facts.items) |f| {
            try writer.print("{d}\t{s}\t{s}\t{d}\t{d:.2}\n", .{
                @intFromEnum(f.category),
                f.key,
                f.value,
                f.timestamp,
                f.confidence,
            });
        }
    }

    /// تحميل من ملف
    fn load(self: *LongTermMemory) !void {
        const file = std.fs.cwd().openFile(self.file_path, .{}) catch return;
        defer file.close();
        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;

            var parts = std.mem.splitScalar(u8, line, '\t');
            const cat_str = parts.next() orelse continue;
            const key = parts.next() orelse continue;
            const value = parts.next() orelse continue;
            const ts_str = parts.next() orelse continue;
            const conf_str = parts.next() orelse continue;

            const cat: FactCategory = @enumFromInt(std.fmt.parseInt(u8, cat_str, 10) catch 0);
            const ts = std.fmt.parseInt(i64, ts_str, 10) catch 0;
            const conf = std.fmt.parseFloat(f32, conf_str) catch 1.0;

            try self.facts.append(.{
                .key = try self.allocator.dupe(u8, key),
                .value = try self.allocator.dupe(u8, value),
                .category = cat,
                .timestamp = ts,
                .confidence = conf,
            });
        }
    }

    /// عدد المعلومات المحفوظة
    pub fn count(self: *LongTermMemory) usize {
        return self.facts.items.len;
    }
};
