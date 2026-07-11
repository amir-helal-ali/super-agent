// src/trainer.zig - محرك التدريب مع تحديث فعلي للأوزان
const std = @import("std");
const nn = @import("nn/mod.zig");
const LanguageModel = @import("model.zig").LanguageModel;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const web = @import("web/mod.zig");
const Memory = @import("memory.zig").Memory;
const corpus = @import("corpus.zig");

pub const Trainer = struct {
    model: *LanguageModel,
    tokenizer: *Tokenizer,
    memory: *Memory,
    allocator: std.mem.Allocator,
    rng: std.Random.DefaultPrng,
    seq_len: usize,
    learning_rate: f32,
    step_count: u32,

    pub fn init(
        allocator: std.mem.Allocator,
        model: *LanguageModel,
        tokenizer: *Tokenizer,
        memory: *Memory,
    ) Trainer {
        return .{
            .model = model,
            .tokenizer = tokenizer,
            .memory = memory,
            .allocator = allocator,
            .rng = nn.tensor.createRng(@bitCast(std.time.timestamp())),
            .seq_len = 16,
            .learning_rate = 0.01,
            .step_count = 0,
        };
    }

    pub fn trainOnText(self: *Trainer, text: []const u8) !TrainingStats {
        var stats = TrainingStats{};
        if (text.len < self.seq_len + 1) return stats;

        var tokens = try self.tokenizer.encode(text);
        defer tokens.deinit();

        // فلترة tokens خارج النطاق
        var valid_count: usize = 0;
        for (tokens.items) |tok| {
            if (tok < self.model.config.vocab_size) {
                tokens.items[valid_count] = tok;
                valid_count += 1;
            }
        }
        tokens.items.len = valid_count;

        if (tokens.items.len < self.seq_len + 1) return stats;

        var pos: usize = 0;
        const step: usize = self.seq_len / 2;

        while (pos + self.seq_len + 1 < tokens.items.len) : (pos += step) {
            const input = tokens.items[pos .. pos + self.seq_len];
            const target = tokens.items[pos + 1 .. pos + self.seq_len + 1];

            var valid = true;
            for (input) |t| { if (t >= self.model.config.vocab_size) { valid = false; break; } }
            for (target) |t| { if (t >= self.model.config.vocab_size) { valid = false; break; } }
            if (!valid) continue;

            // Forward pass
            var logits = try self.model.forward(input);
            defer logits.deinit();

            // حساب الخسارة
            const loss = try self.model.loss(logits, target);
            stats.total_loss += loss;
            stats.examples += 1;
            self.step_count += 1;

            // تحديث فعلي للأوزان: تحديث embedding بناءً على الخطأ
            self.updateEmbeddings(input, target, logits);
        }

        if (stats.examples > 0) {
            stats.avg_loss = stats.total_loss / @as(f32, @floatFromInt(stats.examples));
        }
        return stats;
    }

    /// تحديث embedding weights باستخدام SGD مبسط
    fn updateEmbeddings(self: *Trainer, input: []const u32, target: []const u32, logits: nn.Tensor) void {
        const vocab_size = self.model.config.vocab_size;
        const embed_dim = self.model.config.embed_dim;
        const seq_len = input.len;
        const lr = self.learning_rate;

        // حساب softmax لكل صف
        const probs = self.allocator.alloc(f32, seq_len * vocab_size) catch return;
        defer self.allocator.free(probs);

        var i: usize = 0;
        while (i < seq_len) : (i += 1) {
            const row = logits.data[i * vocab_size .. (i + 1) * vocab_size];
            const prob_row = probs[i * vocab_size .. (i + 1) * vocab_size];
            var max_val: f32 = row[0];
            for (row[1..]) |v| { if (v > max_val) max_val = v; }
            var sum: f32 = 0;
            for (row, 0..) |v, j| {
                prob_row[j] = std.math.exp(v - max_val);
                sum += prob_row[j];
            }
            for (prob_row) |*p| p.* /= sum;
        }

        // تحديث كل embedding: نقرّب embedding للكلمة الحالية من الـ target
        i = 0;
        while (i < seq_len) : (i += 1) {
            const tok_id = input[i];
            const target_id = target[i];
            if (tok_id >= self.model.token_embed.weight.shape[0]) continue;
            if (target_id >= vocab_size) continue;

            const prob_target = probs[i * vocab_size + target_id];
            const grad_scale = lr * (1.0 - prob_target); // gradient أكبر عندما التوقع ضعيف

            // تحديث embedding للكلمة الحالية نحو الـ target
            const embed_row = self.model.token_embed.weight.data[tok_id * embed_dim .. (tok_id + 1) * embed_dim];
            const target_embed = self.model.token_embed.weight.data[target_id * embed_dim .. (target_id + 1) * embed_dim];

            // نقرّب embedding الكلمة الحالية من embedding الكلمة الهدف
            var j: usize = 0;
            while (j < embed_dim) : (j += 1) {
                embed_row[j] += grad_scale * (target_embed[j] - embed_row[j]) * 0.1;
            }

            // تحديث lm_head weights لتعزيز التوقع الصحيح
            const lm_weight = self.model.lm_head.weight.data;
            const lm_row = lm_weight[target_id * embed_dim .. (target_id + 1) * embed_dim];
            j = 0;
            while (j < embed_dim) : (j += 1) {
                lm_row[j] += grad_scale * embed_row[j] * 0.01;
            }
        }
    }

    /// تدريب مكثف على corpus كامل
    pub fn trainIntensive(self: *Trainer, epochs: usize) !TrainingStats {
        var total_stats = TrainingStats{};

        std.debug.print("[train] intensive training: {d} epochs, {d} sentences\n", .{ epochs, corpus.CORPUS_SIZE });

        for (0..epochs) |epoch| {
            std.debug.print("[train] === Epoch {d}/{d} ===\n", .{ epoch + 1, epochs });
            var epoch_loss: f32 = 0;
            var epoch_examples: usize = 0;

            for (corpus.CORPUS) |text| {
                const stats = self.trainOnText(text) catch continue;
                epoch_loss += stats.total_loss;
                epoch_examples += stats.examples;
                total_stats.examples += stats.examples;
                total_stats.total_loss += stats.total_loss;
            }

            if (epoch_examples > 0) {
                const avg = epoch_loss / @as(f32, @floatFromInt(epoch_examples));
                std.debug.print("[train] epoch {d} done: {d} examples, avg_loss: {d:.4}\n", .{ epoch + 1, epoch_examples, avg });
            }
        }

        if (total_stats.examples > 0) {
            total_stats.avg_loss = total_stats.total_loss / @as(f32, @floatFromInt(total_stats.examples));
        }

        std.debug.print("[train] intensive training complete: {d} total examples, avg_loss: {d:.4}\n", .{ total_stats.examples, total_stats.avg_loss });
        return total_stats;
    }

    pub fn trainFromWeb(self: *Trainer, seed_urls: []const []const u8, max_pages: usize) !void {
        var crawler = web.Crawler.init(self.allocator, max_pages);
        defer crawler.deinit();
        for (seed_urls) |url| { crawler.addUrl(url) catch continue; }

        std.debug.print("[trainer] starting crawl...\n", .{});
        var pages = try crawler.crawl();
        defer { for (pages.items) |p| self.allocator.free(p); pages.deinit(); }

        std.debug.print("[trainer] fetched {d} pages\n", .{pages.items.len});
        for (pages.items, 0..) |page, i| {
            if (page.len < 50) continue;
            std.debug.print("[trainer] page {d}/{d}\n", .{ i + 1, pages.items.len });
            _ = self.trainOnText(page) catch continue;
            if (page.len > 50 and page.len < 5000) {
                const key = std.fmt.allocPrint(self.allocator, "web_{d}", .{i}) catch continue;
                defer self.allocator.free(key);
                self.memory.remember(key, page) catch {};
            }
        }
    }

    pub fn trainFromFile(self: *Trainer, path: []const u8) !TrainingStats {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        const content = try file.readToEndAlloc(self.allocator, 50 * 1024 * 1024);
        defer self.allocator.free(content);
        return self.trainOnText(content);
    }
};

pub const TrainingStats = struct {
    examples: usize = 0,
    total_loss: f32 = 0,
    avg_loss: f32 = 0,
};
