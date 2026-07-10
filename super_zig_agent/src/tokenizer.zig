// src/tokenizer.zig - مُجزّئ BPE مبسط للعربية والإنجليزية
// لا يحتاج مكتبات خارجية - كل شيء في Zig
const std = @import("std");

pub const TokenizerError = error{
    InvalidToken,
    OutOfVocab,
    InvalidFormat,
};

/// مُجزّئ يعمل بمستويين: حرفي + كلمات شائعة
pub const Tokenizer = struct {
    // vocab: token_string -> token_id
    vocab: std.StringHashMap(u32),
    // id_to_token: token_id -> token_string
    id_to_token: std.AutoHashMap(u32, []const u8),
    // تخزين دائم للنصوص
    string_arena: std.heap.ArenaAllocator,
    vocab_size: usize,
    special_tokens: std.StringHashMap(u32),

    // رموز خاصة
    pub const PAD: u32 = 0;
    pub const BOS: u32 = 1;
    pub const EOS: u32 = 2;
    pub const UNK: u32 = 3;
    pub const SEP: u32 = 4;

    pub fn init(allocator: std.mem.Allocator) !Tokenizer {
        var tok = Tokenizer{
            .vocab = std.StringHashMap(u32).init(allocator),
            .id_to_token = std.AutoHashMap(u32, []const u8).init(allocator),
            .string_arena = std.heap.ArenaAllocator.init(allocator),
            .vocab_size = 0,
            .special_tokens = std.StringHashMap(u32).init(allocator),
        };

        // رموز خاصة
        try tok.addSpecial("<pad>", PAD);
        try tok.addSpecial("<bos>", BOS);
        try tok.addSpecial("<eos>", EOS);
        try tok.addSpecial("<unk>", UNK);
        try tok.addSpecial("<sep>", SEP);

        // إضافة أحرف أساسية
        try tok.addBasicChars();

        return tok;
    }

    pub fn deinit(self: *Tokenizer) void {
        self.vocab.deinit();
        self.id_to_token.deinit();
        self.string_arena.deinit();
        self.special_tokens.deinit();
    }

    fn addSpecial(self: *Tokenizer, token: []const u8, id: u32) !void {
        const owned = try self.string_arena.allocator().dupe(u8, token);
        try self.vocab.put(owned, id);
        try self.id_to_token.put(id, owned);
        try self.special_tokens.put(owned, id);
        if (id + 1 > self.vocab_size) self.vocab_size = id + 1;
    }

    fn addBasicChars(self: *Tokenizer) !void {
        // أضف الأحرف اللاتينية
        var c: u8 = 'a';
        while (c <= 'z') : (c += 1) {
            var buf: [1]u8 = .{c};
            _ = try self.addToken(&buf);
        }
        c = 'A';
        while (c <= 'Z') : (c += 1) {
            var buf: [1]u8 = .{c};
            _ = try self.addToken(&buf);
        }
        c = '0';
        while (c <= '9') : (c += 1) {
            var buf: [1]u8 = .{c};
            _ = try self.addToken(&buf);
        }
        // علامات ترقيم شائعة
        const punct = " .,;:!?'\"()[]{}<>/\\@#$%^&*-_+=~`|";
        for (punct) |p| {
            var buf: [1]u8 = .{p};
            _ = try self.addToken(&buf);
        }
        // مسافة
        _ = try self.addToken(" ");

        // أحرف عربية أساسية
        const arabic = "ابتثجحخدذرزسشصضطظعغفقكلمنهويءآأؤإئ";
        var iter = (try std.unicode.Utf8View.init(arabic)).iterator();
        while (iter.nextCodepoint()) |cp| {
            var buf: [4]u8 = undefined;
            const len = try std.unicode.utf8Encode(cp, &buf);
            _ = try self.addToken(buf[0..len]);
        }
        // أحرف عربية متقدمة
        const arabic2 = "ةىئءؤ";
        iter = (try std.unicode.Utf8View.init(arabic2)).iterator();
        while (iter.nextCodepoint()) |cp| {
            var buf: [4]u8 = undefined;
            const len = try std.unicode.utf8Encode(cp, &buf);
            _ = try self.addToken(buf[0..len]);
        }
    }

    /// إضافة token جديد
    pub fn addToken(self: *Tokenizer, token: []const u8) !u32 {
        if (self.vocab.get(token)) |id| return id;
        const id: u32 = @intCast(self.vocab_size);
        const owned = try self.string_arena.allocator().dupe(u8, token);
        try self.vocab.put(owned, id);
        try self.id_to_token.put(id, owned);
        self.vocab_size += 1;
        return id;
    }

    /// ترميز نص إلى سلسلة من الـ token IDs
    /// استراتيجية: حرف بحرف + الكلمات الشائعة المعروفة
    pub fn encode(self: *Tokenizer, text: []const u8) !std.ArrayList(u32) {
        var result = std.ArrayList(u32).init(self.string_arena.child_allocator);

        // محاولة مطابقة أطول كلمة معروفة أولاً
        var i: usize = 0;
        while (i < text.len) {
            // محاولة العثور على أطول كلمة معروفة تبدأ من i
            var found = false;
            const max_word_len = @min(text.len - i, @as(usize, 20));
            var len: usize = max_word_len;
            while (len >= 1) : (len -= 1) {
                const substr = text[i .. i + len];
                if (self.vocab.get(substr)) |id| {
                    try result.append(id);
                    i += len;
                    found = true;
                    break;
                }
            }

            if (!found) {
                // محاولة ترميز الحرف/البايت الحالي
                // تحديد طول UTF-8 من البايت الأول
                const first_byte = text[i];
                const seq_len: usize = if (first_byte < 0x80)
                    1
                else if (first_byte < 0xC0)
                    1 // بايت تابع غير صالح في البداية - تعامل كـ single byte
                else if (first_byte < 0xE0)
                    2
                else if (first_byte < 0xF0)
                    3
                else
                    4;

                if (i + seq_len <= text.len) {
                    const token_str = text[i .. i + seq_len];
                    if (self.vocab.get(token_str)) |id| {
                        try result.append(id);
                    } else {
                        // إضافة الحرف الجديد للـ vocab (تعلّم)
                        const new_id = try self.addToken(token_str);
                        try result.append(new_id);
                    }
                    i += seq_len;
                } else {
                    // بايت غير مكتمل - أضف UNK وتجاوز
                    try result.append(UNK);
                    i += 1;
                }
            }
        }
        return result;
    }

    /// فك ترميز - من IDs إلى نص
    pub fn decode(self: *Tokenizer, ids: []const u32) !std.ArrayList(u8) {
        var result = std.ArrayList(u8).init(self.string_arena.child_allocator);
        for (ids) |id| {
            if (self.id_to_token.get(id)) |token| {
                if (id == PAD or id == BOS or id == EOS or id == SEP) continue;
                try result.appendSlice(token);
            }
        }
        return result;
    }

    /// حفظ الـ vocab إلى ملف نصي
    pub fn save(self: *Tokenizer, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        var writer = file.writer();

        // كتابة عدد التوكنز
        try writer.print("{d}\n", .{self.vocab_size});

        // كتابة كل توكن على سطر (id<TAB>token)
        var iter = self.id_to_token.iterator();
        while (iter.next()) |entry| {
            try writer.print("{d}\t", .{entry.key_ptr.*});
            // كتابة التوكن (مع escape للأسطر الجديدة)
            for (entry.value_ptr.*) |c| {
                if (c == '\n') {
                    try writer.writeAll("\\n");
                } else if (c == '\r') {
                    try writer.writeAll("\\r");
                } else if (c == '\t') {
                    try writer.writeAll("\\t");
                } else if (c == '\\') {
                    try writer.writeAll("\\\\");
                } else {
                    try writer.writeByte(c);
                }
            }
            try writer.writeByte('\n');
        }
    }

    /// تحميل الـ vocab من ملف
    pub fn load(allocator: std.mem.Allocator, path: []const u8) !Tokenizer {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        const content = try file.readToEndAlloc(allocator, 50 * 1024 * 1024); // 50MB max
        defer allocator.free(content);

        var tok = try Tokenizer.init(allocator);

        var lines = std.mem.splitScalar(u8, content, '\n');
        // السطر الأول: عدد التوكنز
        const size_line = lines.next() orelse return TokenizerError.InvalidFormat;
        const size = try std.fmt.parseInt(usize, size_line, 10);

        var count: usize = 0;
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            // إيجاد التبويب
            const tab_pos = std.mem.indexOfScalar(u8, line, '\t') orelse continue;
            const id_str = line[0..tab_pos];
            const token_raw = line[tab_pos + 1 ..];

            const id = try std.fmt.parseInt(u32, id_str, 10);

            // unescape
            var token = std.ArrayList(u8).init(allocator);
            defer token.deinit();
            var i: usize = 0;
            while (i < token_raw.len) {
                if (token_raw[i] == '\\') {
                    if (i + 1 < token_raw.len) {
                        switch (token_raw[i + 1]) {
                            'n' => try token.append('\n'),
                            'r' => try token.append('\r'),
                            't' => try token.append('\t'),
                            '\\' => try token.append('\\'),
                            else => try token.append(token_raw[i + 1]),
                        }
                        i += 2;
                    } else {
                        try token.append('\\');
                        i += 1;
                    }
                } else {
                    try token.append(token_raw[i]);
                    i += 1;
                }
            }

            // إضافة للـ vocab
            const owned = try tok.string_arena.allocator().dupe(u8, token.items);
            try tok.vocab.put(owned, id);
            try tok.id_to_token.put(id, owned);
            count += 1;
        }

        tok.vocab_size = size;
        return tok;
    }
};

test "tokenizer basic" {
    var tok = try Tokenizer.init(std.testing.allocator);
    defer tok.deinit();

    var ids = try tok.encode("hello");
    defer ids.deinit();
    try std.testing.expect(ids.items.len > 0);

    var decoded = try tok.decode(ids.items);
    defer decoded.deinit();
    try std.testing.expectEqualStrings("hello", decoded.items);
}

test "tokenizer arabic" {
    var tok = try Tokenizer.init(std.testing.allocator);
    defer tok.deinit();

    var ids = try tok.encode("مرحبا");
    defer ids.deinit();
    try std.testing.expect(ids.items.len > 0);

    var decoded = try tok.decode(ids.items);
    defer decoded.deinit();
    try std.testing.expectEqualStrings("مرحبا", decoded.items);
}
