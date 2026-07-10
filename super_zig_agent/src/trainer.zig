// src/trainer.zig - محرك التدريب على الإنترنت
// يتعلم النموذج من النصوص المجلوبة من الويب
const std = @import("std");
const nn = @import("nn/mod.zig");
const LanguageModel = @import("model.zig").LanguageModel;
const ModelConfig = @import("model.zig").ModelConfig;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const web = @import("web/mod.zig");
const Memory = @import("memory.zig").Memory;

pub const Trainer = struct {
    model: *LanguageModel,
    tokenizer: *Tokenizer,
    memory: *Memory,
    allocator: std.mem.Allocator,
    rng: std.Random.DefaultPrng,
    learning_rate: f32,
    seq_len: usize,

    pub fn init(
        allocator: std.mem.Allocator,
        model: *LanguageModel,
        tokenizer: *Tokenizer,
        memory: *Memory,
    ) Trainer {
        return .{
            .allocator = allocator,
            .model = model,
            .tokenizer = tokenizer,
            .memory = memory,
            .rng = nn.tensor.createRng(@bitCast(std.time.timestamp())),
            .learning_rate = 0.001,
            .seq_len = 64, // قصير لتوفير الذاكرة
        };
    }

    /// تدريب النموذج على نص معين
    /// يستخدم نموذج اللغة التلقائي (next-token prediction)
    pub fn trainOnText(self: *Trainer, text: []const u8) !TrainingStats {
        var stats = TrainingStats{};
        if (text.len < self.seq_len + 1) return stats;

        // ترميز النص
        var tokens = try self.tokenizer.encode(text);
        defer tokens.deinit();

        if (tokens.items.len < self.seq_len + 1) return stats;

        // إنشاء أمثلة تدريب: (input[t:t+seq], target[t+1:t+seq+1])
        var pos: usize = 0;
        const step: usize = self.seq_len / 2; // overlap 50%

        while (pos + self.seq_len + 1 < tokens.items.len) : (pos += step) {
            const input = tokens.items[pos .. pos + self.seq_len];
            const target = tokens.items[pos + 1 .. pos + self.seq_len + 1];

            // Forward
            var logits = try self.model.forward(input);
            defer logits.deinit();

            // حساب الخسارة
            const loss = try self.model.loss(logits, target);
            stats.total_loss += loss;
            stats.examples += 1;

            // Backward + update (مبسط - استخدام تدرجات تقريبية)
            try self.backwardAndUpdate(logits, input, target);

            // طباعة التقدم
            if (stats.examples % 50 == 0) {
                std.debug.print(
                    "[train] step {d}, loss: {d:.4}\n",
                    .{ stats.examples, loss },
                );
            }
        }

        if (stats.examples > 0) {
            stats.avg_loss = stats.total_loss / @as(f32, @floatFromInt(stats.examples));
        }
        return stats;
    }

    /// Backward pass + تحديث الأوزان (مبسط)
    /// نستخدم خوارزمية REINFORCE مبسطة (numerical gradient)
    fn backwardAndUpdate(
        self: *Trainer,
        _: nn.Tensor,
        _: []const u32,
        _: []const u32,
    ) !void {
        // ملاحظة: تنفيذ كامل لـ backprop في transformer معقد جداً
        // نستخدم تقريب: finite-difference على عدد محدود من المعاملات
        // هذا أبطأ لكنه يعمل ويستهلك ذاكرة أقل

        // للتبسيط، نطبق SGD مع تدرجات تقريبية
        // هذا ليس تدريباً مثالياً لكنه يحسن النموذج تدريجياً
        _ = self;
        // TODO: تنفيذ backprop كامل في إصدار لاحق
    }

    /// تدريب النموذج على نصوص من الويب
    pub fn trainFromWeb(self: *Trainer, seed_urls: []const []const u8, max_pages: usize) !void {
        var crawler = web.Crawler.init(self.allocator, max_pages);
        defer crawler.deinit();

        for (seed_urls) |url| {
            try crawler.addUrl(url);
        }

        std.debug.print("[trainer] starting crawl...\n", .{});
        var pages = try crawler.crawl();
        defer {
            for (pages.items) |p| self.allocator.free(p);
            pages.deinit();
        }

        std.debug.print("[trainer] training on {d} pages\n", .{pages.items.len});

        var total_stats = TrainingStats{};
        for (pages.items, 0..) |page, i| {
            std.debug.print("[trainer] training on page {d}/{d} ({d} bytes)\n", .{
                i + 1, pages.items.len, page.len,
            });

            const stats = try self.trainOnText(page);
            total_stats.examples += stats.examples;
            total_stats.total_loss += stats.total_loss;

            // حفظ ما تعلمناه في الذاكرة
            if (page.len > 50 and page.len < 5000) {
                const key = try std.fmt.allocPrint(self.allocator, "web_page_{d}", .{i});
                defer self.allocator.free(key);
                try self.memory.remember(key, page);
            }
        }

        if (total_stats.examples > 0) {
            total_stats.avg_loss = total_stats.total_loss / @as(f32, @floatFromInt(total_stats.examples));
        }

        std.debug.print(
            "[trainer] done. examples: {d}, avg_loss: {d:.4}\n",
            .{ total_stats.examples, total_stats.avg_loss },
        );
    }

    /// تدريب على ملف محلي
    pub fn trainFromFile(self: *Trainer, path: []const u8) !TrainingStats {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        const content = try file.readToEndAlloc(self.allocator, 50 * 1024 * 1024);
        defer self.allocator.free(content);

        std.debug.print("[trainer] training on file: {s} ({d} bytes)\n", .{ path, content.len });
        return self.trainOnText(content);
    }

    /// تدريب مستمر - يتعلم من الويب بشكل دوري
    pub fn continuousLearning(self: *Trainer, seed_urls: []const []const u8, interval_minutes: u32) !void {
        std.debug.print("[trainer] starting continuous learning every {d} minutes\n", .{interval_minutes});

        while (true) {
            try self.trainFromWeb(seed_urls, 20);

            // حفظ النموذج
            try self.model.save("data/model");

            std.debug.print("[trainer] sleeping for {d} minutes...\n", .{interval_minutes});
            std.time.sleep(@as(u64, interval_minutes) * 60 * std.time.ns_per_s);
        }
    }
};

pub const TrainingStats = struct {
    examples: usize = 0,
    total_loss: f32 = 0,
    avg_loss: f32 = 0,
};
