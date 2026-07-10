// src/ngram.zig - نموذج n-gram للتوليد المتماسك
// يعمل بدون تدريب عميق - يحلل الأنماط من النصوص ويولد نصاً متماسكاً
const std = @import("std");
const Tokenizer = @import("tokenizer.zig").Tokenizer;

pub const NGramModel = struct {
    allocator: std.mem.Allocator,
    // bigrams: word -> list of words that follow
    bigrams: std.StringHashMap(std.ArrayList([]u8)),
    // trigrams: "word1 word2" -> list of words that follow
    trigrams: std.StringHashMap(std.ArrayList([]u8)),
    // unigrams (for fallback)
    unigrams: std.ArrayList([]u8),
    trained: bool,
    string_arena: std.heap.ArenaAllocator,

    pub fn init(allocator: std.mem.Allocator) NGramModel {
        return .{
            .allocator = allocator,
            .bigrams = std.StringHashMap(std.ArrayList([]u8)).init(allocator),
            .trigrams = std.StringHashMap(std.ArrayList([]u8)).init(allocator),
            .unigrams = std.ArrayList([]u8).init(allocator),
            .trained = false,
            .string_arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: *NGramModel) void {
        var iter_b = self.bigrams.iterator();
        while (iter_b.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.bigrams.deinit();

        var iter_t = self.trigrams.iterator();
        while (iter_t.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.trigrams.deinit();
        self.unigrams.deinit();
        self.string_arena.deinit();
    }

    /// تدريب على نص
    pub fn train(self: *NGramModel, text: []const u8) !void {
        var words = std.ArrayList([]const u8).init(self.allocator);
        defer words.deinit();

        var it = std.mem.tokenizeAny(u8, text, " \t\n\r.,;:!?'\"()[]{}");
        while (it.next()) |word| {
            try words.append(word);
        }

        if (words.items.len < 3) return;

        // بناء unigrams
        for (words.items) |word| {
            const owned = try self.string_arena.allocator().dupe(u8, word);
            try self.unigrams.append(owned);
        }

        // بناء bigrams
        var i: usize = 0;
        while (i + 1 < words.items.len) : (i += 1) {
            const key = try self.string_arena.allocator().dupe(u8, words.items[i]);
            const next_word = try self.string_arena.allocator().dupe(u8, words.items[i + 1]);

            const entry = try self.bigrams.getOrPut(key);
            if (!entry.found_existing) {
                entry.value_ptr.* = std.ArrayList([]u8).init(self.allocator);
            }
            try entry.value_ptr.*.append(next_word);
        }

        // بناء trigrams
        i = 0;
        while (i + 2 < words.items.len) : (i += 1) {
            const key = try std.fmt.allocPrint(self.string_arena.allocator(), "{s} {s}", .{ words.items[i], words.items[i + 1] });
            const next_word = try self.string_arena.allocator().dupe(u8, words.items[i + 2]);

            const entry = try self.trigrams.getOrPut(key);
            if (!entry.found_existing) {
                entry.value_ptr.* = std.ArrayList([]u8).init(self.allocator);
            }
            try entry.value_ptr.*.append(next_word);
        }

        self.trained = true;
    }

    /// توليد نص من prompt
    pub fn generate(self: *NGramModel, allocator: std.mem.Allocator, prompt: []const u8, max_words: usize) ![]u8 {
        if (!self.trained or self.unigrams.items.len == 0) {
            return allocator.dupe(u8, "");
        }

        var result = std.ArrayList(u8).init(allocator);
        defer result.deinit();

        // إضافة الـ prompt
        try result.appendSlice(prompt);

        // تقسيم الـ prompt لكلمات
        var prompt_words = std.ArrayList([]const u8).init(allocator);
        defer prompt_words.deinit();

        var it = std.mem.tokenizeAny(u8, prompt, " \t\n\r.,;:!?'\"()[]{}");
        while (it.next()) |word| {
            try prompt_words.append(word);
        }

        // آخر كلمتين من الـ prompt
        var prev_word: ?[]const u8 = if (prompt_words.items.len >= 1) prompt_words.items[prompt_words.items.len - 1] else null;
        var prev_prev_word: ?[]const u8 = if (prompt_words.items.len >= 2) prompt_words.items[prompt_words.items.len - 2] else null;

        var rng = std.Random.DefaultPrng.init(@bitCast(std.time.timestamp()));
        var random = rng.random();

        var word_count: usize = 0;
        while (word_count < max_words) : (word_count += 1) {
            var next_word: ?[]const u8 = null;

            // محاولة trigram أولاً
            if (prev_prev_word != null and prev_word != null) {
                const key = try std.fmt.allocPrint(allocator, "{s} {s}", .{ prev_prev_word.?, prev_word.? });
                defer allocator.free(key);
                if (self.trigrams.get(key)) |list| {
                    if (list.items.len > 0) {
                        const idx = random.uintLessThan(usize, list.items.len);
                        next_word = list.items[idx];
                    }
                }
            }

            // محاولة bigram
            if (next_word == null and prev_word != null) {
                if (self.bigrams.get(prev_word.?)) |list| {
                    if (list.items.len > 0) {
                        const idx = random.uintLessThan(usize, list.items.len);
                        next_word = list.items[idx];
                    }
                }
            }

            // fallback: كلمة عشوائية
            if (next_word == null) {
                const idx = random.uintLessThan(usize, self.unigrams.items.len);
                next_word = self.unigrams.items[idx];
            }

            try result.append(' ');
            try result.appendSlice(next_word.?);

            // تحديث السياق
            prev_prev_word = prev_word;
            prev_word = next_word;
        }

        return result.toOwnedSlice();
    }

    /// تدريب على corpus كبير مدمج
    pub fn trainOnBuiltinCorpus(self: *NGramModel) !void {
        const corpus = [_][]const u8{
            "مرحبا بك في Super Agent أنا وكيل ذكاء اصطناعي خارق خفيف الوزن",
            "أعمل على أجهزة منخفضة الإمكانيات أحتاج فقط 2 جيجابايت رام ومعالج 4 cores",
            "لا أحتاج كارت شاشة أتعلم من الإنترنت تلقائياً",
            "أنا مبرمج بلغة Zig Zig لغة سريعة وآمنة ومناسبة للأجهزة المنخفضة",
            "الذكاء الاصطناعي هو محاكاة ذكاء البشر في الآلات",
            "التعلم الآلي فرع من الذكاء الاصطناعي يتعلم النموذج من البيانات",
            "الشبكات العصبية محاكاة للدماغ البشري تتكون من طبقات مترابطة",
            "محولات الترانسفورمر أحدث ثورة في معالجة اللغة الطبيعية",
            "Zig لغة برمجة systems تتميز بالسرعة والأمان والتحكم الكامل",
            "الإنترنت مصدر هائل للمعرفة يمكن للوكيل التعلم منه تلقائياً",
            "Super Agent is a powerful AI built in Zig language",
            "Artificial intelligence is the simulation of human intelligence in machines",
            "Machine learning is a branch of AI Models learn from data",
            "Neural networks simulate the human brain They consist of connected layers",
            "Transformers revolutionized natural language processing",
            "Zig is a systems programming language It is fast and safe",
            "The model uses backpropagation with Adam optimizer for training",
            "يمكنك استخدام الحاسبة للحساب الرياضي مثل الجمع والطرح والضرب",
            "الترجمة متاحة بين العربية والإنجليزية والفرنسية والإسبانية",
            "يمكنني قراءة وكتابة الملفات في مجلد العمل",
            "الطقس متاح لأي مدينة في العالم عبر خدمة wttr",
            "أسعار الصرف متاحة للعملات الرئيسية",
            "أتعلم من كل محادثة وأحفظ المعلومات المهمة",
            "يمكنك سؤالي عن أي موضوع وأحاول الإجابة",
            "البرمجة هي كتابة تعليمات للكمبيوتر لحل المشاكل",
            "الخوارزمية هي مجموعة خطوات لحل مشكلة معينة",
            "قاعدة البيانات تخزن المعلومات بشكل منظم",
            "API يسمح للتطبيقات بالتواصل مع بعضها",
            "Docker يحزم التطبيقات في حاويات محمولة",
            "Git نظام تحكم بالإصدارات لتتبع التغييرات",
            "البلوكشين سجل موزع لا مركزي للمعاملات",
            "الحوسبة السحابية توفر موارد مرنة حسب الطلب",
            "الأمن السيبراني يحمي الأنظمة من الهجمات",
            "التعلم العميق يستخدم شبكات عصبية متعددة الطبقات",
            "معالجة اللغة الطبيعية تفهم وتولد اللغة البشرية",
            "الرؤية الحاسوبية تحلل الصور والفيديو",
            "الروبوتات تدمج البرمجة مع الميكانيكا",
            "الرياضيات علم الأرقام والأنماط",
            "الفيزياء علم المادة والطاقة",
            "الكيمياء علم المادة وتحولاتها",
            "الأحياء علم الكائنات الحية",
            "التاريخ دراسة الماضي البشري",
            "الجغرافيا علم الأرض وسكانها",
            "الأدب فن الكلمة المكتوبة",
            "الشعر فن التعبير بالكلمة الموزونة",
            "الموسيقى فن تنظيم الأصوات",
            "الفلسفة حب الحكمة والتفكير العميق",
        };

        for (corpus) |text| {
            try self.train(text);
        }
    }
};
