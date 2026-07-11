// src/problem_solver.zig - محلل المشكلات ومولد الأفكار
// يحلل المشكلة، يقسمها، يقترح حلولاً متعددة
const std = @import("std");

pub const ProblemSolver = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ProblemSolver {
        return .{ .allocator = allocator };
    }

    pub fn isProblemSolving(input: []const u8) bool {
        const indicators = [_][]const u8{
            "كيف أحل", "كيف نحل", "مشكلة", "حل مشكلة",
            "اقترح حل", "أفكار لحل", "حلول",
            "how to solve", "problem", "solution",
            "ماذا أفعل", "أحتاج مساعدة في",
            "تحدي", "صعوبة", "عالق",
            "اقترح أفكار", "أفكار لمشروع", "brainstorm",
        };
        for (indicators) |ind| {
            if (std.mem.indexOf(u8, input, ind) != null) return true;
        }
        return false;
    }

    pub fn solve(self: *ProblemSolver, input: []const u8) ![]u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();

        try buf.appendSlice("🧩 دعني أحلل المشكلة وأقترح حلولاً...\n\n");

        // 1. تحليل المشكلة
        try buf.appendSlice("📋 تحليل المشكلة:\n");
        const problem_type = self.classifyProblem(input);
        try buf.writer().print("• النوع: {s}\n", .{problemTypeName(problem_type)});
        try buf.appendSlice("• الخطوة الأولى: حدد المشكلة بوضوح\n");
        try buf.appendSlice("• الخطوة الثانية: اجمع المعلومات المتاحة\n");
        try buf.appendSlice("• الخطوة الثالثة: استبعد الحلول غير الممكنة\n\n");

        // 2. حلول مقترحة
        try buf.appendSlice("💡 حلول مقترحة:\n\n");
        try self.generateSolutions(&buf, problem_type, input);

        // 3. نصائح إضافية
        try buf.appendSlice("\n📌 نصائح ذهبية:\n");
        try buf.appendSlice("• ابدأ بالحل الأبسط أولاً\n");
        try buf.appendSlice("• قسّم المشكلة الكبيرة لأجزاء صغيرة\n");
        try buf.appendSlice("• جرّب حلّاً واحداً في كل مرة\n");
        try buf.appendSlice("• لا تخف من الفشل - كل محاولة تعلّمك شيئاً\n");
        try buf.appendSlice("• اطلب المساعدة عند الحاجة\n\n");

        try buf.appendSlice("🤔 أي حل تريد أن نبدأ به؟ أو هل تريد تفاصيل أكثر عن حل معين؟");

        return buf.toOwnedSlice();
    }

    fn classifyProblem(self: *ProblemSolver, input: []const u8) ProblemType {
        _ = self;
        if (std.mem.indexOf(u8, input, "كود") != null or
            std.mem.indexOf(u8, input, "برمجة") != null or
            std.mem.indexOf(u8, input, "code") != null or
            std.mem.indexOf(u8, input, "bug") != null or
            std.mem.indexOf(u8, input, "خطأ") != null)
        {
            return .technical;
        }
        if (std.mem.indexOf(u8, input, "مشروع") != null or
            std.mem.indexOf(u8, input, "startup") != null or
            std.mem.indexOf(u8, input, "business") != null or
            std.mem.indexOf(u8, input, "عمل") != null)
        {
            return .business;
        }
        if (std.mem.indexOf(u8, input, "تعلم") != null or
            std.mem.indexOf(u8, input, "دراسة") != null or
            std.mem.indexOf(u8, input, "learn") != null or
            std.mem.indexOf(u8, input, "study") != null)
        {
            return .learning;
        }
        if (std.mem.indexOf(u8, input, "وقت") != null or
            std.mem.indexOf(u8, input, "تنظيم") != null or
            std.mem.indexOf(u8, input, "إدارة") != null)
        {
            return .time_management;
        }
        if (std.mem.indexOf(u8, input, "علاقة") != null or
            std.mem.indexOf(u8, input, "تواصل") != null)
        {
            return .social;
        }
        return .general;
    }

    fn generateSolutions(self: *ProblemSolver, buf: *std.ArrayList(u8), ptype: ProblemType, input: []const u8) !void {
        _ = self;
        _ = input;

        switch (ptype) {
            .technical => {
                try buf.appendSlice("1️⃣ **الحل التقني المباشر:**\n");
                try buf.appendSlice("   • اقرأ رسالة الخطأ بعناية\n");
                try buf.appendSlice("   • ابحث في Stack Overflow أو Google\n");
                try buf.appendSlice("   • راجع الوثائق الرسمية\n\n");
                try buf.appendSlice("2️⃣ **الحل المنهجي:**\n");
                try buf.appendSlice("   • أعد إنتاج الخطأ في بيئة معزولة\n");
                try buf.appendSlice("   • استخدم debugger لتتبع المشكلة\n");
                try buf.appendSlice("   • أضف print statements لتحديد الموقع\n\n");
                try buf.appendSlice("3️⃣ **الحل الإبداعي:**\n");
                try buf.appendSlice("   • جرّب نهجاً مختلفاً تماماً\n");
                try buf.appendSlice("   • أعد كتابة الكود من الصفر\n");
                try buf.appendSlice("   • استشر زميلاً أو مجتمع المطورين\n");
            },
            .business => {
                try buf.appendSlice("1️⃣ **ابدأ بالحد الأدنى (MVP):**\n");
                try buf.appendSlice("   • حدد الميزة الأساسية فقط\n");
                try buf.appendSlice("   • أطلق بسرعة واحصل على ملاحظات\n\n");
                try buf.appendSlice("2️⃣ **تحليل السوق:**\n");
                try buf.appendSlice("   • ادرس المنافسين\n");
                try buf.appendSlice("   • حدد جمهورك المستهدف\n");
                try buf.appendSlice("   • اختبر الفكرة مع عملاء حقيقيين\n\n");
                try buf.appendSlice("3️⃣ **نموذج العمل:**\n");
                try buf.appendSlice("   • حدد كيف ستحقق الإيرادات\n");
                try buf.appendSlice("   • احسب التكاليف المتوقعة\n");
                try buf.appendSlice("   • خطط للتوسع التدريجي\n");
            },
            .learning => {
                try buf.appendSlice("1️⃣ **خطة تعلم منظم:**\n");
                try buf.appendSlice("   • حدد هدفك بوضوح\n");
                try buf.appendSlice("   • قسّم المحتوى لمستويات\n");
                try buf.appendSlice("   • خصص وقتاً يومياً (30 دقيقة)\n\n");
                try buf.appendSlice("2️⃣ **تعلم عملي:**\n");
                try buf.appendSlice("   • ابنِ مشاريع صغيرة\n");
                try buf.appendSlice("   • حلّ تمارين وتحديات\n");
                try buf.appendSlice("   • شارك في مجتمعات التعلم\n\n");
                try buf.appendSlice("3️⃣ **تعلّم اجتماعي:**\n");
                try buf.appendSlice("   • انضم لمجموعة دراسة\n");
                try buf.appendSlice("   • علّم غيرك ما تعلمته\n");
                try buf.appendSlice("   • ابحث عن مرشد (mentor)\n");
            },
            .time_management => {
                try buf.appendSlice("1️⃣ **تقنية بومودورو:**\n");
                try buf.appendSlice("   • 25 دقيقة عمل + 5 دقائق راحة\n");
                try buf.appendSlice("   • بعد 4 جلسات، خذ راحة 30 دقيقة\n\n");
                try buf.appendSlice("2️⃣ **مصفوفة آيزنهاور:**\n");
                try buf.appendSlice("   • عاجل ومهم: افعله الآن\n");
                try buf.appendSlice("   • مهم غير عاجل: جدوله\n");
                try buf.appendSlice("   • عاجل غير مهم: فوّضه\n");
                try buf.appendSlice("   • غير عاجل غير مهم: احذفه\n\n");
                try buf.appendSlice("3️⃣ **قاعدة الدقيقتين:**\n");
                try buf.appendSlice("   • إذا كان شيء يستغرق أقل من دقيقتين، افعله فوراً\n");
            },
            .social => {
                try buf.appendSlice("1️⃣ **الاستماع الفعّال:**\n");
                try buf.appendSlice("   • استمع لتفهم، لا لترد\n");
                try buf.appendSlice("   • كرّر ما سمعته للتأكد\n\n");
                try buf.appendSlice("2️⃣ **التواصل الواضح:**\n");
                try buf.appendSlice("   • استخدم 'أنا أشعر' بدلاً من 'أنت دائماً'\n");
                try buf.appendSlice("   • ركّز على المشكلة لا الشخص\n\n");
                try buf.appendSlice("3️⃣ **التعاطف:**\n");
                try buf.appendSlice("   • ضع نفسك مكان الآخر\n");
                try buf.appendSlice("   • اعترف بمشاعره قبل تقديم الحل\n");
            },
            .general => {
                try buf.appendSlice("1️⃣ **الحل التحليلي:**\n");
                try buf.appendSlice("   • اقسّم المشكلة لأجزاء\n");
                try buf.appendSlice("   • حل كل جزء على حدة\n");
                try buf.appendSlice("   • ادمج الحلول\n\n");
                try buf.appendSlice("2️⃣ **الحل الإبداعي:**\n");
                try buf.appendSlice("   • فكّر خارج الصندوق\n");
                try buf.appendSlice("   • ابحث عن أنماط مماثلة\n");
                try buf.appendSlice("   • جرّب العصف الذهني\n\n");
                try buf.appendSlice("3️⃣ **الحل التعاوني:**\n");
                try buf.appendSlice("   • شارك المشكلة مع آخرين\n");
                try buf.appendSlice("   • كن منفتحاً للأفكار المختلفة\n");
                try buf.appendSlice("   • ادمج وجهات نظر متعددة\n");
            },
        }
    }
};

const ProblemType = enum { technical, business, learning, time_management, social, general };

fn problemTypeName(p: ProblemType) []const u8 {
    return switch (p) {
        .technical => "تقني/برمجي",
        .business => "مشروع/أعمال",
        .learning => "تعلم/دراسة",
        .time_management => "إدارة وقت",
        .social => "اجتماعي/علاقات",
        .general => "عام",
    };
}
