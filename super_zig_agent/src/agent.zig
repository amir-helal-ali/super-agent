// src/agent.zig - الوكيل الرئيسي
// يحلل المدخلات، يستخدم الأدوات، يتعلم، ويعطي إجابات
const std = @import("std");
const nn = @import("nn/mod.zig");
const LanguageModel = @import("model.zig").LanguageModel;
const ModelConfig = @import("model.zig").ModelConfig;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Memory = @import("memory.zig").Memory;
const tools = @import("tools/mod.zig");
const web = @import("web/mod.zig");

pub const AgentConfig = struct {
    name: []const u8 = "Super Agent",
    language: []const u8 = "ar",
    max_thinking_steps: usize = 5,
    learning_enabled: bool = true,
    model_dir: []const u8 = "data/model",
    memory_dir: []const u8 = "data/memory",
};

pub const AgentResponse = struct {
    answer: []u8,
    steps_taken: usize,
    tools_used: std.ArrayList([]const u8),
    learned: bool,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *AgentResponse) void {
        self.allocator.free(self.answer);
        self.tools_used.deinit();
    }
};

pub const SuperAgent = struct {
    config: AgentConfig,
    allocator: std.mem.Allocator,
    model: ?LanguageModel,
    tokenizer: ?Tokenizer,
    memory: Memory,
    rng: std.Random.DefaultPrng,

    pub fn init(allocator: std.mem.Allocator, config: AgentConfig) !SuperAgent {
        var agent = SuperAgent{
            .config = config,
            .allocator = allocator,
            .model = null,
            .tokenizer = null,
            .memory = try Memory.init(allocator, config.memory_dir),
            .rng = nn.tensor.createRng(@bitCast(std.time.timestamp())),
        };

        // محاولة تحميل النموذج المُدرّب
        try agent.loadModel();

        return agent;
    }

    pub fn deinit(self: *SuperAgent) void {
        if (self.model) |*m| m.deinit();
        if (self.tokenizer) |*t| t.deinit();
        self.memory.deinit();
    }

    /// تحميل النموذج والـ tokenizer
    fn loadModel(self: *SuperAgent) !void {
        // محاولة تحميل الـ tokenizer
        var tok_path_buf: [256]u8 = undefined;
        const tok_path = try std.fmt.bufPrint(&tok_path_buf, "{s}/tokenizer.txt", .{self.config.model_dir});

        self.tokenizer = Tokenizer.load(self.allocator, tok_path) catch |err| {
            std.debug.print("[agent] no saved tokenizer ({}), creating new one\n", .{err});
            var tok = try Tokenizer.init(self.allocator);
            // تدريب على نصوص أساسية
            try self.trainTokenizerBasics(&tok);
            self.tokenizer = tok;
            return;
        };

        // محاولة تحميل النموذج
        const model_config = ModelConfig{
            .vocab_size = self.tokenizer.?.vocab_size,
            .embed_dim = 128,
            .num_heads = 4,
            .num_layers = 2,
            .max_seq_len = 128,
            .ffn_ratio = 2,
        };

        var random = self.rng.random();
        self.model = LanguageModel.init(self.allocator, model_config, &random) catch |err| {
            std.debug.print("[agent] failed to load model: {}\n", .{err});
            return;
        };
    }

    /// تدريب أساسي للـ tokenizer على نصوص شائعة
    fn trainTokenizerBasics(self: *SuperAgent, tok: *Tokenizer) !void {
        const common_words = [_][]const u8{
            // عربي
            "السلام", "عليكم", "مرحبا", "كيف", "حالك", "اسمي", "أنا", "أنت",
            "نعم", "لا", "شكرا", "من", "إلى", "في", "على", "ماذا", "لماذا",
            "متى", "أين", "هذا", "هذه", "ذلك", "الذي", "التي", "كان", "صباح",
            "مساء", "خير", "سؤال", "جواب", "كتاب", "قراءة", "كتابة", "تعلم",
            "ذكاء", "اصطناعي", "نموذج", "بيانات", "خوارزمية", "برمجة", "كود",
            "حاسوب", "إنترنت", "ويب", "صفحة", "نص", "كلمة", "جملة", "فقرة",
            // إنجليزي
            "hello", "world", "the", "and", "for", "are", "with", "this",
            "that", "have", "from", "they", "will", "would", "there", "their",
            "what", "about", "which", "when", "make", "can", "like", "time",
            "just", "him", "know", "take", "into", "year", "your", "good",
        };
        _ = self;
        for (common_words) |word| {
            _ = try tok.addToken(word);
        }
    }

    /// المحادثة مع الوكيل
    pub fn chat(self: *SuperAgent, user_input: []const u8) !AgentResponse {
        var tools_used = std.ArrayList([]const u8).init(self.allocator);
        var steps_taken: usize = 0;

        // 1. تحليل المدخل - هل يحتوي طلب أداة؟
        const calc_result = self.tryCalculator(user_input) catch null;
        if (calc_result) |r| {
            try tools_used.append("calculator");
            steps_taken += 1;
            return .{
                .answer = r,
                .steps_taken = steps_taken,
                .tools_used = tools_used,
                .learned = false,
                .allocator = self.allocator,
            };
        }

        // 2. هل يسأل عن شيء نعرفه من الذاكرة؟
        if (self.tryMemory(user_input) catch null) |r| {
            try tools_used.append("memory_recall");
            steps_taken += 1;
            return .{
                .answer = r,
                .steps_taken = steps_taken,
                .tools_used = tools_used,
                .learned = false,
                .allocator = self.allocator,
            };
        }

        // 3. هل يحتاج بحثاً على الويب؟
        if (self.needsWebSearch(user_input)) {
            const web_result = try self.searchWeb(user_input);
            try tools_used.append("web_search");
            steps_taken += 1;
            if (web_result) |r| {
                // حفظ في الذاكرة
                if (self.config.learning_enabled) {
                    self.memory.remember(user_input, r) catch {};
                }
                return .{
                    .answer = r,
                    .steps_taken = steps_taken,
                    .tools_used = tools_used,
                    .learned = true,
                    .allocator = self.allocator,
                };
            }
        }

        // 4. توليد رد باستخدام النموذج المحلي
        const response = try self.generateResponse(user_input);
        steps_taken += 1;

        // 5. حفظ في الذاكرة للتعلم
        if (self.config.learning_enabled) {
            const key = try std.fmt.allocPrint(self.allocator, "conv_{d}", .{std.time.timestamp()});
            defer self.allocator.free(key);
            self.memory.remember(key, response) catch {};
        }

        return .{
            .answer = response,
            .steps_taken = steps_taken,
            .tools_used = tools_used,
            .learned = self.config.learning_enabled,
            .allocator = self.allocator,
        };
    }

    /// محاولة معالجة كحاسبة
    fn tryCalculator(self: *SuperAgent, input: []const u8) !?[]u8 {
        // كشف هل المدخل تعبير رياضي
        var has_digit = false;
        var has_op = false;
        for (input) |c| {
            if (std.ascii.isDigit(c) or c == '.') has_digit = true;
            if (c == '+' or c == '-' or c == '*' or c == '/' or c == '^') has_op = true;
        }
        if (!has_digit or !has_op) return null;

        // محاولة التقييم
        const result = tools.calculator.evaluate(self.allocator, input) catch return null;
        return result;
    }

    /// محاولة استرجاع من الذاكرة
    fn tryMemory(self: *SuperAgent, input: []const u8) !?[]u8 {
        // أنماط بسيطة للبحث في الذاكرة
        if (std.mem.indexOf(u8, input, "تذكر") != null or
            std.mem.indexOf(u8, input, "ماذا تعرف") != null or
            std.mem.indexOf(u8, input, "remember") != null)
        {
            var results = self.memory.search(input);
            defer results.deinit();

            if (results.items.len > 0) {
                var response = std.ArrayList(u8).init(self.allocator);
                try response.appendSlice("أعرف ما يلي:\n");
                for (results.items, 0..) |r, i| {
                    if (i >= 5) break;
                    try response.writer().print("- {s}: {s}\n", .{ r.key, r.content });
                }
                const slice = try response.toOwnedSlice();
                return slice;
            }
        }
        return null;
    }

    /// هل يحتاج بحثاً على الويب؟
    fn needsWebSearch(self: *SuperAgent, input: []const u8) bool {
        const web_indicators = [_][]const u8{
            "ابحث", "بحث", "اخر", "أخبار", "الآن", "اليوم", "حالياً", "ما هو",
            "search", "latest", "news", "current", "today", "now",
        };
        _ = self;
        for (web_indicators) |ind| {
            if (std.mem.indexOf(u8, input, ind) != null) return true;
        }
        return false;
    }

    /// بحث على الويب (DuckDuckGo HTML)
    fn searchWeb(self: *SuperAgent, query: []const u8) !?[]u8 {
        const search_url = try std.fmt.allocPrint(
            self.allocator,
            "https://html.duckduckgo.com/html/?q={s}",
            .{query},
        );
        defer self.allocator.free(search_url);

        var response = web.fetch(self.allocator, search_url, 1024 * 1024) catch return null;
        defer response.deinit();

        // استخراج النص
        const text = web.extractText(self.allocator, response.body) catch return null;
        defer self.allocator.free(text);

        // اقتطاع لأول 2000 حرف
        const max_len = @min(text.len, 2000);
        const result = try self.allocator.dupe(u8, text[0..max_len]);
        return result;
    }

    /// توليد رد باستخدام النموذج المحلي
    fn generateResponse(self: *SuperAgent, input: []const u8) ![]u8 {
        if (self.tokenizer == null or self.model == null) {
            // نمط بدون نموذج - ردود محددة
            return self.fallbackResponse(input);
        }

        // ترميز المدخل
        var tokens = try self.tokenizer.?.encode(input);
        defer tokens.deinit();

        // إضافة BOS في البداية
        var prompt = std.ArrayList(u32).init(self.allocator);
        defer prompt.deinit();
        try prompt.append(Tokenizer.BOS);
        try prompt.appendSlice(tokens.items);

        // توليد
        var random = self.rng.random();
        var output = self.model.?.generate(prompt.items, 100, 0.7, &random) catch {
            return self.fallbackResponse(input);
        };
        defer output.deinit();

        // فك الترميز
        var decoded = try self.tokenizer.?.decode(output.items);
        defer decoded.deinit();

        if (decoded.items.len == 0) {
            return self.fallbackResponse(input);
        }

        return self.allocator.dupe(u8, decoded.items);
    }

    /// رد احتياطي عندما لا يوجد نموذج مُدرّب
    fn fallbackResponse(self: *SuperAgent, input: []const u8) ![]u8 {
        // ردود بسيطة للأسئلة الشائعة
        if (std.mem.indexOf(u8, input, "مرحبا") != null or
            std.mem.indexOf(u8, input, "السلام") != null or
            std.mem.indexOf(u8, input, "اهلا") != null)
        {
            return self.allocator.dupe(u8, "مرحبا بك! أنا Super Agent - وكيل ذكاء اصطناعي خارق خفيف الوزن. كيف يمكنني مساعدتك؟");
        }

        if (std.mem.indexOf(u8, input, "من انت") != null or
            std.mem.indexOf(u8, input, "من أنت") != null or
            std.mem.indexOf(u8, input, "اسمك") != null)
        {
            return self.allocator.dupe(u8, "أنا Super Agent - وكيل ذكاء اصطناعي مبني بلغة Zig، أعمل على 2GB RAM ومعالج 4 cores بدون GPU. أتعلم من الإنترنت تلقائياً.");
        }

        if (std.mem.indexOf(u8, input, "شكرا") != null) {
            return self.allocator.dupe(u8, "العفو! سعيد بمساعدتك.");
        }

        // رد عام
        return std.fmt.allocPrint(
            self.allocator,
            "استلمت رسالتك: '{s}'. النموذج بحاجة لتدريب أكثر للإجابة بدقة. شغّل: train-agent لبدء التعلم من الإنترنت.",
            .{input},
        );
    }

    /// تدريب على نص جديد
    pub fn learn(self: *SuperAgent, text: []const u8) !void {
        if (self.tokenizer == null) return;

        // إضافة كلمات جديدة للـ tokenizer
        var it = std.mem.tokenizeAny(u8, text, " \t\n\r.,;:!?'\"()[]{}");
        while (it.next()) |word| {
            if (word.len >= 2 and word.len <= 20) {
                _ = try self.tokenizer.?.addToken(word);
            }
        }

        // حفظ الـ tokenizer
        var path_buf: [256]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buf, "{s}/tokenizer.txt", .{self.config.model_dir});
        try self.tokenizer.?.save(path);

        std.debug.print("[agent] learned {d} chars of new text\n", .{text.len});
    }

    /// إحصائيات الوكيل
    pub fn stats(self: *SuperAgent) AgentStats {
        return .{
            .vocab_size = if (self.tokenizer) |t| t.vocab_size else 0,
            .memory_entries = self.memory.entries.count(),
            .has_model = self.model != null,
        };
    }
};

pub const AgentStats = struct {
    vocab_size: usize,
    memory_entries: usize,
    has_model: bool,
};
