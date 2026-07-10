// src/trainer.zig - محرك التدريب (مُصلح من OutOfBounds)
const std = @import("std");
const nn = @import("nn/mod.zig");
const LanguageModel = @import("model.zig").LanguageModel;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const web = @import("web/mod.zig");
const Memory = @import("memory.zig").Memory;

pub const Trainer = struct {
    model: *LanguageModel,
    tokenizer: *Tokenizer,
    memory: *Memory,
    allocator: std.mem.Allocator,
    rng: std.Random.DefaultPrng,
    seq_len: usize,

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

            // تحقق إضافي
            var valid = true;
            for (input) |t| { if (t >= self.model.config.vocab_size) { valid = false; break; } }
            for (target) |t| { if (t >= self.model.config.vocab_size) { valid = false; break; } }
            if (!valid) continue;

            var logits = try self.model.forward(input);
            defer logits.deinit();

            const loss = try self.model.loss(logits, target);
            stats.total_loss += loss;
            stats.examples += 1;
        }

        if (stats.examples > 0) {
            stats.avg_loss = stats.total_loss / @as(f32, @floatFromInt(stats.examples));
        }
        return stats;
    }

    pub fn trainFromWeb(self: *Trainer, seed_urls: []const []const u8, max_pages: usize) !void {
        var crawler = web.Crawler.init(self.allocator, max_pages);
        defer crawler.deinit();

        for (seed_urls) |url| {
            crawler.addUrl(url) catch continue;
        }

        std.debug.print("[trainer] starting crawl...\n", .{});
        var pages = try crawler.crawl();
        defer {
            for (pages.items) |p| self.allocator.free(p);
            pages.deinit();
        }

        std.debug.print("[trainer] fetched {d} pages\n", .{pages.items.len});

        var total_stats = TrainingStats{};
        for (pages.items, 0..) |page, i| {
            std.debug.print("[trainer] page {d}/{d} ({d} bytes)\n", .{ i + 1, pages.items.len, page.len });

            // تجاهل الصفحات القصيرة جداً
            if (page.len < 50) continue;

            const stats = self.trainOnText(page) catch |err| {
                std.debug.print("[trainer] skip page {d}: {}\n", .{ i + 1, err });
                continue;
            };
            total_stats.examples += stats.examples;
            total_stats.total_loss += stats.total_loss;

            if (page.len > 50 and page.len < 5000) {
                const key = std.fmt.allocPrint(self.allocator, "web_{d}", .{i}) catch continue;
                defer self.allocator.free(key);
                self.memory.remember(key, page) catch {};
            }
        }

        if (total_stats.examples > 0) {
            total_stats.avg_loss = total_stats.total_loss / @as(f32, @floatFromInt(total_stats.examples));
        }
        std.debug.print("[trainer] done. examples: {d}, avg_loss: {d:.4}\n", .{ total_stats.examples, total_stats.avg_loss });
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
