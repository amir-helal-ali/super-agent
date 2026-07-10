// src/memory.zig - نظام الذاكرة الدائم
// تخزين بسيط في ملفات - لا يحتاج SQLite
const std = @import("std");

pub const MemoryEntry = struct {
    key: []u8,
    content: []u8,
    timestamp: i64,
    access_count: u32,
};

pub const SearchResult = struct {
    key: []const u8,
    content: []const u8,
    score: f32,
};

pub const Memory = struct {
    allocator: std.mem.Allocator,
    data_dir: []u8,
    entries: std.StringHashMap(MemoryEntry),
    lock: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator, data_dir: []const u8) !Memory {
        try std.fs.cwd().makePath(data_dir);
        var mem = Memory{
            .allocator = allocator,
            .data_dir = try allocator.dupe(u8, data_dir),
            .entries = std.StringHashMap(MemoryEntry).init(allocator),
            .lock = .{},
        };
        try mem.load();
        return mem;
    }

    pub fn deinit(self: *Memory) void {
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.key);
            self.allocator.free(entry.value_ptr.content);
        }
        self.entries.deinit();
        self.allocator.free(self.data_dir);
    }

    /// حفظ معلومة
    pub fn remember(self: *Memory, key: []const u8, content: []const u8) !void {
        self.lock.lock();
        defer self.lock.unlock();

        // إذا كان موجوداً، نحدثه
        if (self.entries.fetchRemove(key)) |existing| {
            self.allocator.free(existing.value.key);
            self.allocator.free(existing.value.content);
        }

        const key_owned = try self.allocator.dupe(u8, key);
        const content_owned = try self.allocator.dupe(u8, content);
        try self.entries.put(key_owned, .{
            .key = key_owned,
            .content = content_owned,
            .timestamp = std.time.timestamp(),
            .access_count = 0,
        });

        try self.save();
    }

    /// استرجاع معلومة
    pub fn recall(self: *Memory, key: []const u8) ?[]const u8 {
        self.lock.lock();
        defer self.lock.unlock();

        if (self.entries.getPtr(key)) |entry| {
            entry.access_count += 1;
            return entry.content;
        }
        return null;
    }

    /// بحث بسيط في الذاكرة (يطابق الكلمات المفتاحية)
    pub fn search(self: *Memory, query: []const u8) std.ArrayList(SearchResult) {
        self.lock.lock();
        defer self.lock.unlock();

        var results = std.ArrayList(SearchResult).init(self.allocator);

        // تجزئة الاستعلام إلى كلمات
        var query_words = std.ArrayList([]const u8).init(self.allocator);
        defer query_words.deinit();

        var it = std.mem.tokenizeAny(u8, query, " \t\n\r.,;:!?'\"()[]{}");
        while (it.next()) |word| {
            if (word.len > 2) query_words.append(word) catch {};
        }

        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            var score: f32 = 0;
            for (query_words.items) |qw| {
                // حساب عدد مرات الظهور في الـ content
                var pos: usize = 0;
                var count: usize = 0;
                while (pos < entry.value_ptr.content.len) {
                    if (std.mem.indexOfPos(u8, entry.value_ptr.content, pos, qw)) |idx| {
                        count += 1;
                        pos = idx + qw.len;
                    } else {
                        break;
                    }
                }
                score += @as(f32, @floatFromInt(count)) / @as(f32, @floatFromInt(entry.value_ptr.content.len + 1));
                // أيضًا في المفتاح
                if (std.mem.indexOf(u8, entry.value_ptr.key, qw) != null) {
                    score += 0.5;
                }
            }
            if (score > 0) {
                results.append(.{
                    .key = entry.value_ptr.key,
                    .content = entry.value_ptr.content,
                    .score = score,
                }) catch {};
            }
        }

        // ترتيب تنازلياً بالـ score (bubble sort - بسيط)
        for (results.items, 0..) |_, i| {
            for (results.items[i + 1 ..], i + 1..) |_, j| {
                if (results.items[i].score < results.items[j].score) {
                    const tmp = results.items[i];
                    results.items[i] = results.items[j];
                    results.items[j] = tmp;
                }
            }
        }

        return results;
    }

    /// نسيان معلومة
    pub fn forget(self: *Memory, key: []const u8) !void {
        self.lock.lock();
        defer self.lock.unlock();

        if (self.entries.fetchRemove(key)) |existing| {
            self.allocator.free(existing.value.key);
            self.allocator.free(existing.value.content);
            try self.save();
        }
    }

    /// قائمة كل المفاتيح
    pub fn listKeys(self: *Memory) !std.ArrayList([]const u8) {
        self.lock.lock();
        defer self.lock.unlock();

        var result = std.ArrayList([]const u8).init(self.allocator);
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            try result.append(entry.key_ptr.*);
        }
        return result;
    }

    /// حفظ في ملف
    fn save(self: *Memory) !void {
        var path_buf: [512]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buf, "{s}/memory.json", .{self.data_dir});

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        var writer = file.writer();

        try writer.writeAll("[\n");
        var first = true;
        var iter = self.entries.iterator();
        while (iter.next()) |entry| {
            if (!first) try writer.writeAll(",\n");
            first = false;
            try writer.writeAll("  {\"key\":\"");
            try writeJsonString(writer, entry.value_ptr.key);
            try writer.writeAll("\",\"content\":\"");
            try writeJsonString(writer, entry.value_ptr.content);
            try writer.print("\",\"timestamp\":{d},\"access_count\":{d}}}", .{
                entry.value_ptr.timestamp,
                entry.value_ptr.access_count,
            });
        }
        try writer.writeAll("\n]\n");
    }

    /// تحميل من ملف
    fn load(self: *Memory) !void {
        var path_buf: [512]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buf, "{s}/memory.json", .{self.data_dir});

        const file = std.fs.cwd().openFile(path, .{}) catch return;
        defer file.close();
        const content = try file.readToEndAlloc(self.allocator, 50 * 1024 * 1024);
        defer self.allocator.free(content);

        // تحليل JSON باستخدام std.json.parseFromSlice (Zig 0.14 API)
        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, content, .{}) catch return;
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .array) return;

        for (root.array.items) |item| {
            if (item != .object) continue;
            const key_val = item.object.get("key") orelse continue;
            const content_val = item.object.get("content") orelse continue;
            if (key_val != .string or content_val != .string) continue;

            const ts: i64 = if (item.object.get("timestamp")) |t|
                if (t == .integer) t.integer else 0
            else
                0;
            const access: u32 = if (item.object.get("access_count")) |a|
                if (a == .integer) @intCast(a.integer) else 0
            else
                0;

            const key_owned = try self.allocator.dupe(u8, key_val.string);
            const content_owned = try self.allocator.dupe(u8, content_val.string);
            try self.entries.put(key_owned, .{
                .key = key_owned,
                .content = content_owned,
                .timestamp = ts,
                .access_count = access,
            });
        }
    }
};

fn writeJsonString(writer: anytype, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => try writer.writeByte(c),
        }
    }
}

test "memory basic" {
    var tmp_dir = std.testing.tmpDir(.{});
    const path = try tmp_dir.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(path);

    var mem = try Memory.init(std.testing.allocator, path);
    defer mem.deinit();

    try mem.remember("name", "Super Agent");
    try std.testing.expectEqualStrings("Super Agent", mem.recall("name").?);
}
