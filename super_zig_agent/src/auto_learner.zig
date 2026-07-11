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

    // === مصادر متنوعة غير ويكيبيديا ===

    // مواقع تعليم برمجي
    "https://www.w3schools.com/python/",
    "https://www.w3schools.com/js/",
    "https://www.w3schools.com/sql/",
    "https://www.w3schools.com/html/",
    "https://www.w3schools.com/css/",
    "https://www.w3schools.com/react/",
    "https://www.w3schools.com/nodejs/",
    "https://www.w3schools.com/python/numpy/",
    "https://www.w3schools.com/python/pandas/",
    "https://www.w3schools.com/python/matplotlib/",
    "https://www.w3schools.com/django/",
    "https://www.w3schools.com/typescript/",
    "https://www.w3schools.com/rust/",
    "https://www.w3schools.com/go/",
    "https://www.w3schools.com/php/",

    // MDN Web Docs (مرجع الويب)
    "https://developer.mozilla.org/en-US/docs/Web/JavaScript",
    "https://developer.mozilla.org/en-US/docs/Web/HTML",
    "https://developer.mozilla.org/en-US/docs/Web/CSS",
    "https://developer.mozilla.org/en-US/docs/Web/API",
    "https://developer.mozilla.org/en-US/docs/Web/HTTP",
    "https://developer.mozilla.org/en-US/docs/Web/Web_Components",
    "https://developer.mozilla.org/en-US/docs/Web/Accessibility",
    "https://developer.mozilla.org/en-US/docs/Glossary/REST_API",

    // FreeCodeCamp (دروس مجانية)
    "https://www.freecodecamp.org/news/what-is-python/",
    "https://www.freecodecamp.org/news/what-is-javascript/",
    "https://www.freecodecamp.org/news/the-react-handbook/",
    "https://www.freecodecamp.org/news/the-node-js-handbook/",
    "https://www.freecodecamp.org/news/the-docker-handbook/",
    "https://www.freecodecamp.org/news/the-git-handbook/",
    "https://www.freecodecamp.org/news/the-css-handbook/",
    "https://www.freecodecamp.org/news/the-html-handbook/",
    "https://www.freecodecamp.org/news/what-is-a-database/",
    "https://www.freecodecamp.org/news/machine-learning/",
    "https://www.freecodecamp.org/news/deep-learning/",
    "https://www.freecodecamp.org/news/python-for-data-science/",
    "https://www.freecodecamp.org/news/linux-command-line/",
    "https://www.freecodecamp.org/news/how-to-use-the-command-line/",
    "https://www.freecodecamp.org/news/web-development/",
    "https://www.freecodecamp.org/news/full-stack-development/",
    "https://www.freecodecamp.org/news/what-is-an-api/",
    "https://www.freecodecamp.org/news/rest-api-tutorial/",
    "https://www.freecodecamp.org/news/what-is-git/",
    "https://www.freecodecamp.org/news/how-to-use-git/",
    "https://www.freecodecamp.org/news/what-is-docker/",
    "https://www.freecodecamp.org/news/what-is-kubernetes/",
    "https://www.freecodecamp.org/news/what-is-cybersecurity/",
    "https://www.freecodecamp.org/news/what-is-blockchain/",
    "https://www.freecodecamp.org/news/what-is-cloud-computing/",

    // GeeksforGeeks (شروحات تقنية)
    "https://www.geeksforgeeks.org/introduction-to-python/",
    "https://www.geeksforgeeks.org/javascript-tutorial/",
    "https://www.geeksforgeeks.org/data-structures/",
    "https://www.geeksforgeeks.org/algorithms/",
    "https://www.geeksforgeeks.org/machine-learning/",
    "https://www.geeksforgeeks.org/deep-learning/",
    "https://www.geeksforgeeks.org/artificial-intelligence/",
    "https://www.geeksforgeeks.org/sql-tutorial/",
    "https://www.geeksforgeeks.org/dbms/",
    "https://www.geeksforgeeks.org/computer-network-tutorials/",
    "https://www.geeksforgeeks.org/operating-systems/",
    "https://www.geeksforgeeks.org/compiler-design-tutorials/",
    "https://www.geeksforgeeks.org/software-engineering/",
    "https://www.geeksforgeeks.org/web-technologies/",
    "https://www.geeksforgeeks.org/reactjs-tutorial/",
    "https://www.geeksforgeeks.org/nodejs-tutorial/",
    "https://www.geeksforgeeks.org/django-tutorial/",
    "https://www.geeksforgeeks.org/typescript-tutorial/",
    "https://www.geeksforgeeks.org/docker-tutorial/",
    "https://www.geeksforgeeks.org/kubernetes-tutorial/",
    "https://www.geeksforgeeks.org/git-tutorial/",
    "https://www.geeksforgeeks.org/linux-tutorial/",
    "https://www.geeksforgeeks.org/cyber-security-tutorial/",
    "https://www.geeksforgeeks.org/cloud-computing/",
    "https://www.geeksforgeeks.org/blockchain-tutorial/",

    // مواقع عربية تعليمية
    "https://harmash.com/tutorials/programming/python",
    "https://harmash.com/tutorials/programming/javascript",
    "https://harmash.com/tutorials/databases/sql",
    "https://harmash.com/tutorials/web/html",
    "https://harmash.com/tutorials/web/css",
    "https://harmash.com/tutorials/networks/network_basics",
    "https://harmash.com/tutorials/programming/algorithms",
    "https://harmash.com/tutorials/programming/data-structures",
    "https://harmash.com/tutorials/ai/machine-learning",
    "https://harmash.com/tutorials/security/information-security",

    // Stack Overflow (أسئلة وأجوبة شائعة)
    "https://stackoverflow.com/questions/tagged/python?tab=Votes",
    "https://stackoverflow.com/questions/tagged/javascript?tab=Votes",
    "https://stackoverflow.com/questions/tagged/java?tab=Votes",
    "https://stackoverflow.com/questions/tagged/reactjs?tab=Votes",
    "https://stackoverflow.com/questions/tagged/docker?tab=Votes",
    "https://stackoverflow.com/questions/tagged/git?tab=Votes",
    "https://stackoverflow.com/questions/tagged/sql?tab=Votes",
    "https://stackoverflow.com/questions/tagged/linux?tab=Votes",
    "https://stackoverflow.com/questions/tagged/html?tab=Votes",
    "https://stackoverflow.com/questions/tagged/css?tab=Votes",
    "https://stackoverflow.com/questions/tagged/typescript?tab=Votes",
    "https://stackoverflow.com/questions/tagged/rust?tab=Votes",
    "https://stackoverflow.com/questions/tagged/node.js?tab=Votes",
    "https://stackoverflow.com/questions/tagged/machine-learning?tab=Votes",
    "https://stackoverflow.com/questions/tagged/artificial-intelligence?tab=Votes",

    // GitHub (وثائق ومشاريع)
    "https://github.com/microsoft/vscode",
    "https://github.com/facebook/react",
    "https://github.com/vercel/next.js",
    "https://github.com/nodejs/node",
    "https://github.com/python/cpython",
    "https://github.com/rust-lang/rust",
    "https://github.com/golang/go",
    "https://github.com/microsoft/TypeScript",
    "https://github.com/tailwindlabs/tailwindcss",
    "https://github.com/docker/compose",
    "https://github.com/kubernetes/kubernetes",
    "https://github.com/git/git",

    // مدونات تقنية
    "https://martinfowler.com/articles/microservices.html",
    "https://martinfowler.com/articles/continuousIntegration.html",
    "https://www.docker.com/blog/",
    "https://kubernetes.io/blog/",
    "https://web.dev/learn/",
    "https://developers.google.com/machine-learning/crash-course",
    "https://developers.google.com/web/fundamentals",
    "https://aws.amazon.com/what-is-cloud-computing/",
    "https://azure.microsoft.com/en-us/overview/what-is-azure/",
    "https://cloud.google.com/learn",

    // علوم ومعرفة عامة
    "https://www.britannica.com/technology/artificial-intelligence",
    "https://www.britannica.com/technology/computer-science",
    "https://www.britannica.com/science/physics-science",
    "https://www.britannica.com/science/chemistry",
    "https://www.britannica.com/science/biology",
    "https://www.britannica.com/science/mathematics",
    "https://www.britannica.com/topic/philosophy",
    "https://www.britannica.com/topic/economics",
    "https://www.britannica.com/event/history-of-Europe",
    "https://www.britannica.com/topic/psychology",

    // Khan Academy (تعليم)
    "https://www.khanacademy.org/computing/computer-science",
    "https://www.khanacademy.org/computing/computer-programming",
    "https://www.khanacademy.org/math",
    "https://www.khanacademy.org/science/physics",
    "https://www.khanacademy.org/science/chemistry",
    "https://www.khanacademy.org/science/biology",
    "https://www.khanacademy.org/humanities",

    // Coursera (دروس)
    "https://www.coursera.org/learn/machine-learning",
    "https://www.coursera.org/learn/python",
    "https://www.coursera.org/learn/data-science",
    "https://www.coursera.org/learn/algorithms",
    "https://www.coursera.org/learn/web-design",

    // مواقع أخبار تقنية
    "https://techcrunch.com/category/artificial-intelligence/",
    "https://www.theverge.com/ai-artificial-intelligence",
    "https://arstechnica.com/ai/",
    "https://www.wired.com/tag/artificial-intelligence/",
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
