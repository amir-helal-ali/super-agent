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
const responses = @import("responses.zig");
const sentiment_mod = @import("sentiment.zig");
const summarizer = @import("summarizer.zig");
const brain_mod = @import("brain.zig");
const ltm_mod = @import("long_term_memory.zig");

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
    brain: brain_mod.Brain,
    long_term_memory: ltm_mod.LongTermMemory,

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
            .brain = brain_mod.Brain.init(allocator),
            .long_term_memory = ltm_mod.LongTermMemory.init(allocator, "data/memory/long_term.txt") catch ltm_mod.LongTermMemory{
                .allocator = allocator,
                .facts = std.ArrayList(ltm_mod.Fact).init(allocator),
                .file_path = "",
            },
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
        self.brain.deinit();
        self.long_term_memory.deinit();
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

        // استخراج وحفظ معلومات في الذاكرة طويلة المدى
        self.long_term_memory.extractAndStore(user_input);

        // 0.1. طلب ملخص المحادثة
        if (std.mem.indexOf(u8, user_input, "ملخص") != null or
            std.mem.indexOf(u8, user_input, "لخص") != null or
            std.mem.indexOf(u8, user_input, "summary") != null or
            std.mem.indexOf(u8, user_input, "ماذا تحدثنا") != null)
        {
            const summary = summarizer.summarize(self.allocator, &self.context) catch null;
            if (summary) |s| {
                try tools_used.append("summarizer");
                steps_taken += 1;
                self.context.addMessage("assistant", s) catch {};
                return .{
                    .answer = s,
                    .steps_taken = steps_taken,
                    .tools_used = tools_used,
                    .learned = false,
                    .allocator = self.allocator,
                };
            }
        }

        // 0. تحليل المشاعر - إضافة رد عاطفي إذا لزم
        const detected_sentiment = sentiment_mod.analyze(user_input);
        if (detected_sentiment != .neutral) {
            const sentiment_reply = sentiment_mod.responseForSentiment(detected_sentiment);
            if (sentiment_reply.len > 0) {
                // نضيف الرد العاطفي قبل الرد الفعلي
                // لكن فقط إذا لم يكن سؤالاً مباشراً
                const is_question = std.mem.indexOf(u8, user_input, "؟") != null or
                    std.mem.indexOf(u8, user_input, "?") != null or
                    std.mem.indexOf(u8, user_input, "ما ") != null or
                    std.mem.indexOf(u8, user_input, "كم ") != null or
                    std.mem.indexOf(u8, user_input, "كيف ") != null;
                if (!is_question) {
                    try tools_used.append("sentiment");
                    steps_taken += 1;
                    self.context.addMessage("assistant", sentiment_reply) catch {};
                    return .{
                        .answer = try self.allocator.dupe(u8, sentiment_reply),
                        .steps_taken = steps_taken,
                        .tools_used = tools_used,
                        .learned = false,
                        .allocator = self.allocator,
                    };
                }
            }
        }

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
        // استخدام العقل المدبر - يحلل النية ويرد بشكل بشري
        return self.brain.respond(input, &self.context) catch {
            return self.fallbackResponse(input);
        };
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
        // 1. البحث في قاعدة المعرفة (تامة + ضبابية)
        if (knowledge.search(input)) |response| {
            return self.allocator.dupe(u8, response);
        }

        // 2. ردود متنوعة للترحيب
        if (std.mem.indexOf(u8, input, "مرحبا") != null or
            std.mem.indexOf(u8, input, "السلام") != null or
            std.mem.indexOf(u8, input, "اهلا") != null or
            std.mem.indexOf(u8, input, "hello") != null or
            std.mem.indexOf(u8, input, "hi") != null)
        {
            const greeting = responses.greeting();
            if (self.context.getUserName()) |name| {
                return std.fmt.allocPrint(self.allocator, "{s} {s}! 🌟\n\nاكتب 'مساعدة' لعرض الأوامر.", .{ greeting, name });
            }
            return std.fmt.allocPrint(self.allocator, "{s}\n\nاكتب 'مساعدة' لعرض الأوامر.", .{greeting});
        }

        // 3. ردود متنوعة للشكر
        if (std.mem.indexOf(u8, input, "شكرا") != null or std.mem.indexOf(u8, input, "thank") != null or
            std.mem.indexOf(u8, input, "ممتاز") != null or std.mem.indexOf(u8, input, "رائع") != null)
        {
            return self.allocator.dupe(u8, responses.thanks());
        }

        // 4. ردود متنوعة للوداع
        if (std.mem.indexOf(u8, input, "وداعا") != null or std.mem.indexOf(u8, input, "مع السلامة") != null or
            std.mem.indexOf(u8, input, "bye") != null or std.mem.indexOf(u8, input, "إلى اللقاء") != null)
        {
            if (self.context.getUserName()) |name| {
                return std.fmt.allocPrint(self.allocator, "إلى اللقاء {s}! 👋", .{name});
            }
            return self.allocator.dupe(u8, responses.farewell());
        }

        // 5. كيف حالك
        if (std.mem.indexOf(u8, input, "كيف حالك") != null or std.mem.indexOf(u8, input, "كيف الحال") != null) {
            if (self.context.getUserName()) |name| {
                return std.fmt.allocPrint(self.allocator, "أنا بخير {s}، شكراً لسؤالك! 🌟 أنا جاهز لمساعدتك.", .{name});
            }
            return self.allocator.dupe(u8, "أنا بخير، شكراً لسؤالك! 🌟 أنا جاهز لمساعدتك في أي شيء.");
        }

        // 6. استرجاع الاسم
        if (std.mem.indexOf(u8, input, "ما اسمي") != null or std.mem.indexOf(u8, input, "هل تعرف اسمي") != null or
            std.mem.indexOf(u8, input, "ما هو اسمي") != null)
        {
            if (self.context.getUserName()) |name| {
                return std.fmt.allocPrint(self.allocator, "نعم! اسمك {s}. 😊", .{name});
            }
            return self.allocator.dupe(u8, "لا أعرف اسمك بعد. أخبرني: 'اسمي أحمد'");
        }

        // 6.5. تعريف الاسم - "اسمي امير" أو "انا اسمي امير"
        if (std.mem.indexOf(u8, input, "اسمي") != null or std.mem.indexOf(u8, input, "أنا اسمي") != null or
            std.mem.indexOf(u8, input, "انا اسمي") != null)
        {
            // الاسم تم حفظه بالفعل في context.addMessage -> extractUserInfo
            if (self.context.getUserName()) |name| {
                return std.fmt.allocPrint(self.allocator, "سعدت بمعرفتك {s}! 😊 كيف يمكنني مساعدتك؟", .{name});
            }
        }

        // 6.6. تعريف الموقع - "أعيش في" أو "اسكن في"
        if (std.mem.indexOf(u8, input, "أعيش في") != null or std.mem.indexOf(u8, input, "اسكن في") != null or
            std.mem.indexOf(u8, input, "اسكن") != null or std.mem.indexOf(u8, input, "أعيش") != null)
        {
            if (self.context.getUserLocation()) |loc| {
                return std.fmt.allocPrint(self.allocator, "ممتاز! {s} مدينة جميلة. 🌍 كيف أساعدك؟", .{loc});
            }
        }

        // 6.7. موافقة وتأكيد - "نعم", "ok", "حسنا", "تمام"
        if (std.mem.eql(u8, input, "نعم") or std.mem.eql(u8, input, "ok") or
            std.mem.eql(u8, input, "حسنا") or std.mem.eql(u8, input, "تمام") or
            std.mem.eql(u8, input, "yes") or std.mem.eql(u8, input, "حاضر") or
            std.mem.eql(u8, input, "أهلا"))
        {
            const ack_replies = [_][]const u8{
                "تمام! 😊 ماذا تريد أن نفعل؟",
                "حسناً! أنا جاهز. ما الخطوة التالية؟",
                "ممتاز! هل لديك سؤال آخر؟",
            };
            var rng = std.Random.DefaultPrng.init(@bitCast(std.time.timestamp()));
            const idx = rng.random().uintLessThan(usize, ack_replies.len);
            return self.allocator.dupe(u8, ack_replies[idx]);
        }

        // 7. رد ذكي مع اقتراحات
        return responses.suggestResponse(input, self.allocator);
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
