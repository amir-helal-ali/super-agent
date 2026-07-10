// src/ngram.zig - نموذج n-gram محسن مع فصل اللغات
const std = @import("std");

pub const NGramModel = struct {
    allocator: std.mem.Allocator,
    // bigrams مفصولة حسب اللغة
    ar_bigrams: std.StringHashMap(std.ArrayList([]u8)),
    en_bigrams: std.StringHashMap(std.ArrayList([]u8)),
    // trigrams مفصولة حسب اللغة
    ar_trigrams: std.StringHashMap(std.ArrayList([]u8)),
    en_trigrams: std.StringHashMap(std.ArrayList([]u8)),
    // unigrams مفصولة
    ar_unigrams: std.ArrayList([]u8),
    en_unigrams: std.ArrayList([]u8),
    trained: bool,
    string_arena: std.heap.ArenaAllocator,

    pub fn init(allocator: std.mem.Allocator) NGramModel {
        return .{
            .allocator = allocator,
            .ar_bigrams = std.StringHashMap(std.ArrayList([]u8)).init(allocator),
            .en_bigrams = std.StringHashMap(std.ArrayList([]u8)).init(allocator),
            .ar_trigrams = std.StringHashMap(std.ArrayList([]u8)).init(allocator),
            .en_trigrams = std.StringHashMap(std.ArrayList([]u8)).init(allocator),
            .ar_unigrams = std.ArrayList([]u8).init(allocator),
            .en_unigrams = std.ArrayList([]u8).init(allocator),
            .trained = false,
            .string_arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: *NGramModel) void {
        var iter = self.ar_bigrams.iterator();
        while (iter.next()) |e| e.value_ptr.*.deinit();
        self.ar_bigrams.deinit();

        iter = self.en_bigrams.iterator();
        while (iter.next()) |e| e.value_ptr.*.deinit();
        self.en_bigrams.deinit();

        iter = self.ar_trigrams.iterator();
        while (iter.next()) |e| e.value_ptr.*.deinit();
        self.ar_trigrams.deinit();

        iter = self.en_trigrams.iterator();
        while (iter.next()) |e| e.value_ptr.*.deinit();
        self.en_trigrams.deinit();

        self.ar_unigrams.deinit();
        self.en_unigrams.deinit();
        self.string_arena.deinit();
    }

    /// كشف هل الكلمة عربية
    fn isArabic(word: []const u8) bool {
        for (word) |b| {
            // نطاق UTF-8 للحروف العربية: D8 80 - D9 BF تقريباً
            if (b == 0xD8 or b == 0xD9) return true;
            // أو إذا كانت كلمة عربية بسيطة معروفة
        }
        // فحص إضافي: هل تحتوي على أحرف عربية؟
        if (word.len >= 2) {
            if (word[0] >= 0xD8 and word[0] <= 0xD9) return true;
        }
        return false;
    }

    /// كشف لغة نص كامل
    fn detectLanguage(text: []const u8) bool {
        // يعيد true للعربية، false للإنجليزية
        var ar_count: usize = 0;
        var en_count: usize = 0;
        for (text) |b| {
            if (b >= 0xD8 and b <= 0xD9) ar_count += 1;
            if (b >= 'a' and b <= 'z') en_count += 1;
            if (b >= 'A' and b <= 'Z') en_count += 1;
        }
        return ar_count > en_count;
    }

    /// تدريب على نص
    pub fn train(self: *NGramModel, text: []const u8) !void {
        const is_ar = detectLanguage(text);

        var words = std.ArrayList([]const u8).init(self.allocator);
        defer words.deinit();

        var it = std.mem.tokenizeAny(u8, text, " \t\n\r.,;:!?'\"()[]{}");
        while (it.next()) |word| {
            try words.append(word);
        }

        if (words.items.len < 3) return;

        const bigrams = if (is_ar) &self.ar_bigrams else &self.en_bigrams;
        const trigrams = if (is_ar) &self.ar_trigrams else &self.en_trigrams;
        const unigrams = if (is_ar) &self.ar_unigrams else &self.en_unigrams;

        // unigrams
        for (words.items) |word| {
            const owned = try self.string_arena.allocator().dupe(u8, word);
            try unigrams.append(owned);
        }

        // bigrams
        var i: usize = 0;
        while (i + 1 < words.items.len) : (i += 1) {
            const key = try self.string_arena.allocator().dupe(u8, words.items[i]);
            const next_word = try self.string_arena.allocator().dupe(u8, words.items[i + 1]);

            const entry = try bigrams.getOrPut(key);
            if (!entry.found_existing) {
                entry.value_ptr.* = std.ArrayList([]u8).init(self.allocator);
            }
            try entry.value_ptr.*.append(next_word);
        }

        // trigrams
        i = 0;
        while (i + 2 < words.items.len) : (i += 1) {
            const key = try std.fmt.allocPrint(self.string_arena.allocator(), "{s} {s}", .{ words.items[i], words.items[i + 1] });
            const next_word = try self.string_arena.allocator().dupe(u8, words.items[i + 2]);

            const entry = try trigrams.getOrPut(key);
            if (!entry.found_existing) {
                entry.value_ptr.* = std.ArrayList([]u8).init(self.allocator);
            }
            try entry.value_ptr.*.append(next_word);
        }

        self.trained = true;
    }

    /// توليد نص - يفصل العربية عن الإنجليزية تماماً
    pub fn generate(self: *NGramModel, allocator: std.mem.Allocator, prompt: []const u8, max_words: usize) ![]u8 {
        if (!self.trained) return allocator.dupe(u8, "");

        const is_ar = detectLanguage(prompt);
        const bigrams = if (is_ar) &self.ar_bigrams else &self.en_bigrams;
        const trigrams = if (is_ar) &self.ar_trigrams else &self.en_trigrams;
        const unigrams = if (is_ar) &self.ar_unigrams else &self.en_unigrams;

        if (unigrams.items.len == 0) return allocator.dupe(u8, "");

        var result = std.ArrayList(u8).init(allocator);
        defer result.deinit();

        // تقسيم الـ prompt
        var prompt_words = std.ArrayList([]const u8).init(allocator);
        defer prompt_words.deinit();

        var it = std.mem.tokenizeAny(u8, prompt, " \t\n\r.,;:!?'\"()[]{}");
        while (it.next()) |word| {
            try prompt_words.append(word);
        }

        // إذا لم توجد كلمات في الـ prompt، لا تولد
        if (prompt_words.items.len == 0) return allocator.dupe(u8, "");

        // فقط آخر كلمتين من نفس لغة الـ prompt
        var prev_word: ?[]const u8 = null;
        var prev_prev_word: ?[]const u8 = null;

        // البحث عن آخر كلمتين بنفس اللغة
        var pi: usize = prompt_words.items.len;
        while (pi > 0) {
            pi -= 1;
            const w = prompt_words.items[pi];
            if (detectLanguage(w) == is_ar) {
                if (prev_word == null) {
                    prev_word = w;
                } else if (prev_prev_word == null) {
                    prev_prev_word = w;
                    break;
                }
            } else {
                break; // لغة مختلفة - توقف
            }
        }

        var rng = std.Random.DefaultPrng.init(@bitCast(std.time.timestamp()));
        var random = rng.random();

        // التوليد
        var word_count: usize = 0;
        var consecutive_fallback: usize = 0;

        while (word_count < max_words) : (word_count += 1) {
            var next_word: ?[]const u8 = null;

            // trigram
            if (prev_prev_word != null and prev_word != null) {
                const key = try std.fmt.allocPrint(allocator, "{s} {s}", .{ prev_prev_word.?, prev_word.? });
                defer allocator.free(key);
                if (trigrams.get(key)) |list| {
                    if (list.items.len > 0) {
                        const idx = random.uintLessThan(usize, list.items.len);
                        next_word = list.items[idx];
                    }
                }
            }

            // bigram
            if (next_word == null and prev_word != null) {
                if (bigrams.get(prev_word.?)) |list| {
                    if (list.items.len > 0) {
                        const idx = random.uintLessThan(usize, list.items.len);
                        next_word = list.items[idx];
                        consecutive_fallback = 0;
                    }
                }
            }

            // إذا فشل التنبؤ مرتين متتاليتين، توقف
            if (next_word == null) {
                consecutive_fallback += 1;
                if (consecutive_fallback >= 2) break;

                // fallback: كلمة عشوائية بنفس اللغة
                const idx = random.uintLessThan(usize, unigrams.items.len);
                next_word = unigrams.items[idx];
            } else {
                consecutive_fallback = 0;
            }

            // التحقق من أن الكلمة بنفس اللغة
            if (detectLanguage(next_word.?) != is_ar) {
                // تخطي الكلمة المخالفة
                consecutive_fallback += 1;
                if (consecutive_fallback >= 2) break;
                continue;
            }

            try result.append(' ');
            try result.appendSlice(next_word.?);

            prev_prev_word = prev_word;
            prev_word = next_word;
        }

        return result.toOwnedSlice();
    }

    pub fn trainOnBuiltinCorpus(self: *NGramModel) !void {
        // corpus عربي خالص
        const ar_corpus = [_][]const u8{
            "مرحبا بك في Super Agent وكيل ذكاء اصطناعي خارق",
            "أعمل على أجهزة منخفضة الإمكانيات بدون كارت شاشة",
            "أتعلم من الإنترنت تلقائيا وأحفظ المعلومات المهمة",
            "Zig لغة برمجة سريعة وآمنة ومناسبة للأجهزة المنخفضة",
            "الذكاء الاصطناعي محاكاة ذكاء البشر في الآلات",
            "التعلم الآلي فرع من الذكاء الاصطناعي يتعلم من البيانات",
            "الشبكات العصبية محاكاة للدماغ البشري طبقات مترابطة",
            "الترانسفورمر أحدث ثورة في معالجة اللغة الطبيعية",
            "البرمجة كتابة تعليمات للكمبيوتر لحل المشاكل",
            "الخوارزمية خطوات لحل مشكلة معينة بشكل منظم",
            "قاعدة البيانات تخزن المعلومات بشكل آمن ومنظم",
            "الإنترنت مصدر هائل للمعرفة والتعلم",
            "الرياضيات علم الأرقام والأنماط والمعادلات",
            "الفيزياء علم المادة والطاقة والقوى الطبيعية",
            "الكيمياء علم المادة وتحولاتها وخصائصها",
            "الأحياء علم الكائنات الحية ووظائفها",
            "التاريخ دراسة الماضي البشري وحضاراته",
            "الجغرافيا علم الأرض وتضاريسها وسكانها",
            "الأدب فن الكلمة المكتوبة والإبداع اللغوي",
            "الشعر فن التعبير بالكلمة الموزونة المقفاة",
            "الموسيقى فن تنظيم الأصوات والإيقاعات",
            "الفلسفة حب الحكمة والتفكير العميق المنظم",
            "الأمن السيبراني يحمي الأنظمة من الاختراقات",
            "الحوسبة السحابية توفر موارد مرنة حسب الطلب",
            "البلوكشين سجل موزع لا مركزي للمعاملات",
            "الروبوتات تدمج البرمجة مع الميكانيكا",
            "يمكنك سؤالي عن أي موضوع وأحاول الإجابة",
            "الترجمة متاحة بين العربية والإنجليزية والفرنسية",
            "الحاسبة تدعم الجمع والطرح والضرب والقسمة",
            "يمكنني قراءة وكتابة الملفات في مجلد العمل",
        };

        // corpus إنجليزي خالص
        const en_corpus = [_][]const u8{
            "Super Agent is a powerful AI built in Zig",
            "Artificial intelligence simulates human intelligence in machines",
            "Machine learning is a branch of AI that learns from data",
            "Neural networks simulate the human brain with connected layers",
            "Transformers revolutionized natural language processing",
            "Zig is a fast and safe systems programming language",
            "Programming is writing instructions for computers",
            "Algorithms are organized steps to solve problems",
            "Databases store information in an organized way",
            "The internet is a vast source of knowledge",
            "Mathematics is the science of numbers and patterns",
            "Physics is the science of matter and energy",
            "Chemistry is the science of matter and transformations",
            "Biology is the science of living organisms",
            "History is the study of the human past",
            "Geography is the science of Earth and inhabitants",
            "Literature is the art of written words",
            "Poetry is the art of rhythmic expression",
            "Music is the art of organizing sounds",
            "Philosophy is the love of wisdom",
            "Cybersecurity protects systems from attacks",
            "Cloud computing provides flexible resources",
            "Blockchain is a distributed decentralized ledger",
            "Robotics combines programming with mechanics",
        };

        for (ar_corpus) |text| try self.train(text);
        for (en_corpus) |text| try self.train(text);
    }
};
