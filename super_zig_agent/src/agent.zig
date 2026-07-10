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
const knowledge = @import("knowledge.zig");
const context_mod = @import("context.zig");
const ngram = @import("ngram.zig");

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
    context: context_mod.ConversationContext,
    ngram_model: ngram.NGramModel,

    pub fn init(allocator: std.mem.Allocator, config: AgentConfig) !SuperAgent {
        var agent = SuperAgent{
            .config = config,
            .allocator = allocator,
            .model = null,
            .tokenizer = null,
            .memory = try Memory.init(allocator, config.memory_dir),
            .rng = nn.tensor.createRng(@bitCast(std.time.timestamp())),
            .context = context_mod.ConversationContext.init(allocator),
            .ngram_model = ngram.NGramModel.init(allocator),
        };

        // تدريب n-gram على corpus مدمج
        agent.ngram_model.trainOnBuiltinCorpus() catch {};

        // محاولة تحميل النموذج المُدرّب
        try agent.loadModel();

        return agent;
    }

    pub fn deinit(self: *SuperAgent) void {
        if (self.model) |*m| m.deinit();
        if (self.tokenizer) |*t| t.deinit();
        self.memory.deinit();
        self.context.deinit();
        self.ngram_model.deinit();
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

        // حفظ في السياق
        self.context.addMessage("user", user_input) catch {};

        // 0.5. هل يسأل عن الطقس؟
        if (tools.info_tool.isWeatherQuery(user_input)) |city| {
            const weather = tools.info_tool.getWeather(self.allocator, city) catch null;
            if (weather) |r| {
                try tools_used.append("weather");
                steps_taken += 1;
                self.context.addMessage("assistant", r) catch {};
                return .{ .answer = r, .steps_taken = steps_taken, .tools_used = tools_used, .learned = false, .allocator = self.allocator };
            }
        }

        // 0.6. هل يسأل عن العملات؟
        if (tools.info_tool.isCurrencyQuery(user_input)) |cur| {
            const rate = tools.info_tool.getExchangeRate(self.allocator, cur.from, cur.to) catch null;
            if (rate) |r| {
                try tools_used.append("currency");
                steps_taken += 1;
                self.context.addMessage("assistant", r) catch {};
                return .{ .answer = r, .steps_taken = steps_taken, .tools_used = tools_used, .learned = false, .allocator = self.allocator };
            }
        }

        // 1. تحليل المدخل - هل يحتوي طلب أداة؟
        const calc_result = self.tryCalculator(user_input) catch null;
        if (calc_result) |r| {
            try tools_used.append("calculator");
            steps_taken += 1;
            self.context.addMessage("assistant", r) catch {};
            return .{ .answer = r, .steps_taken = steps_taken, .tools_used = tools_used, .learned = false, .allocator = self.allocator };
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
        _ = self;
        return tools.web_search.needsWebSearch(input);
    }

    fn searchWeb(self: *SuperAgent, query: []const u8) !?[]u8 {
        const search_query = tools.web_search.extractQuery(query);
        return tools.web_search.search(self.allocator, search_query) catch null;
    }

    /// توليد رد باستخدام النموذج المحلي
    fn generateResponse(self: *SuperAgent, input: []const u8) ![]u8 {
        // 1. محاولة استخدام n-gram model
        if (self.ngram_model.trained) {
            const ngram_result = self.ngram_model.generate(self.allocator, input, 15) catch null;
            if (ngram_result) |r| {
                // فحص جودة الرد
                if (self.isResponseCoherent(r, input)) {
                    return r;
                }
                self.allocator.free(r);
            }
        }

        // 2. محاولة استخدام transformer model (معطل مؤقتاً - ينتج نصاً غير مفهوم)
        // TODO: إعادة تفعيل بعد تدريب كافٍ

        // 3. fallback
        return self.fallbackResponse(input);
    }

    /// فحص جودة الرد - هل هو متماسك؟
    fn isResponseCoherent(self: *SuperAgent, response: []const u8, input: []const u8) bool {
        _ = self;
        _ = input;

        // يجب أن يكون طوله معقولاً
        if (response.len < 10) return false;
        if (response.len > 500) return false;

        // يجب أن لا يحتوي على رموز غريبة كثيرة
        var weird_count: usize = 0;
        for (response) |c| {
            if (c < 32 and c != ' ' and c != '\n' and c != '\t') weird_count += 1;
        }
        if (weird_count > 3) return false;

        // عد الكلمات
        var word_count: usize = 0;
        var it = std.mem.tokenizeAny(u8, response, " \t\n\r");
        while (it.next()) |_| word_count += 1;

        // يجب أن يكون 3 كلمات على الأقل
        if (word_count < 3) return false;

        // فحص الخلط اللغوي - لا يجب أن يخلط عربي وإنجليزي بكثرة
        var ar_chars: usize = 0;
        var en_chars: usize = 0;
        for (response) |b| {
            if (b >= 0xD8 and b <= 0xD9) ar_chars += 1;
            if (b >= 'a' and b <= 'z') en_chars += 1;
            if (b >= 'A' and b <= 'Z') en_chars += 1;
        }

        // إذا كان فيه خلط كبير (أكثر من 30% لغة أخرى) ارفضه
        if (ar_chars > 0 and en_chars > 0) {
            const total = ar_chars + en_chars;
            const minority = @min(ar_chars, en_chars);
            if (minority * 100 / total > 30) return false;
        }

        return true;
    }

    /// رد احتياطي عندما لا يوجد نموذج مُدرّب
    fn fallbackResponse(self: *SuperAgent, input: []const u8) ![]u8 {
        // 1. البحث في قاعدة المعرفة أولاً
        if (knowledge.search(input)) |response| {
            return self.allocator.dupe(u8, response);
        }

        // 2. ردود للأسئلة الشائعة
        if (std.mem.indexOf(u8, input, "مرحبا") != null or
            std.mem.indexOf(u8, input, "السلام") != null or
            std.mem.indexOf(u8, input, "اهلا") != null or
            std.mem.indexOf(u8, input, "hello") != null)
        {
            return self.allocator.dupe(u8, "مرحبا بك! أنا Super Agent - وكيل ذكاء اصطناعي خارق خفيف الوزن. كيف يمكنني مساعدتك؟\n\nاكتب 'مساعدة' لعرض الأوامر المتاحة.");
        }

        if (std.mem.indexOf(u8, input, "شكرا") != null or std.mem.indexOf(u8, input, "thank") != null) {
            return self.allocator.dupe(u8, "العفو! سعيد بمساعدتك. هل لديك سؤال آخر؟");
        }

        if (std.mem.indexOf(u8, input, "وداعا") != null or std.mem.indexOf(u8, input, "مع السلامة") != null or std.mem.indexOf(u8, input, "bye") != null) {
            if (self.context.getUserName()) |name| {
                return std.fmt.allocPrint(self.allocator, "إلى اللقاء {s}! كان من دواعي سروري مساعدتك. 👋", .{name});
            }
            return self.allocator.dupe(u8, "إلى اللقاء! كان من دواعي سروري مساعدتك. 👋");
        }

        // 3. محاولة الرد بناءً على كلمات مفتاحية
        if (std.mem.indexOf(u8, input, "كيف حالك") != null) {
            if (self.context.getUserName()) |name| {
                return std.fmt.allocPrint(self.allocator, "أنا بخير {s}، شكراً لسؤالك! 🌟 أنا جاهز لمساعدتك.", .{name});
            }
            return self.allocator.dupe(u8, "أنا بخير، شكراً لسؤالك! 🌟 أنا جاهز لمساعدتك في أي شيء.");
        }

        // 3.5. هل يعرف المستخدم اسمي؟
        if (std.mem.indexOf(u8, input, "ما اسمي") != null or std.mem.indexOf(u8, input, "هل تعرف اسمي") != null) {
            if (self.context.getUserName()) |name| {
                return std.fmt.allocPrint(self.allocator, "نعم! اسمك {s}. 😊", .{name});
            }
            return self.allocator.dupe(u8, "لا أعرف اسمك بعد. أخبرني: 'اسمي أحمد'");
        }

        // 4. رد عام مفيد
        return std.fmt.allocPrint(
            self.allocator,
            "لم أفهم رسالتك تماماً: '{s}'\n\nجرّب:\n• 'مساعدة' - عرض الأوامر\n• 'sqrt(25)+10' - حساب\n• 'كم الساعة' - وقت\n• 'ما هو الذكاء الاصطناعي' - معلومات\n• 'طقس في القاهرة' - الطقس\n• 'سعر الدولار' - العملات\n• 'ترجم للإنجليزية: مرحبا' - ترجمة\n• 'اسمي أحمد' - تعريف بالنفس",
            .{input},
        );
    }

    /// تدريب على نص جديد
    pub fn learn(self: *SuperAgent, text: []const u8) !void {
        // تدريب n-gram model (يعمل دائماً)
        self.ngram_model.train(text) catch {};

        if (self.tokenizer == null) return;

        var it = std.mem.tokenizeAny(u8, text, " \t\n\r.,;:!?'\"()[]{}");
        while (it.next()) |word| {
            if (word.len >= 2 and word.len <= 20) {
                _ = self.tokenizer.?.addToken(word) catch {};
            }
        }

        std.fs.cwd().makePath(self.config.model_dir) catch {};

        var path_buf: [256]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buf, "{s}/tokenizer.txt", .{self.config.model_dir});
        self.tokenizer.?.save(path) catch {};
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
