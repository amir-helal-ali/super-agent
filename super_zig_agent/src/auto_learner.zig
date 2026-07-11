// src/auto_learner.zig - نظام التعلم الذاتي التلقائي
// يزحف الإنترنت تلقائياً ويتعلم من كل المصادر العالمية
const std = @import("std");
const web = @import("web/mod.zig");
const corpus = @import("corpus.zig");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Memory = @import("memory.zig").Memory;
const Trainer = @import("trainer.zig").Trainer;
const LanguageModel = @import("model.zig").LanguageModel;

/// مصادر ويب عالمية متنوعة (عربي + إنجليزي)
pub const GLOBAL_SOURCES = [_][]const u8{
    // ويكيبيديا العربية
    "https://ar.wikipedia.org/wiki/الذكاء_الاصطناعي",
    "https://ar.wikipedia.org/wiki/تعلم_الآلة",
    "https://ar.wikipedia.org/wiki/برمجة",
    "https://ar.wikipedia.org/wiki/حاسوب",
    "https://ar.wikipedia.org/wiki/إنترنت",
    "https://ar.wikipedia.org/wiki/رياضيات",
    "https://ar.wikipedia.org/wiki/فيزياء",
    "https://ar.wikipedia.org/wiki/كيمياء",
    "https://ar.wikipedia.org/wiki/أحياء",
    "https://ar.wikipedia.org/wiki/تاريخ",
    "https://ar.wikipedia.org/wiki/جغرافيا",
    "https://ar.wikipedia.org/wiki/فلسفة",
    "https://ar.wikipedia.org/wiki/أدب",
    "https://ar.wikipedia.org/wiki/علم_النفس",
    "https://ar.wikipedia.org/wiki/اقتصاد",
    "https://ar.wikipedia.org/wiki/طب",
    "https://ar.wikipedia.org/wiki/هندسة",
    "https://ar.wikipedia.org/wiki/فن",
    "https://ar.wikipedia.org/wiki/موسيقى",
    "https://ar.wikipedia.org/wiki/رياضة",
    // ويكيبيديا الإنجليزية
    "https://en.wikipedia.org/wiki/Artificial_intelligence",
    "https://en.wikipedia.org/wiki/Machine_learning",
    "https://en.wikipedia.org/wiki/Programming_language",
    "https://en.wikipedia.org/wiki/Computer_science",
    "https://en.wikipedia.org/wiki/Algorithm",
    "https://en.wikipedia.org/wiki/Data_structure",
    "https://en.wikipedia.org/wiki/Database",
    "https://en.wikipedia.org/wiki/Web_development",
    "https://en.wikipedia.org/wiki/Software_engineering",
    "https://en.wikipedia.org/wiki/Cybersecurity",
    "https://en.wikipedia.org/wiki/Cloud_computing",
    "https://en.wikipedia.org/wiki/Blockchain",
    "https://en.wikipedia.org/wiki/Robotics",
    "https://en.wikipedia.org/wiki/Mathematics",
    "https://en.wikipedia.org/wiki/Physics",
    "https://en.wikipedia.org/wiki/Chemistry",
    "https://en.wikipedia.org/wiki/Biology",
    "https://en.wikipedia.org/wiki/Zig_(programming_language)",
    "https://en.wikipedia.org/wiki/Rust_(programming_language)",
    "https://en.wikipedia.org/wiki/Python_(programming_language)",
    // مواقع تعليمية
    "https://en.wikipedia.org/wiki/Deep_learning",
    "https://en.wikipedia.org/wiki/Neural_network",
    "https://en.wikipedia.org/wiki/Natural_language_processing",
    "https://en.wikipedia.org/wiki/Transformer_(deep_learning_architecture)",
    "https://en.wikipedia.org/wiki/GPT",
    "https://en.wikipedia.org/wiki/BERT_(language_model)",
    "https://en.wikipedia.org/wiki/Docker_(software)",
    "https://en.wikipedia.org/wiki/Kubernetes",
    "https://en.wikipedia.org/wiki/Git",
    "https://en.wikipedia.org/wiki/Linux",
    "https://en.wikipedia.org/wiki/JavaScript",
    "https://en.wikipedia.org/wiki/TypeScript",
    "https://en.wikipedia.org/wiki/React",
    "https://en.wikipedia.org/wiki/Next.js",
    "https://en.wikipedia.org/wiki/Tailwind_CSS",
    "https://en.wikipedia.org/wiki/SQL",
    "https://en.wikipedia.org/wiki/MongoDB",
    "https://en.wikipedia.org/wiki/Redis",
    "https://en.wikipedia.org/wiki/GraphQL",
    "https://en.wikipedia.org/wiki/REST_API",
    "https://en.wikipedia.org/wiki/Microservices",
    "https://en.wikipedia.org/wiki/DevOps",
    "https://en.wikipedia.org/wiki/Agile_software_development",
    "https://en.wikipedia.org/wiki/CI/CD",
    "https://en.wikipedia.org/wiki/WebAssembly",
    "https://en.wikipedia.org/wiki/Quantum_computing",
    "https://en.wikipedia.org/wiki/Cryptography",
    "https://en.wikipedia.org/wiki/Operating_system",
    "https://en.wikipedia.org/wiki/Compiler",
    "https://en.wikipedia.org/wiki/Computer_network",
    "https://en.wikipedia.org/wiki/HTTP",
    "https://en.wikipedia.org/wiki/JSON",
    "https://en.wikipedia.org/wiki/API",
};

pub const AutoLearner = struct {
    allocator: std.mem.Allocator,
    trainer: *Trainer,
    memory: *Memory,
    tokenizer: *Tokenizer,
    model: *LanguageModel,
    total_pages_learned: usize,
    total_sentences_learned: usize,
    is_learning: bool,

    pub fn init(
        allocator: std.mem.Allocator,
        trainer: *Trainer,
        memory: *Memory,
        tokenizer: *Tokenizer,
        model: *LanguageModel,
    ) AutoLearner {
        return .{
            .allocator = allocator,
            .trainer = trainer,
            .memory = memory,
            .tokenizer = tokenizer,
            .model = model,
            .total_pages_learned = 0,
            .total_sentences_learned = 0,
            .is_learning = false,
        };
    }

    /// التعلم التلقائي الكامل من كل المصادر العالمية
    pub fn learnFromAllSources(self: *AutoLearner) !void {
        self.is_learning = true;
        defer self.is_learning = false;

        const stdout = std.io.getStdOut().writer();

        // المرحلة 1: التدريب على corpus المدمج (260+ جملة)
        try stdout.print("\n📚 المرحلة 1: التدريب على corpus المدمج (260+ جملة)...\n", .{});
        const corpus_stats = try self.trainer.trainIntensive(5);
        try stdout.print("   ✅ {d} مثال، خسارة: {d:.4}\n", .{ corpus_stats.examples, corpus_stats.avg_loss });

        // المرحلة 2: الزحف والتعلم من 70+ مصدر عالمي
        try stdout.print("\n🌐 المرحلة 2: الزحف والتعلم من {d} مصدر عالمي...\n", .{GLOBAL_SOURCES.len});

        var crawler = web.Crawler.init(self.allocator, GLOBAL_SOURCES.len);
        defer crawler.deinit();

        for (GLOBAL_SOURCES) |url| {
            crawler.addUrl(url) catch continue;
        }

        var pages = crawler.crawl() catch {
            try stdout.print("   ⚠️ تعذر الزحف - المتابعة بالبيانات المتاحة\n", .{});
            // حفظ النموذج حتى لو فشل الزحف
            try self.model.save("data/model");
            try self.tokenizer.save("data/model/tokenizer.txt");
            return;
        };
        defer {
            for (pages.items) |p| self.allocator.free(p);
            pages.deinit();
        }

        try stdout.print("   📥 تم جلب {d} صفحة\n", .{pages.items.len});

        // المرحلة 3: التدريب على كل صفحة
        try stdout.print("\n🧠 المرحلة 3: التدريب على المحتوى المجلب...\n", .{});
        var web_examples: usize = 0;
        var web_loss: f32 = 0;

        for (pages.items, 0..) |page, i| {
            if (page.len < 50) continue;

            try stdout.print("   [{d}/{d}] تدريب على {d} بايت...\n", .{ i + 1, pages.items.len, page.len });

            // تقسيم الصفحة لجمل
            var sentence_it = std.mem.splitScalar(u8, page, '.');
            while (sentence_it.next()) |sentence| {
                const trimmed = std.mem.trim(u8, sentence, " \t\n\r");
                if (trimmed.len < 20 or trimmed.len > 500) continue;

                // تدريب على الجملة
                const stats = self.trainer.trainOnText(trimmed) catch continue;
                web_examples += stats.examples;
                web_loss += stats.total_loss;
                self.total_sentences_learned += 1;
            }

            // حفظ في الذاكرة
            if (page.len > 50 and page.len < 5000) {
                const key = std.fmt.allocPrint(self.allocator, "auto_learn_{d}", .{self.total_pages_learned}) catch continue;
                defer self.allocator.free(key);
                self.memory.remember(key, page) catch {};
            }

            self.total_pages_learned += 1;
        }

        // المرحلة 4: تدريب إضافي على corpus مرة أخرى لتعزيز التعلم
        try stdout.print("\n🔄 المرحلة 4: تعزيز التعلم (3 epochs إضافية)...\n", .{});
        const reinforce_stats = try self.trainer.trainIntensive(3);
        try stdout.print("   ✅ {d} مثال إضافي\n", .{reinforce_stats.examples});

        // المرحلة 5: حفظ النموذج
        try stdout.print("\n💾 المرحلة 5: حفظ النموذج...\n", .{});
        try self.model.save("data/model");
        try self.tokenizer.save("data/model/tokenizer.txt");

        // تقرير نهائي
        try stdout.print("\n", .{});
        try stdout.print("═══════════════════════════════════════\n", .{});
        try stdout.print("  ✅ التعلم التلقائي اكتمل!\n", .{});
        try stdout.print("═══════════════════════════════════════\n", .{});
        try stdout.print("  📚 corpus مدمج: {d} جملة\n", .{corpus.CORPUS_SIZE});
        try stdout.print("  🌐 صفحات ويب: {d}\n", .{self.total_pages_learned});
        try stdout.print("  📝 جمل ويب: {d}\n", .{self.total_sentences_learned});
        try stdout.print("  🧠 أمثلة corpus: {d}\n", .{corpus_stats.examples + reinforce_stats.examples});
        try stdout.print("  🌍 أمثلة ويب: {d}\n", .{web_examples});
        try stdout.print("  📊 خسارة corpus: {d:.4}\n", .{corpus_stats.avg_loss});
        if (web_examples > 0) {
            try stdout.print("  📊 خسارة ويب: {d:.4}\n", .{web_loss / @as(f32, @floatFromInt(web_examples))});
        }
        try stdout.print("  💾 النموذج محفوظ في: data/model/\n", .{});
        try stdout.print("═══════════════════════════════════════\n", .{});
    }

    /// التعلم من محادثة واحدة (يُستدعى بعد كل رد)
    pub fn learnFromConversation(self: *AutoLearner, user_input: []const u8, agent_response: []const u8) void {
        // تدريب على رسالة المستخدم
        _ = self.trainer.trainOnText(user_input) catch {};

        // تدريب على رد الوكيل
        _ = self.trainer.trainOnText(agent_response) catch {};

        // إضافة الكلمات الجديدة للـ tokenizer
        var it = std.mem.tokenizeAny(u8, user_input, " \t\n\r.,;:!?'\"()[]{}");
        while (it.next()) |word| {
            if (word.len >= 2 and word.len <= 20) {
                _ = self.tokenizer.addToken(word) catch {};
            }
        }

        // إضافة كلمات الرد
        it = std.mem.tokenizeAny(u8, agent_response, " \t\n\r.,;:!?'\"()[]{}");
        while (it.next()) |word| {
            if (word.len >= 2 and word.len <= 20) {
                _ = self.tokenizer.addToken(word) catch {};
            }
        }

        self.total_sentences_learned += 2;
    }

    /// تقرير حالة التعلم
    pub fn status(self: *AutoLearner) AutoLearnStatus {
        return .{
            .is_learning = self.is_learning,
            .pages_learned = self.total_pages_learned,
            .sentences_learned = self.total_sentences_learned,
            .corpus_size = corpus.CORPUS_SIZE,
            .global_sources = GLOBAL_SOURCES.len,
        };
    }
};

pub const AutoLearnStatus = struct {
    is_learning: bool,
    pages_learned: usize,
    sentences_learned: usize,
    corpus_size: usize,
    global_sources: usize,
};
