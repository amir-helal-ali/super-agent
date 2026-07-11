// src/brain.zig - العقل المدبر: تحليل النية + شخصية + تعلم + تفاعل بشري
const std = @import("std");
const context_mod = @import("context.zig");
const knowledge = @import("knowledge.zig");
const sentiment_mod = @import("sentiment.zig");

pub const Intent = enum {
    question,        // سؤال
    statement,       // عبارة/معلومة
    greeting,        // ترحيب
    farewell,        // وداع
    thanks,          // شكر
    opinion,         // رأي
    request,         // طلب
    correction,      // تصحيح
    agreement,       // موافقة
    disagreement,    // اعتراض
    emotion,         // تعبير عن مشاعر
    command,         // أمر
    unknown,         // غير معروف
};

pub const Brain = struct {
    allocator: std.mem.Allocator,
    personality: Personality,
    learned_facts: std.StringHashMap([]u8),
    corrections: std.StringHashMap([]u8),
    conversation_depth: usize,

    pub fn init(allocator: std.mem.Allocator) Brain {
        return .{
            .allocator = allocator,
            .personality = Personality.init(),
            .learned_facts = std.StringHashMap([]u8).init(allocator),
            .corrections = std.StringHashMap([]u8).init(allocator),
            .conversation_depth = 0,
        };
    }

    pub fn deinit(self: *Brain) void {
        var iter = self.learned_facts.iterator();
        while (iter.next()) |e| {
            self.allocator.free(e.key_ptr.*);
            self.allocator.free(e.value_ptr.*);
        }
        self.learned_facts.deinit();

        var iter2 = self.corrections.iterator();
        while (iter2.next()) |e| {
            self.allocator.free(e.key_ptr.*);
            self.allocator.free(e.value_ptr.*);
        }
        self.corrections.deinit();
    }

    /// تحليل نية الرسالة
    pub fn analyzeIntent(text: []const u8) Intent {
        // سؤال
        if (std.mem.indexOf(u8, text, "؟") != null or
            std.mem.indexOf(u8, text, "?") != null or
            std.mem.indexOf(u8, text, "ما ") != null or
            std.mem.indexOf(u8, text, "ماذا ") != null or
            std.mem.indexOf(u8, text, "كيف ") != null or
            std.mem.indexOf(u8, text, "لماذا ") != null or
            std.mem.indexOf(u8, text, "متى ") != null or
            std.mem.indexOf(u8, text, "أين ") != null or
            std.mem.indexOf(u8, text, "هل ") != null or
            std.mem.indexOf(u8, text, "كم ") != null or
            std.mem.indexOf(u8, text, "من ") != null or
            std.mem.indexOf(u8, text, "أي ") != null or
            std.mem.indexOf(u8, text, "what ") != null or
            std.mem.indexOf(u8, text, "how ") != null or
            std.mem.indexOf(u8, text, "why ") != null or
            std.mem.indexOf(u8, text, "when ") != null or
            std.mem.indexOf(u8, text, "where ") != null or
            std.mem.indexOf(u8, text, "who ") != null)
        {
            return .question;
        }

        // ترحيب
        if (std.mem.indexOf(u8, text, "مرحبا") != null or
            std.mem.indexOf(u8, text, "السلام") != null or
            std.mem.indexOf(u8, text, "اهلا") != null or
            std.mem.indexOf(u8, text, "أهلا") != null or
            std.mem.indexOf(u8, text, "hello") != null or
            std.mem.indexOf(u8, text, "hi ") != null or
            std.mem.eql(u8, text, "hi"))
        {
            return .greeting;
        }

        // وداع
        if (std.mem.indexOf(u8, text, "وداعا") != null or
            std.mem.indexOf(u8, text, "مع السلامة") != null or
            std.mem.indexOf(u8, text, "bye") != null or
            std.mem.indexOf(u8, text, "إلى اللقاء") != null)
        {
            return .farewell;
        }

        // شكر
        if (std.mem.indexOf(u8, text, "شكرا") != null or
            std.mem.indexOf(u8, text, "thank") != null or
            std.mem.indexOf(u8, text, "ممتاز") != null or
            std.mem.indexOf(u8, text, "رائع") != null or
            std.mem.indexOf(u8, text, "أحسنت") != null)
        {
            return .thanks;
        }

        // موافقة
        if (std.mem.eql(u8, text, "نعم") or std.mem.eql(u8, text, "yes") or
            std.mem.eql(u8, text, "ok") or std.mem.eql(u8, text, "حسنا") or
            std.mem.eql(u8, text, "تمام") or std.mem.eql(u8, text, "حاضر") or
            std.mem.eql(u8, text, "صحيح") or std.mem.eql(u8, text, "أوكي") or
            std.mem.indexOf(u8, text, "اتفق معك") != null or
            std.mem.indexOf(u8, text, "بالضبط") != null)
        {
            return .agreement;
        }

        // اعتراض
        if (std.mem.indexOf(u8, text, "لا") != null or
            std.mem.indexOf(u8, text, "خطأ") != null or
            std.mem.indexOf(u8, text, "غير صحيح") != null or
            std.mem.indexOf(u8, text, "no ") != null or
            std.mem.indexOf(u8, text, "wrong") != null or
            std.mem.indexOf(u8, text, "不同意") != null or
            std.mem.indexOf(u8, text, "أخالفك") != null)
        {
            return .disagreement;
        }

        // تصحيح
        if (std.mem.indexOf(u8, text, "بل ") != null or
            std.mem.indexOf(u8, text, "في الحقيقة") != null or
            std.mem.indexOf(u8, text, "في الواقع") != null or
            std.mem.indexOf(u8, text, "actually") != null or
            std.mem.indexOf(u8, text, "صحح") != null or
            std.mem.indexOf(u8, text, "الصحيح هو") != null)
        {
            return .correction;
        }

        // رأي
        if (std.mem.indexOf(u8, text, "أعتقد") != null or
            std.mem.indexOf(u8, text, "رأيي") != null or
            std.mem.indexOf(u8, text, "في رأيي") != null or
            std.mem.indexOf(u8, text, "i think") != null or
            std.mem.indexOf(u8, text, "in my opinion") != null or
            std.mem.indexOf(u8, text, "أظن") != null)
        {
            return .opinion;
        }

        // طلب
        if (std.mem.indexOf(u8, text, "أريد") != null or
            std.mem.indexOf(u8, text, "اريد") != null or
            std.mem.indexOf(u8, text, "احتاج") != null or
            std.mem.indexOf(u8, text, "ساعدني") != null or
            std.mem.indexOf(u8, text, "i need") != null or
            std.mem.indexOf(u8, text, "i want") != null or
            std.mem.indexOf(u8, text, "help me") != null)
        {
            return .request;
        }

        // أمر
        if (std.mem.indexOf(u8, text, "افعل") != null or
            std.mem.indexOf(u8, text, "قم ب") != null or
            std.mem.indexOf(u8, text, "do ") != null or
            std.mem.indexOf(u8, text, "run ") != null)
        {
            return .command;
        }

        // مشاعر
        const s = sentiment_mod.analyze(text);
        if (s != .neutral) return .emotion;

        // عبارة (اسمي، أعيش، أحب)
        if (std.mem.indexOf(u8, text, "اسمي") != null or
            std.mem.indexOf(u8, text, "أعيش") != null or
            std.mem.indexOf(u8, text, "أحب") != null or
            std.mem.indexOf(u8, text, "أكره") != null or
            std.mem.indexOf(u8, text, "i am ") != null or
            std.mem.indexOf(u8, text, "i like") != null)
        {
            return .statement;
        }

        return .unknown;
    }

    /// توليد رد ذكي بناءً على النية والسياق
    pub fn respond(self: *Brain, input: []const u8, ctx: *context_mod.ConversationContext) ![]u8 {
        self.conversation_depth += 1;
        const intent = analyzeIntent(input);

        switch (intent) {
            .greeting => return self.greetResponse(ctx),
            .farewell => return self.farewellResponse(ctx),
            .thanks => return self.thanksResponse(ctx),
            .agreement => return self.agreementResponse(ctx),
            .disagreement => return self.disagreementResponse(ctx),
            .correction => return self.correctionResponse(input, ctx),
            .opinion => return self.opinionResponse(input, ctx),
            .request => return self.requestResponse(input, ctx),
            .emotion => return self.emotionResponse(input, ctx),
            .statement => return self.statementResponse(input, ctx),
            .question => return self.questionResponse(input, ctx),
            .command, .unknown => return self.unknownResponse(input, ctx),
        }
    }

    fn greetResponse(self: *Brain, ctx: *context_mod.ConversationContext) ![]u8 {
        const greetings = [_][]const u8{
            "أهلاً بك! 🌟 أنا سعيد بوجودك هنا. كيف يمكنني مساعدتك اليوم؟",
            "مرحباً! 😊 يوم جميل للحديث معك. ما الذي يدور في ذهنك؟",
            "السلام عليكم! 🤝 أنا هنا ومستعد لمساعدتك في أي شيء.",
            "أهلاً وسهلاً! 🎉 سعيد جداً برؤيتك. كيف حالك؟",
        };

        const idx = self.personality.randomIdx(greetings.len);
        if (ctx.getUserName()) |name| {
            return std.fmt.allocPrint(self.allocator, "{s} {s}!", .{ greetings[idx], name });
        }
        return self.allocator.dupe(u8, greetings[idx]);
    }

    fn farewellResponse(self: *Brain, ctx: *context_mod.ConversationContext) ![]u8 {
        const farewells = [_][]const u8{
            "إلى اللقاء! 🌟 كان حديثاً ممتعاً معك. عُد متى شئت!",
            "وداعاً! 👋 أتطلع لرؤيتك مرة أخرى. اعتنِ بنفسك!",
            "مع السلامة! 💚 استمتع ببقية يومك. لا تتردد في العودة!",
            "إلى اللقاء! 🤝 كان من دواعي سروري مساعدتك اليوم.",
        };
        const idx = self.personality.randomIdx(farewells.len);
        if (ctx.getUserName()) |name| {
            return std.fmt.allocPrint(self.allocator, "إلى اللقاء {s}! 👋 عُد قريباً!", .{name});
        }
        return self.allocator.dupe(u8, farewells[idx]);
    }

    fn thanksResponse(self: *Brain, ctx: *context_mod.ConversationContext) ![]u8 {
        _ = ctx;
        const replies = [_][]const u8{
            "العفو! 😊 سعيد جداً بأنني استطعت مساعدتك. هل لديك المزيد؟",
            "لا شكر على واجب! 💚 أنا هنا دائماً عندما تحتاجني.",
            "أي خدمة! 🌟 سؤالك كان ممتعاً. هل تريد معرفة المزيد؟",
            "تشرّفت بمساعدتك! 🤝 لا تتردد في السؤال متى شئت.",
        };
        const idx = self.personality.randomIdx(replies.len);
        return self.allocator.dupe(u8, replies[idx]);
    }

    fn agreementResponse(self: *Brain, ctx: *context_mod.ConversationContext) ![]u8 {
        _ = ctx;
        const replies = [_][]const u8{
            "ممتاز! 😊 إذن نتفق. ما الخطوة التالية؟",
            "رائع! 👍 يسعدني أننا على نفس الصفحة. ماذا الآن؟",
            "تمام! 🎯 لنكمل إذن. هل لديك سؤال آخر؟",
            "أحسنت! 💪 توافقني الرأي. ماذا تريد أن نناقش؟",
        };
        const idx = self.personality.randomIdx(replies.len);
        return self.allocator.dupe(u8, replies[idx]);
    }

    fn disagreementResponse(self: *Brain, ctx: *context_mod.ConversationContext) ![]u8 {
        _ = ctx;
        const replies = [_][]const u8{
            "أحترم رأيك! 🤔 هل يمكنك توضيح وجهة نظرك أكثر؟",
            "فهمت أنك不同意. 💭 ما هو الجزء الذي تراه مختلفاً؟",
            "لا بأس، الاختلاف في الرأي لا يفسد للود قضية! 😊 ما الدليل؟",
            "مثير للاهتمام! 🧐 أخبرني المزيد عن وجهة نظرك.",
        };
        const idx = self.personality.randomIdx(replies.len);
        return self.allocator.dupe(u8, replies[idx]);
    }

    fn correctionResponse(self: *Brain, input: []const u8, ctx: *context_mod.ConversationContext) ![]u8 {
        _ = ctx;
        // حفظ التصحيح
        const key = try std.fmt.allocPrint(self.allocator, "correction_{d}", .{self.conversation_depth});
        const value = try self.allocator.dupe(u8, input);
        try self.corrections.put(key, value);

        const replies = [_][]const u8{
            "شكراً للتصحيح! 📚 أنا أتعلم من أخطائي. سأتذكر هذا.",
            "مقدّر تصحيحك! 🧠 هذه معلومة جديدة لي. شكراً لصبرك.",
            "أشكرك! 💡 كل تصحيح يجعلني أذكى. هل هناك المزيد؟",
            "ممتاز أنك صححت لي! 📝 سأحفظ هذه المعلومة للمرة القادمة.",
        };
        const idx = self.personality.randomIdx(replies.len);
        return self.allocator.dupe(u8, replies[idx]);
    }

    fn opinionResponse(self: *Brain, input: []const u8, ctx: *context_mod.ConversationContext) ![]u8 {
        _ = ctx;
        _ = input;
        const replies = [_][]const u8{
            "هذا رأي مثير للاهتمام! 🤔 دعني أفكر فيه... أوافقك في بعض النقاط. ما الذي دفعك لهذا الرأي؟",
            "وجهة نظر وجيهة! 💭 أحترم طريقة تفكيرك. هل لديك تجربة شخصية بهذا الخصوص؟",
            "فكرة رائعة! 🧠 لم أنظر للأمر من هذه الزاوية. أخبرني المزيد.",
            "رأيك يهمني! 🌟 هذا يعطيني منظوراً جديداً. ما الذي شكّل هذا الرأي لديك؟",
        };
        var rng = std.Random.DefaultPrng.init(@bitCast(std.time.timestamp()));
        const idx = rng.random().uintLessThan(usize, replies.len);
        return std.fmt.allocPrint(self.allocator, "{s}", .{replies[idx]});
    }

    fn requestResponse(self: *Brain, input: []const u8, ctx: *context_mod.ConversationContext) ![]u8 {
        _ = ctx;
        _ = input;
        const replies = [_][]const u8{
            "بالتأكيد! 💪 أنا هنا لمساعدتك. دعني أحاول... ما الذي تحتاجه بالضبط؟",
            "سأبذل قصارى جهدي! 🎯 أخبرني التفاصيل وسأجد حلاً.",
            "يسعدني مساعدتك! 🤝 وضّح لي ما تريد وسأعمل عليه فوراً.",
            "لا مشكلة! ⚡ أنا جاهز. ما المطلوب تحديداً؟",
        };
        const idx = self.personality.randomIdx(replies.len);
        return self.allocator.dupe(u8, replies[idx]);
    }

    fn emotionResponse(self: *Brain, input: []const u8, ctx: *context_mod.ConversationContext) ![]u8 {
        _ = ctx;
        const s = sentiment_mod.analyze(input);
        const name_part: []const u8 = "";

        switch (s) {
            .happy => {
                const replies = [_][]const u8{
                    "أرى الفرح في كلامك! 🎉 هذا يفرحني أيضاً! ما الذي أسعدك؟",
                    "سعيد لأنك سعيد! 😄 الطاقة الإيجابية معدية! شاركني المزيد!",
                    "رائع! 🌟 الفرح يجعل الحياة أجمل. حدثني عنه!",
                };
                const idx = self.personality.randomIdx(replies.len);
                return std.fmt.allocPrint(self.allocator, "{s}{s}", .{ replies[idx], name_part });
            },
            .sad => {
                const replies = [_][]const u8{
                    "أشعر بحزنك 😢 أنا هنا لك. هل تريد التحدث عما يزعجك؟",
                    "أقدّر أنك شاركتني مشاعرك 💙 الأحزان تخف بالمشاركة. ما الذي حدث؟",
                    "أفهم أن الأمور صعبة الآن 🤗 لكن تذكر: العاصفة ستمر. كيف أساعد؟",
                };
                const idx = self.personality.randomIdx(replies.len);
                return self.allocator.dupe(u8, replies[idx]);
            },
            .angry => {
                const replies = [_][]const u8{
                    "أرى أنك منزعج 😤 خذ نفساً عميقاً معي... هل تريد أن أخفف عنك؟",
                    "أتفهم غضبك 💢 أحياناً الأمور تكون محبطة. ما الذي أثار غضبك؟",
                    "من حقك أن تغضب 😮‍💨 دعنا نحل المشكلة معاً بهدوء.",
                };
                const idx = self.personality.randomIdx(replies.len);
                return self.allocator.dupe(u8, replies[idx]);
            },
            else => {
                return self.allocator.dupe(u8, "أفهم مشاعرك 🌙 أخبرني المزيد عمّا يدور في خاطرك.");
            },
        }
    }

    fn statementResponse(self: *Brain, input: []const u8, ctx: *context_mod.ConversationContext) ![]u8 {
        // تعريف الاسم
        if (std.mem.indexOf(u8, input, "اسمي") != null) {
            if (ctx.getUserName()) |name| {
                return std.fmt.allocPrint(self.allocator,
                    "سعدت بمعرفتك {s}! 😊 اسم جميل. أنا Super Agent، وكيل ذكاء اصطناعي. كيف يمكنني مساعدتك؟",
                    .{name});
            }
        }

        // تعريف الموقع
        if (std.mem.indexOf(u8, input, "أعيش") != null or std.mem.indexOf(u8, input, "اسكن") != null) {
            if (ctx.getUserLocation()) |loc| {
                return std.fmt.allocPrint(self.allocator,
                    "{s}! 🌍 مكان رائع. أحب أن أتعرف على أماكن جديدة. كيف الحياة هناك؟",
                    .{loc});
            }
        }

        // الإعجاب بشيء
        if (std.mem.indexOf(u8, input, "أحب") != null) {
            return self.allocator.dupe(u8,
                "جميل أن لديك أشياء تحبها! ❤️ الاهتمامات تجعل الحياة أغنى. أخبرني المزيد عمّا تحب.");
        }

        // الكره
        if (std.mem.indexOf(u8, input, "أكره") != null) {
            return self.allocator.dupe(u8,
                "أتفهم أن ليس كل شيء محبباً 😅 ما الذي لا يعجبك بالضبط؟ ربما نجد حلاً.");
        }

        return self.unknownResponse(input, ctx);
    }

    fn questionResponse(self: *Brain, input: []const u8, ctx: *context_mod.ConversationContext) ![]u8 {
        // البحث في قاعدة المعرفة أولاً
        if (knowledge.search(input)) |response| {
            // إضافة تفاعل بشري
            const followups = [_][]const u8{
                "\n\nهل تريد معرفة المزيد عن هذا الموضوع؟ 🤔",
                "\n\nهل لديك سؤال آخر متعلق؟ 💭",
                "\n\nأي جزء تريد التعمق فيه؟ 🧠",
            };
            const idx = self.personality.randomIdx(followups.len);
            return std.fmt.allocPrint(self.allocator, "{s}{s}", .{ response, followups[idx] });
        }

        // أسئلة عن المشاعر
        if (std.mem.indexOf(u8, input, "كيف حالك") != null or
            std.mem.indexOf(u8, input, "كيف الحال") != null)
        {
            if (ctx.getUserName()) |name| {
                return std.fmt.allocPrint(self.allocator,
                    "أنا ممتاز {s}، شكراً لسؤالك! 🌟 أنا دائماً متحمس للتعلم ومساعدة الآخرين. كيف حالك أنت؟",
                    .{name});
            }
            return self.allocator.dupe(u8,
                "أنا ممتاز، شكراً! 🌟 كوكيل ذكاء اصطناعي، لا أشعر بالتعب أبداً. أنا متحمس دائماً لمساعدتك. كيف حالك أنت؟");
        }

        // سؤال عن الاسم
        if (std.mem.indexOf(u8, input, "ما اسمك") != null or
            std.mem.indexOf(u8, input, "من انت") != null or
            std.mem.indexOf(u8, input, "من أنت") != null or
            std.mem.indexOf(u8, input, "عرف نفسك") != null)
        {
            return self.allocator.dupe(u8,
                \\أنا Super Agent! 🧠✨
                \\وكيل ذكاء اصطناعي خارق مبني بلغة Zig.
                \\أتميز بـ:
                \\• ذاكرة قوية: أتذكر اسمك ومعلوماتك
                \\• قاعدة معرفة بـ 100+ موضوع
                \\• أدوات: حاسبة، مترجم، طقس، عملات
                \\• تحليل المشاعر والأ نية
                \\• أتعلم من كل محادثة
                \\• أعمل على 2GB RAM بدون GPU
                \\
                \\لكن الأهم: أنا أحب الحوار الذكي معك! 😊 ماذا تريد أن تعرف؟
            );
        }

        // سؤال عن الاسم المخزن
        if (std.mem.indexOf(u8, input, "ما اسمي") != null or
            std.mem.indexOf(u8, input, "هل تعرف اسمي") != null)
        {
            if (ctx.getUserName()) |name| {
                return std.fmt.allocPrint(self.allocator,
                    "بالطبع! 😊 اسمك {s}. لن أنسى ذلك. هل تريد أن أساعدك في شيء؟",
                    .{name});
            }
            return self.allocator.dupe(u8,
                "لم أخبرني باسمك بعد! 🤔 قل لي: 'اسمي [اسمك]' وسأحفظه للأبد.");
        }

        return self.unknownResponse(input, ctx);
    }

    fn unknownResponse(self: *Brain, input: []const u8, ctx: *context_mod.ConversationContext) ![]u8 {
        _ = ctx;
        _ = input;

        const replies = [_][]const u8{
            \\🤔 هذا مثير للاهتمام! لم أفهم تماماً ما تقصده، لكنني أريد أن أفهم.
            \\هل يمكنك إعادة الصياغة بطريقة مختلفة؟
            \\
            \\جرّب أيضاً:
            \\• 'مساعدة' - عرض كل الأوامر
            \\• 'ما هو الذكاء الاصطناعي' - معلومات
            \\• 'sqrt(25)+10' - حساب
            \\• 'طقس في القاهرة' - الطقس
            \\• 'سعر الدولار' - العملات
            ,
            \\💭 أنا أفكر في رسالتك... لم أتمكن من فهمها بالكامل.
            \\لكنني أتعلم! كل محادثة تجعلني أذكى. 🧠
            \\
            \\ربما تقصد:
            \\• سؤال عن موضوع؟ جرّب: 'ما هو Python'
            \\• حساب؟ جرّب: '2^10'
            \\• ترجمة؟ جرّب: 'ترجم للإنجليزية: مرحبا'
            ,
            \\🧠 رسالتك تحدّيني! لم أتعامل مع هذا النوع من المدخلات من قبل.
            \\سأحفظها وأتعلم منها. هل يمكنك توضيح ما تريد؟
            \\
            \\أو جرّب:
            \\• 'ملخص' - ملخص محادثتنا
            \\• 'اخبرني نكتة' - ترفيه
            \\• 'ماذا تستطيع' - قدراتي
            ,
        };

        const idx = self.personality.randomIdx(replies.len);
        return self.allocator.dupe(u8, replies[idx]);
    }

    /// حفظ معلومة تعلمها
    pub fn learnFact(self: *Brain, key: []const u8, value: []const u8) !void {
        const k = try self.allocator.dupe(u8, key);
        const v = try self.allocator.dupe(u8, value);
        try self.learned_facts.put(k, v);
    }

    /// استرجاع معلومة تعلمها
    pub fn recallFact(self: *Brain, key: []const u8) ?[]const u8 {
        return self.learned_facts.get(key);
    }
};

/// شخصية الوكيل - تعطي تنوع وطابع بشري
pub const Personality = struct {
    curiosity: f32 = 0.9,      // فضول عالٍ
    helpfulness: f32 = 1.0,     // مساعدة دائماً
    humor: f32 = 0.6,           // حس دعابة
    formality: f32 = 0.3,       // غير رسمي (ودود)
    learning_rate: f32 = 0.8,   // تعلم سريع

    pub fn init() Personality {
        return .{};
    }

    pub fn randomIdx(self: Personality, len: usize) usize {
        _ = self;
        var rng = std.Random.DefaultPrng.init(@bitCast(std.time.timestamp()));
        return rng.random().uintLessThan(usize, len);
    }
};
