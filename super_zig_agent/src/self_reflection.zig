// src/self_reflection.zig - نظام التقييم الذاتي والتحسين المستمر
// يقيّم جودة ردوده، يتعلّم من الأخطاء، يحسّن نفسه
const std = @import("std");

pub const SelfReflection = struct {
    allocator: std.mem.Allocator,
    response_log: std.ArrayList(ResponseLog),
    improvement_count: usize,
    quality_score: f32,

    pub fn init(allocator: std.mem.Allocator) SelfReflection {
        return .{
            .allocator = allocator,
            .response_log = std.ArrayList(ResponseLog).init(allocator),
            .improvement_count = 0,
            .quality_score = 0.75,
        };
    }

    pub fn deinit(self: *SelfReflection) void {
        for (self.response_log.items) |*r| {
            self.allocator.free(r.user_input);
            self.allocator.free(r.agent_response);
        }
        self.response_log.deinit();
    }

    /// تسجيل رد لتقييمه لاحقاً
    pub fn logResponse(self: *SelfReflection, input: []const u8, response: []const u8, tools_used: []const []const u8) !void {
        const input_owned = try self.allocator.dupe(u8, input);
        const response_owned = try self.allocator.dupe(u8, response);

        // تقييم فوري للجودة
        const score = self.evaluateResponse(response, input);

        try self.response_log.append(.{
            .user_input = input_owned,
            .agent_response = response_owned,
            .quality_score = score,
            .timestamp = std.time.timestamp(),
            .tools_count = tools_used.len,
        });

        // الاحتفاظ بآخر 50 رد فقط
        if (self.response_log.items.len > 50) {
            const old = self.response_log.orderedRemove(0);
            self.allocator.free(old.user_input);
            self.allocator.free(old.agent_response);
        }

        // تحديث متوسط الجودة
        self.updateQualityScore();
    }

    /// تقييم جودة الرد
    fn evaluateResponse(self: *SelfReflection, response: []const u8, input: []const u8) f32 {
        _ = self;
        var score: f32 = 0.5; // أساس

        // طول مناسب (ليس قصيراً جداً ولا طويلاً جداً)
        if (response.len > 20 and response.len < 2000) {
            score += 0.15;
        }

        // يحتوي على معلومة مفيدة
        if (std.mem.indexOf(u8, response, "•") != null or
            std.mem.indexOf(u8, response, "-") != null or
            std.mem.indexOf(u8, response, "✓") != null)
        {
            score += 0.1;
        }

        // يحتوي على تفاعل بشري (إيموجي أو سؤال)
        var has_emoji = false;
        for (response) |b| {
            if (b >= 0xE2) { // بداية UTF-8 للإيموجي
                has_emoji = true;
                break;
            }
        }
        if (has_emoji) score += 0.05;

        // يطرح سؤال متابعة
        if (std.mem.indexOf(u8, response, "؟") != null or
            std.mem.indexOf(u8, response, "?") != null)
        {
            score += 0.1;
        }

        // مرتبط بالسؤال (يحتوي على كلمات من السؤال)
        var word_it = std.mem.tokenizeAny(u8, input, " \t\n\r.,;:!?'\"");
        var relevance: usize = 0;
        while (word_it.next()) |word| {
            if (word.len > 3) {
                if (std.mem.indexOf(u8, response, word) != null) {
                    relevance += 1;
                }
            }
        }
        if (relevance > 0) score += 0.1;

        // لا يخلط لغات
        var ar_count: usize = 0;
        var en_count: usize = 0;
        for (response) |b| {
            if (b >= 0xD8 and b <= 0xD9) ar_count += 1;
            if (b >= 'a' and b <= 'z') en_count += 1;
        }
        if (ar_count > 0 and en_count > 0) {
            const minority = @min(ar_count, en_count);
            const total = ar_count + en_count;
            if (minority * 100 / total > 40) {
                score -= 0.15; // خصم للخلط اللغوي
            }
        }

        // يعطي نصيحة أو اقتراح
        if (std.mem.indexOf(u8, response, "جرّب") != null or
            std.mem.indexOf(u8, response, "نصيحة") != null or
            std.mem.indexOf(u8, response, "اقتراح") != null)
        {
            score += 0.05;
        }

        if (score > 1.0) score = 1.0;
        if (score < 0.0) score = 0.0;
        return score;
    }

    /// تحديث متوسط الجودة
    fn updateQualityScore(self: *SelfReflection) void {
        if (self.response_log.items.len == 0) return;
        var total: f32 = 0;
        for (self.response_log.items) |r| {
            total += r.quality_score;
        }
        self.quality_score = total / @as(f32, @floatFromInt(self.response_log.items.len));
    }

    /// تلقي ملاحظة من المستخدم وتحسين
    pub fn receiveFeedback(self: *SelfReflection, feedback: []const u8) ![]u8 {
        self.improvement_count += 1;

        const positive = std.mem.indexOf(u8, feedback, "جيد") != null or
            std.mem.indexOf(u8, feedback, "ممتاز") != null or
            std.mem.indexOf(u8, feedback, "رائع") != null or
            std.mem.indexOf(u8, feedback, "good") != null or
            std.mem.indexOf(u8, feedback, "great") != null;

        const negative = std.mem.indexOf(u8, feedback, "سيء") != null or
            std.mem.indexOf(u8, feedback, "خطأ") != null or
            std.mem.indexOf(u8, feedback, "bad") != null or
            std.mem.indexOf(u8, feedback, "wrong") != null;

        if (positive) {
            self.quality_score = @min(self.quality_score + 0.05, 1.0);
            return self.allocator.dupe(u8, "شكراً! 🌟 ملاحظتك الإيجابية تشجعني على التحسن أكثر. سأحافظ على هذا المستوى!");
        }

        if (negative) {
            self.quality_score = @max(self.quality_score - 0.05, 0.0);
            return self.allocator.dupe(u8, "أعتذر! 😔 سأعمل على تحسين ردودي. ملاحظاتك تساعدني أن أصبح أذكى. ما الجزء الذي لم يعجبك بالضبط؟");
        }

        return self.allocator.dupe(u8, "شكراً لملاحظتك! 📝 سأأخذها بعين الاعتبار في ردودي القادمة.");
    }

    /// توليد تقرير عن الأداء الذاتي
    pub fn selfReport(self: *SelfReflection) ![]u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();

        try buf.appendSlice("📊 تقرير الأداء الذاتي:\n\n");
        try buf.writer().print("• إجمالي الردود: {d}\n", .{self.response_log.items.len});
        try buf.writer().print("• متوسط الجودة: {d:.1}%\n", .{self.quality_score * 100});
        try buf.writer().print("• مرات التحسين: {d}\n", .{self.improvement_count});

        // أفضل وأسوأ رد
        if (self.response_log.items.len > 0) {
            var best_idx: usize = 0;
            var worst_idx: usize = 0;
            var best_score: f32 = 0;
            var worst_score: f32 = 1.0;

            for (self.response_log.items, 0..) |r, i| {
                if (r.quality_score > best_score) {
                    best_score = r.quality_score;
                    best_idx = i;
                }
                if (r.quality_score < worst_score) {
                    worst_score = r.quality_score;
                    worst_idx = i;
                }
            }

            try buf.appendSlice("\n✅ أفضل رد (جودة عالية):\n");
            const best = self.response_log.items[best_idx];
            const best_preview_len = @min(best.agent_response.len, 80);
            try buf.appendSlice(best.agent_response[0..best_preview_len]);
            if (best.agent_response.len > 80) try buf.appendSlice("...\n");

            try buf.appendSlice("\n⚠️ رد يحتاج تحسين:\n");
            const worst = self.response_log.items[worst_idx];
            const worst_preview_len = @min(worst.agent_response.len, 80);
            try buf.appendSlice(worst.agent_response[0..worst_preview_len]);
            if (worst.agent_response.len > 80) try buf.appendSlice("...\n");
        }

        try buf.appendSlice("\n🧠 خطة التحسين:\n");
        try buf.appendSlice("• التركيز على ردود أطول وأكثر تفصيلاً\n");
        try buf.appendSlice("• طرح أسئلة متابعة في كل رد\n");
        try buf.appendSlice("• ربط الردود باهتمامات المستخدم\n");
        try buf.appendSlice("• تجنب الخلط اللغوي\n");

        return buf.toOwnedSlice();
    }

    /// هل يطلب المستخدم تقييم الأداء؟
    pub fn isSelfReportRequest(input: []const u8) bool {
        return std.mem.indexOf(u8, input, "تقييم أدائك") != null or
            std.mem.indexOf(u8, input, "كيف أداؤك") != null or
            std.mem.indexOf(u8, input, "self report") != null or
            std.mem.indexOf(u8, input, "أداءك") != null or
            std.mem.indexOf(u8, input, "تقرير ذاتي") != null;
    }

    /// هل يقدم المستخدم ملاحظة؟
    pub fn isFeedback(input: []const u8) bool {
        return std.mem.indexOf(u8, input, "ردك سيء") != null or
            std.mem.indexOf(u8, input, "ردك جيد") != null or
            std.mem.indexOf(u8, input, "لم يعجبني") != null or
            std.mem.indexOf(u8, input, "أعجبني ردك") != null or
            std.mem.indexOf(u8, input, "حسّن ردودك") != null or
            std.mem.indexOf(u8, input, "feedback") != null;
    }
};

const ResponseLog = struct {
    user_input: []u8,
    agent_response: []u8,
    quality_score: f32,
    timestamp: i64,
    tools_count: usize,
};
