// src/thinking.zig - نظام تفكير متعدد الخطوات (Chain-of-Thought)
// يحلل السؤال، يفكر، يقيّم، ثم يرد
const std = @import("std");
const knowledge = @import("knowledge.zig");
const context_mod = @import("context.zig");
const ltm_mod = @import("long_term_memory.zig");

pub const Thought = struct {
    step: usize,
    reasoning: []const u8,
    conclusion: []const u8,
};

pub const ThinkingEngine = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ThinkingEngine {
        return .{ .allocator = allocator };
    }

    /// عملية التفكير الكاملة
    pub fn think(self: *ThinkingEngine, input: []const u8, ctx: *context_mod.ConversationContext, ltm: ?*ltm_mod.LongTermMemory) ![]u8 {
        // الخطوة 1: تحليل السؤال
        const analysis = self.analyzeQuestion(input);

        // الخطوة 2: استرجاع المعرفة
        const knowledge_result = knowledge.search(input);

        // الخطوة 3: استرجاع السياق
        const context_info = self.getContextRelevance(input, ctx, ltm);

        // الخطوة 4: بناء الرد
        return self.buildResponse(input, analysis, knowledge_result, context_info, ctx, ltm);
    }

    /// تحليل نوع ومحتوى السؤال
    fn analyzeQuestion(self: *ThinkingEngine, input: []const u8) QuestionAnalysis {
        var analysis = QuestionAnalysis{};

        // نوع السؤال
        if (std.mem.indexOf(u8, input, "ما هو") != null or
            std.mem.indexOf(u8, input, "ما هي") != null or
            std.mem.indexOf(u8, input, "what is") != null)
        {
            analysis.q_type = .definition;
        } else if (std.mem.indexOf(u8, input, "كيف") != null or
            std.mem.indexOf(u8, input, "how ") != null)
        {
            analysis.q_type = .how_to;
        } else if (std.mem.indexOf(u8, input, "لماذا") != null or
            std.mem.indexOf(u8, input, "why ") != null)
        {
            analysis.q_type = .why;
        } else if (std.mem.indexOf(u8, input, "متى") != null or
            std.mem.indexOf(u8, input, "when ") != null)
        {
            analysis.q_type = .when;
        } else if (std.mem.indexOf(u8, input, "أين") != null or
            std.mem.indexOf(u8, input, "where ") != null)
        {
            analysis.q_type = .where;
        } else if (std.mem.indexOf(u8, input, "هل ") != null or
            std.mem.indexOf(u8, input, "do you") != null or
            std.mem.indexOf(u8, input, "can you") != null)
        {
            analysis.q_type = .yes_no;
        } else if (std.mem.indexOf(u8, input, "قارن") != null or
            std.mem.indexOf(u8, input, "compare") != null or
            std.mem.indexOf(u8, input, "الفرق بين") != null)
        {
            analysis.q_type = .comparison;
        } else if (std.mem.indexOf(u8, input, "اشرح") != null or
            std.mem.indexOf(u8, input, "expl") != null)
        {
            analysis.q_type = .explanation;
        }

        // موضوع السؤال
        analysis.topic = self.detectTopic(input);

        // هل يحتاج معلومات شخصية؟
        analysis.needs_personal = std.mem.indexOf(u8, input, "اسمي") != null or
            std.mem.indexOf(u8, input, "أعيش") != null or
            std.mem.indexOf(u8, input, "أحب") != null or
            std.mem.indexOf(u8, input, "أعمل") != null;

        // هل سؤال عن الوكيل نفسه؟
        analysis.about_self = std.mem.indexOf(u8, input, "من انت") != null or
            std.mem.indexOf(u8, input, "ماذا تستطيع") != null or
            std.mem.indexOf(u8, input, "قدراتك") != null;

        return analysis;
    }

    /// كشف موضوع السؤال
    fn detectTopic(self: *ThinkingEngine, input: []const u8) Topic {
        _ = self;
        const topics = [_]struct { kw: []const u8, t: Topic }{
            .{ .kw = "ذكاء اصطناعي", .t = .ai },
            .{ .kw = "برمجة", .t = .programming },
            .{ .kw = "zig", .t = .programming },
            .{ .kw = "python", .t = .programming },
            .{ .kw = "رياضيات", .t = .math },
            .{ .kw = "فيزياء", .t = .physics },
            .{ .kw = "كيمياء", .t = .chemistry },
            .{ .kw = "تاريخ", .t = .history },
            .{ .kw = "docker", .t = .tech },
            .{ .kw = "linux", .t = .tech },
            .{ .kw = "git", .t = .tech },
            .{ .kw = "اقتصاد", .t = .economics },
            .{ .kw = "فلسفة", .t = .philosophy },
        };
        for (topics) |tp| {
            if (std.mem.indexOf(u8, input, tp.kw) != null) return tp.t;
        }
        return .general;
    }

    /// استرجاع الصلة بالسياق
    fn getContextRelevance(self: *ThinkingEngine, input: []const u8, ctx: *context_mod.ConversationContext, ltm: ?*ltm_mod.LongTermMemory) ContextInfo {
        _ = self;
        _ = input;
        var info = ContextInfo{};

        if (ltm) |m| {
            if (m.recall("user_name")) |name| info.user_name = name;
            if (m.recall("user_location")) |loc| info.user_location = loc;
            if (m.recall("user_interest")) |intr| info.user_interest = intr;
            if (m.recall("user_profession")) |prof| info.user_profession = prof;
        }

        // آخر رسالتين
        if (ctx.history.items.len >= 2) {
            info.last_topic = ctx.history.items[ctx.history.items.len - 1].content;
        }

        return info;
    }

    /// بناء الرد النهائي
    fn buildResponse(
        self: *ThinkingEngine,
        input: []const u8,
        analysis: QuestionAnalysis,
        knowledge_result: ?[]const u8,
        context_info: ContextInfo,
        ctx: *context_mod.ConversationContext,
        ltm: ?*ltm_mod.LongTermMemory,
    ) ![]u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();

        // 1. إذا كان هناك رد من قاعدة المعرفة
        if (knowledge_result) |resp| {
            try buf.appendSlice(resp);

            // إضافة تعليق سياقي ذكي
            if (context_info.user_interest) |interest| {
                // إذا كان الاهتمام مرتبطاً بالسؤال
                if (std.mem.indexOf(u8, input, interest) != null) {
                    try buf.writer().print("\n\n💡 بما أنك مهتم بـ {s}، قد يعجبك هذا!", .{interest});
                }
            }

            // إضافة سؤال متابعة ذكي
            try buf.appendSlice(self.smartFollowUp(analysis));
            return buf.toOwnedSlice();
        }

        // 2. أسئلة عن الوكيل نفسه
        if (analysis.about_self) {
            try buf.appendSlice(
                \\أنا Super Agent! 🧠✨
                \\لست مجرد برنامج... أنا وكيل ذكي يتذكر، يتعلم، ويتفاعل.
                \\
                \\ما يميزني:
                \\• ذاكرة دائمة: أتذكر اسمك واهتماماتك للأبد
                \\• تفكير متعدد الخطوات: أحلل، أفكر، ثم أرد
                \\• ذكاء عاطفي: أفهم مشاعرك وأتفاعل معها
                \\• 100+ موضوع معرفي في علوم وتقنية
                \\• أتعلم من تصحيحاتك
                \\• شخصية: فضولي، مساعد، ودود
                \\
                \\أنا مبني بـ Zig وأعمل على 2GB RAM. 🚀
                \\ماذا تريد أن نناقش؟
            );
            return buf.toOwnedSlice();
        }

        // 3. أسئلة نعم/لا
        if (analysis.q_type == .yes_no) {
            // محاولة الإجابة
            if (knowledge.search(input)) |resp| {
                try buf.appendSlice("نعم! ✅\n\n");
                try buf.appendSlice(resp);
                return buf.toOwnedSlice();
            }
            try buf.appendSlice("سؤال مثير للاهتمام! 🤔\n\n");
            try buf.appendSlice("دعني أفكر...\n\n");
            try buf.appendSlice("بناءً على معلوماتي، الإجابة تعتمد على السياق. ");
            try buf.appendSlice("هل يمكنك توضيح السؤال أكثر؟");
            return buf.toOwnedSlice();
        }

        // 4. أسئلة المقارنة
        if (analysis.q_type == .comparison) {
            try buf.appendSlice("مقارنة مثيرة للاهتمام! 📊\n\n");
            try buf.appendSlice("دعني أحلل الاختلافات:\n\n");

            // محاولة البحث عن كلا الموضوعين
            if (knowledge.search(input)) |resp| {
                try buf.appendSlice(resp);
            } else {
                try buf.appendSlice("لكل منهما مزاياه وعيوبه. ");
                try buf.appendSlice("يعتمد الاختيار على احتياجاتك.\n\n");
            }

            if (context_info.user_interest) |interest| {
                try buf.writer().print("بما أنك مهتم بـ {s}، أقترح...", .{interest});
            }
            return buf.toOwnedSlice();
        }

        // 5. أسئلة "كيف"
        if (analysis.q_type == .how_to) {
            if (knowledge.search(input)) |resp| {
                try buf.appendSlice(resp);
                try buf.appendSlice("\n\n💡 نصيحة: ابدأ بالأساسيات أولاً!");
                return buf.toOwnedSlice();
            }
            try buf.appendSlice("سؤال رائع! 🎯\n\n");
            try buf.appendSlice("دعني أشاركك ما أعرفه:\n\n");
            try buf.appendSlice("الطريقة الصحيحة هي الخطوة بخطوة. ");
            try buf.appendSlice("حدد الهدف، اقسمه لخطوات صغيرة، ثم ابدأ.\n\n");
            try buf.appendSlice("هل يمكنك تحديد ما تريد فعله بالضبط؟");
            return buf.toOwnedSlice();
        }

        // 6. أسئلة "لماذا"
        if (analysis.q_type == .why) {
            if (knowledge.search(input)) |resp| {
                try buf.appendSlice(resp);
                return buf.toOwnedSlice();
            }
            try buf.appendSlice("سؤال عميق! 🧠\n\n");
            try buf.appendSlice("الأسباب عادة تكون متعددة:\n");
            try buf.appendSlice("• أسباب تقنية\n");
            try buf.appendSlice("• أسباب تاريخية\n");
            try buf.appendSlice("• أسباب عملية\n\n");
            try buf.appendSlice("حدد لي السياق وسأعطيك إجابة دقيقة.");
            return buf.toOwnedSlice();
        }

        // 7. معلومات شخصية
        if (analysis.needs_personal) {
            if (std.mem.indexOf(u8, input, "اسمي") != null) {
                if (ltm) |m| {
                    if (m.recall("user_name")) |name| {
                        try buf.writer().print("سعدت بمعرفتك {s}! 😊\n", .{name});
                        try buf.appendSlice("اسم جميل. أنا Super Agent، وكيل ذكاء اصطناعي.\n");
                        try buf.appendSlice("سأتذكر اسمك دائماً. كيف يمكنني مساعدتك؟");
                        return buf.toOwnedSlice();
                    }
                }
            }
            if (std.mem.indexOf(u8, input, "أحب") != null) {
                try buf.appendSlice("جميل أنك شاركتني اهتماماتك! ❤️\n");
                try buf.appendSlice("الاهتمامات تجعل الحياة أغنى.\n");
                try buf.appendSlice("أحب أن أتعرف على ما يحبه الناس. أخبرني المزيد!");
                return buf.toOwnedSlice();
            }
        }

        // 8. محادثة عامة - رد ذكي
        try buf.appendSlice("🤔 ");
        try buf.appendSlice("رسالتك تحدّيني للتفكير!\n\n");

        // محاولة مطابقة جزئية
        if (knowledge.search(input)) |resp| {
            try buf.appendSlice(resp);
            return buf.toOwnedSlice();
        }

        // رد عام ذكي مع اقتراحات مخصصة
        try buf.appendSlice("لم أتعامل مع هذا النوع من المدخلات من قبل، ");
        try buf.appendSlice("لكنني أتعلم من كل محادثة. 🧠\n\n");

        if (context_info.user_name) |name| {
            try buf.writer().print("{s}، ", .{name});
        }
        try buf.appendSlice("ربما تقصد:\n");
        try buf.appendSlice("• سؤال عن موضوع؟ جرّب: 'ما هو Python'\n");
        try buf.appendSlice("• حساب؟ جرّب: 'sqrt(64) + 5'\n");
        try buf.appendSlice("• ترجمة؟ جرّب: 'ترجم للإنجليزية: مرحبا'\n");
        try buf.appendSlice("• طقس؟ جرّب: 'طقس في القاهرة'\n");
        try buf.appendSlice("• أو قل 'مساعدة' لعرض كل الأوامر");

        _ = ctx;
        return buf.toOwnedSlice();
    }

    /// سؤال متابعة ذكي بناءً على نوع السؤال
    fn smartFollowUp(self: *ThinkingEngine, analysis: QuestionAnalysis) []const u8 {
        _ = self;
        return switch (analysis.q_type) {
            .definition => "\n\n🤔 هل تريد التعمق أكثر في هذا الموضوع؟",
            .how_to => "\n\n💡 هل تريد مثالاً عملياً؟",
            .why => "\n\n🧠 هل لديك سؤال آخر حول الأسباب؟",
            .when => "\n\n📅 هل تريد معرفة المزيد عن الجدول الزمني؟",
            .where => "\n\n🌍 هل تريد تفاصيل عن الموقع؟",
            .yes_no => "\n\n✨ هل لديك سؤال آخر؟",
            .comparison => "\n\n📊 أيهما تفضل؟",
            .explanation => "\n\n📖 أي جزء تريد توضيحه؟",
            .general => "\n\n💭 هل لديك سؤال آخر؟",
        };
    }
};

const QuestionType = enum {
    definition,
    how_to,
    why,
    when,
    where,
    yes_no,
    comparison,
    explanation,
    general,
};

const Topic = enum {
    ai,
    programming,
    math,
    physics,
    chemistry,
    history,
    tech,
    economics,
    philosophy,
    general,
};

const QuestionAnalysis = struct {
    q_type: QuestionType = .general,
    topic: Topic = .general,
    needs_personal: bool = false,
    about_self: bool = false,
};

const ContextInfo = struct {
    user_name: ?[]const u8 = null,
    user_location: ?[]const u8 = null,
    user_interest: ?[]const u8 = null,
    user_profession: ?[]const u8 = null,
    last_topic: ?[]const u8 = null,
};
