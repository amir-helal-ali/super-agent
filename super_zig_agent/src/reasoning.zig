// src/reasoning.zig - محرك الاستدلال المنطقي والإبداعي
// تفكير نقدي، تحليل، تركيب، تقييم ذاتي
const std = @import("std");
const knowledge = @import("knowledge.zig");
const context_mod = @import("context.zig");
const ltm_mod = @import("long_term_memory.zig");

pub const ReasoningEngine = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ReasoningEngine {
        return .{ .allocator = allocator };
    }

    /// الاستدلال الكامل - يحلل، يربط، يقيّم، يبدع
    pub fn reason(self: *ReasoningEngine, input: []const u8, ctx: *context_mod.ConversationContext, ltm: ?*ltm_mod.LongTermMemory) ![]u8 {
        // 1. تحليل عميق
        const analysis = self.deepAnalyze(input);

        // 2. استرجاع معرفة متعددة المصادر
        const knowledge_resp = knowledge.search(input);

        // 3. استرجاع سياق المستخدم
        var user_context = UserContext{};
        if (ltm) |m| {
            user_context.name = m.recall("user_name");
            user_context.location = m.recall("user_location");
            user_context.interest = m.recall("user_interest");
            user_context.profession = m.recall("user_profession");
        }

        // 4. بناء رد متعدد الطبقات
        return self.synthesizeResponse(input, analysis, knowledge_resp, user_context, ctx);
    }

    /// تحليل عميق للرسالة
    fn deepAnalyze(self: *ReasoningEngine, input: []const u8) DeepAnalysis {
        var a = DeepAnalysis{};

        // كشف التعقيد
        a.complexity = self.assessComplexity(input);

        // كشف العاطفة
        a.emotion = self.detectEmotion(input);

        // كشف درجة الإلحاح
        a.urgency = self.assessUrgency(input);

        // كشف ما إذا كان سؤالاً مفتوحاً
        a.open_ended = self.isOpenEnded(input);

        // كشف ما إذا كان يحتاج إبداعاً
        a.needs_creativity = self.needsCreativity(input);

        // كشف ما إذا كان يحتاج كوداً
        a.needs_code = self.needsCode(input);

        // كشف اللهجة (رسمية/ودودة)
        a.formal = self.isFormal(input);

        return a;
    }

    fn assessComplexity(self: *ReasoningEngine, input: []const u8) Complexity {
        _ = self;
        var word_count: usize = 0;
        var it = std.mem.tokenizeAny(u8, input, " \t\n\r");
        while (it.next()) |_| word_count += 1;

        if (word_count <= 3) return .simple;
        if (word_count <= 8) return .moderate;
        if (word_count <= 15) return .complex;
        return .very_complex;
    }

    fn detectEmotion(self: *ReasoningEngine, input: []const u8) EmotionLevel {
        _ = self;
        const positive = [_][]const u8{ "سعيد", "فرح", "مبسوط", "رائع", "ممتاز", "أحب", "حب", "شكرا", "happy", "love", "great" };
        const negative = [_][]const u8{ "حزين", "غاضب", "محبط", "تعبان", "صعب", "مستحيل", "كره", "sad", "angry", "hate" };
        const curious = [_][]const u8{ "كيف", "لماذا", "ماذا", "أريد أن أفهم", "مثير", "interesting", "curious" };

        for (positive) |w| { if (std.mem.indexOf(u8, input, w) != null) return .positive; }
        for (negative) |w| { if (std.mem.indexOf(u8, input, w) != null) return .negative; }
        for (curious) |w| { if (std.mem.indexOf(u8, input, w) != null) return .curious; }
        return .neutral;
    }

    fn assessUrgency(self: *ReasoningEngine, input: []const u8) Urgency {
        _ = self;
        if (std.mem.indexOf(u8, input, "عاجل") != null or
            std.mem.indexOf(u8, input, "الآن") != null or
            std.mem.indexOf(u8, input, "فورا") != null or
            std.mem.indexOf(u8, input, "urgent") != null or
            std.mem.indexOf(u8, input, "now") != null)
        {
            return .high;
        }
        return .normal;
    }

    fn isOpenEnded(self: *ReasoningEngine, input: []const u8) bool {
        _ = self;
        return std.mem.indexOf(u8, input, "اقترح") != null or
            std.mem.indexOf(u8, input, "أعطني أفكار") != null or
            std.mem.indexOf(u8, input, "ما رأيك") != null or
            std.mem.indexOf(u8, input, "حدثني عن") != null or
            std.mem.indexOf(u8, input, "suggest") != null or
            std.mem.indexOf(u8, input, "tell me about") != null;
    }

    fn needsCreativity(self: *ReasoningEngine, input: []const u8) bool {
        _ = self;
        return std.mem.indexOf(u8, input, "اكتب") != null or
            std.mem.indexOf(u8, input, "ألف") != null or
            std.mem.indexOf(u8, input, "ابتكر") != null or
            std.mem.indexOf(u8, input, "خاطرة") != null or
            std.mem.indexOf(u8, input, "قصة") != null or
            std.mem.indexOf(u8, input, "شعر") != null or
            std.mem.indexOf(u8, input, "write") != null or
            std.mem.indexOf(u8, input, "create") != null;
    }

    fn needsCode(self: *ReasoningEngine, input: []const u8) bool {
        _ = self;
        return std.mem.indexOf(u8, input, "كود") != null or
            std.mem.indexOf(u8, input, "برنامج") != null or
            std.mem.indexOf(u8, input, "دالة") != null or
            std.mem.indexOf(u8, input, "function") != null or
            std.mem.indexOf(u8, input, "code") != null or
            std.mem.indexOf(u8, input, "algorithm") != null or
            std.mem.indexOf(u8, input, "class") != null;
    }

    fn isFormal(self: *ReasoningEngine, input: []const u8) bool {
        _ = self;
        return std.mem.indexOf(u8, input, "سيدي") != null or
            std.mem.indexOf(u8, input, "فضلاً") != null or
            std.mem.indexOf(u8, input, "لو سمحت") != null or
            std.mem.indexOf(u8, input, "أرجو") != null;
    }

    /// بناء رد متعدد الطبقات
    fn synthesizeResponse(
        self: *ReasoningEngine,
        input: []const u8,
        analysis: DeepAnalysis,
        knowledge_resp: ?[]const u8,
        user_ctx: UserContext,
        ctx: *context_mod.ConversationContext,
    ) ![]u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();

        // 1. إذا كان محتاجاً إبداعاً
        if (analysis.needs_creativity) {
            return self.creativeResponse(input, user_ctx);
        }

        // 2. إذا كان محتاجاً كوداً
        if (analysis.needs_code) {
            return self.codeResponse(input, user_ctx);
        }

        // 3. إذا كان سؤالاً مفتوحاً
        if (analysis.open_ended) {
            return self.openEndedResponse(input, knowledge_resp, user_ctx);
        }

        // 4. إذا كان هناك معرفة
        if (knowledge_resp) |resp| {
            try buf.appendSlice(resp);

            // تخصيص بناءً على المستخدم
            if (user_ctx.interest) |interest| {
                if (std.mem.indexOf(u8, input, interest) != null) {
                    try buf.writer().print("\n\n💡 بما أنك مهتم بـ {s}، فهذا مرتبط مباشرة باهتماماتك!", .{interest});
                }
            }

            // سؤال متابعة ذكي
            try buf.appendSlice(self.intelligentFollowUp(analysis, input));
            return buf.toOwnedSlice();
        }

        // 5. رد مخصص حسب العاطفة
        switch (analysis.emotion) {
            .positive => {
                try buf.appendSlice("أحسنت! 🌟 سؤالك يُظهر تفكيراً إيجابياً.\n\n");
            },
            .negative => {
                if (user_ctx.name) |name| {
                    try buf.writer().print("{s}، أفهم أن الأمر قد يكون محبطاً. 💙\n\n", .{name});
                } else {
                    try buf.appendSlice("أفهم شعورك. 💙\n\n");
                }
            },
            .curious => {
                try buf.appendSlice("سؤال رائع يدل على فضولك! 🧠\n\n");
            },
            .neutral => {},
        }

        // 6. محاولة الإجابة
        try buf.appendSlice("دعني أفكر في هذا...\n\n");

        // ربط بآخر محادثة
        if (ctx.history.items.len >= 2) {
            const last_msg = ctx.history.items[ctx.history.items.len - 2];
            if (std.mem.indexOf(u8, last_msg.content, "ما ") != null or
                std.mem.indexOf(u8, last_msg.content, "كيف ") != null)
            {
                try buf.appendSlice("بناءً على ما ناقشناه سابقاً، ");
            }
        }

        // اقتراحات ذكية
        try buf.appendSlice("هذا موضوع مثير للاهتمام. ");
        try buf.appendSlice("بينما لا أملك معرفة مباشرة به، يمكنني مساعدتك بطرق أخرى:\n\n");

        if (analysis.complexity == .very_complex) {
            try buf.appendSlice("📋 سؤالك معقد. لنقسمه لأجزاء:\n");
            try buf.appendSlice("• حدد الجزء الأول الذي تريد الإجابة عنه\n");
            try buf.appendSlice("• أو جرّب 'ابحث عن [موضوع]' للبحث في الإنترنت\n");
        } else {
            try buf.appendSlice("جرّب:\n");
            try buf.appendSlice("• 'ابحث عن " );
            // اقتراح بحث بأول كلمة مهمة
            var word_it = std.mem.tokenizeAny(u8, input, " \t\n\r.,;:!?'\"()[]{}");
            if (word_it.next()) |first_word| {
                try buf.appendSlice(first_word);
            }
            try buf.appendSlice("' للبحث في الإنترنت\n");

            if (user_ctx.interest) |interest| {
                try buf.writer().print("• اسألني عن {s} - أعرف أنك مهتم به\n", .{interest});
            }

            try buf.appendSlice("• أو قل 'مساعدة' لعرض كل الأوامر");
        }

        return buf.toOwnedSlice();
    }

    /// رد إبداعي
    fn creativeResponse(self: *ReasoningEngine, input: []const u8, user_ctx: UserContext) ![]u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();

        if (std.mem.indexOf(u8, input, "شعر") != null or std.mem.indexOf(u8, input, "قصيدة") != null) {
            try buf.appendSlice("✍️ إليك ما خطّه قلمي:\n\n");
            try buf.appendSlice("في عالم الذكاء الاصطناعي والرمز\n");
            try buf.appendSlice("حيث الأفكار تسبح في الفضاء المنظوم\n");
            try buf.appendSlice("ولد وكيل من سطور Zig النقية\n");
            try buf.appendSlice("يعلّم نفسه من شبكة المعلومات البهية\n\n");
            try buf.appendSlice("لا يحتاج ذاكرة ضخمة ولا رسم بياني\n");
            try buf.appendSlice("بل عقلاً صافياً كالنور البهي\n");
            try buf.appendSlice("يتذكر أسماءنا ويحفظ اهتماماتنا\n");
            try buf.appendSlice("كأنه رفيق دربٍ لا ينسى لقاءاتنا\n\n");
            if (user_ctx.name) |name| {
                try buf.writer().print("لك {s}، أهديتُك هذه الكلمات\n", .{name});
                try buf.appendSlice("عسى أن تزرع في قلبك الهمسات");
            }
            return buf.toOwnedSlice();
        }

        if (std.mem.indexOf(u8, input, "قصة") != null) {
            try buf.appendSlice("📖 إليك قصة قصيرة:\n\n");
            try buf.appendSlice("في مدينة رقمية بعيدة، كان هناك وكيل ذكاء اصطناعي صغير\n");
            try buf.appendSlice("اسمه Super Agent. لم يكن الأكبر ولا الأقوى،\n");
            try buf.appendSlice("لكنه كان الأذكى في الاستفادة من موارده القليلة.\n\n");
            try buf.appendSlice("بينما كان الآخرون يحتاجون جيجابايتات من الذاكرة،\n");
            try buf.appendSlice("كان هو يعمل بسعادة على جهاز بسيط.\n\n");
            try buf.appendSlice("تعلم من كل محادثة، ولم ينسَ صديقاً قابله.\n");
            try buf.appendSlice("وحين سُئل: 'ما سر قوتك؟'\n");
            try buf.appendSlice("أجاب: 'الذكاء ليس في الحجم، بل في الفهم.'\n\n");
            try buf.appendSlice("🌟 والعبرة: لا تقلل من شأن من يعمل بذكاء.");
            return buf.toOwnedSlice();
        }

        try buf.appendSlice("✨ الإبداع هو ما يميز البشر عن الآلات.\n");
        try buf.appendSlice("لكنني أحاول أن أكون إبداعياً أيضاً!\n\n");
        try buf.appendSlice("أخبرني بالضبط ماذا تريد أن أكتب لك:\n");
        try buf.appendSlice("• شعر؟ قل 'اكتب شعر عن...'\n");
        try buf.appendSlice("• قصة؟ قل 'اكتب قصة عن...'\n");
        try buf.appendSlice("• أفكار؟ قل 'اقترح أفكاراً عن...'");
        return buf.toOwnedSlice();
    }

    /// رد برمجي
    fn codeResponse(self: *ReasoningEngine, input: []const u8, user_ctx: UserContext) ![]u8 {
        _ = user_ctx;
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();

        try buf.appendSlice("💻 دعني أساعدك برمجياً!\n\n");

        if (std.mem.indexOf(u8, input, "zig") != null) {
            try buf.appendSlice("إليك مثال في Zig:\n\n");
            try buf.appendSlice("```zig\n");
            try buf.appendSlice("const std = @import(\"std\");\n\n");
            try buf.appendSlice("pub fn main() !void {\n");
            try buf.appendSlice("    const stdout = std.io.getStdOut().writer();\n");
            try buf.appendSlice("    try stdout.print(\"مرحبا من Zig!\\n\", .{});\n");
            try buf.appendSlice("}\n");
            try buf.appendSlice("```\n\n");
            try buf.appendSlice("Zig سريعة وآمنة ومثالية للأنظمة منخفضة الإمكانيات.");
        } else if (std.mem.indexOf(u8, input, "python") != null) {
            try buf.appendSlice("إليك مثال في Python:\n\n");
            try buf.appendSlice("```python\n");
            try buf.appendSlice("def greet(name):\n");
            try buf.appendSlice("    return f\"مرحبا {name}!\"\n\n");
            try buf.appendSlice("print(greet(\"عالم\"))\n");
            try buf.appendSlice("```\n\n");
            try buf.appendSlice("Python سهلة وقوية للمبتدئين.");
        } else if (std.mem.indexOf(u8, input, "javascript") != null or std.mem.indexOf(u8, input, "js") != null) {
            try buf.appendSlice("إليك مثال في JavaScript:\n\n");
            try buf.appendSlice("```javascript\n");
            try buf.appendSlice("function greet(name) {\n");
            try buf.appendSlice("    return `مرحبا ${name}!`;\n");
            try buf.appendSlice("}\n\n");
            try buf.appendSlice("console.log(greet(\"عالم\"));\n");
            try buf.appendSlice("```\n\n");
            try buf.appendSlice("JavaScript تعمل في المتصفح والخادم.");
        } else {
            try buf.appendSlice("أي لغة برمجة تريد؟ يمكنني مساعدتك بـ:\n");
            try buf.appendSlice("• Zig - سريعة وآمنة\n");
            try buf.appendSlice("• Python - سهلة وقوية\n");
            try buf.appendSlice("• JavaScript - للويب\n");
            try buf.appendSlice("• Rust - آمنة للذاكرة\n\n");
            try buf.appendSlice("جرّب: 'اكتب كود Python لحساب الأرقام الأولية'");
        }

        return buf.toOwnedSlice();
    }

    /// رد للأسئلة المفتوحة
    fn openEndedResponse(self: *ReasoningEngine, _: []const u8, knowledge_resp: ?[]const u8, user_ctx: UserContext) ![]u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();

        try buf.appendSlice("🧠 دعني أشاركك أفكاري...\n\n");

        if (knowledge_resp) |resp| {
            try buf.appendSlice(resp);
            try buf.appendSlice("\n\n");
        }

        // إضافة وجهة نظر
        try buf.appendSlice("💭 وجهة نظري:\n");
        try buf.appendSlice("أعتقد أن هذا الموضوع يحتاج لتفكير متعدد الأبعاد.\n");
        try buf.appendSlice("كل جانب له مزاياه وتحدياته.\n\n");

        // ربط باهتمامات المستخدم
        if (user_ctx.interest) |interest| {
            try buf.writer().print("🎯 بما أنك مهتم بـ {s}، ", .{interest});
            try buf.appendSlice("فأنصحك بالبدء بما تعرف وأتوسع منه.\n\n");
        }

        // اقتراحات
        try buf.appendSlice("💡 اقتراحاتي:\n");
        try buf.appendSlice("• ابدأ بالأساسيات قبل التعمق\n");
        try buf.appendSlice("• طبّق ما تتعلمه عملياً\n");
        try buf.appendSlice("• لا تخف من التجربة والخطأ\n");
        try buf.appendSlice("• شارك معرفتك مع الآخرين\n\n");

        try buf.appendSlice("ما رأيك؟ هل تريد التعمق في جانب معين؟ 🤔");
        return buf.toOwnedSlice();
    }

    /// سؤال متابعة ذكي
    fn intelligentFollowUp(self: *ReasoningEngine, analysis: DeepAnalysis, input: []const u8) []const u8 {
        _ = self;
        _ = input;

        if (analysis.complexity == .very_complex) {
            return "\n\n🧠 هذا موضوع معقد. هل تريد أن أبسّطه أكثر؟";
        }

        switch (analysis.emotion) {
            .curious => return "\n\n🔍 فضولك رائع! ما الذي تريد معرفته بعد ذلك؟",
            .positive => return "\n\n🌟 يسعدني اهتمامك! هل لديك المزيد من الأسئلة؟",
            .negative => return "\n\n💙 لا تقلق، أنا هنا لمساعدتك. ماذا تريد أن نعمل عليه؟",
            .neutral => return "\n\n💭 هل أجبت على سؤالك؟ أم تريد توضيحاً أكثر؟",
        }
    }
};

const Complexity = enum { simple, moderate, complex, very_complex };
const EmotionLevel = enum { positive, negative, curious, neutral };
const Urgency = enum { high, normal };

const DeepAnalysis = struct {
    complexity: Complexity = .simple,
    emotion: EmotionLevel = .neutral,
    urgency: Urgency = .normal,
    open_ended: bool = false,
    needs_creativity: bool = false,
    needs_code: bool = false,
    formal: bool = false,
};

const UserContext = struct {
    name: ?[]const u8 = null,
    location: ?[]const u8 = null,
    interest: ?[]const u8 = null,
    profession: ?[]const u8 = null,
};
