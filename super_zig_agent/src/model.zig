// src/model.zig - النموذج اللغوي الصغير (Mini GPT)
// مصمم ليعمل على 2GB RAM بدون GPU
// حجمه حوالي 5-20 مليون معامل (خفيف جداً)
const std = @import("std");
const nn = @import("nn/mod.zig");
const Tokenizer = @import("tokenizer.zig").Tokenizer;

pub const ModelConfig = struct {
    vocab_size: usize = 8000,
    embed_dim: usize = 256,
    num_heads: usize = 4,
    num_layers: usize = 4,
    max_seq_len: usize = 256,
    ffn_ratio: usize = 4,
};

/// نموذج Mini-GPT
pub const LanguageModel = struct {
    config: ModelConfig,
    token_embed: nn.Embedding,
    pos_encoding: nn.PositionalEncoding,
    blocks: []nn.TransformerBlock,
    final_ln_gamma: nn.Tensor,
    final_ln_beta: nn.Tensor,
    lm_head: nn.Linear, // embed_dim -> vocab_size
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: ModelConfig, rng: *std.Random) !LanguageModel {
        const blocks = try allocator.alloc(nn.TransformerBlock, config.num_layers);
        for (blocks) |*b| {
            b.* = try nn.TransformerBlock.init(
                allocator,
                config.embed_dim,
                config.num_heads,
                config.ffn_ratio,
                rng,
            );
        }

        // gamma = 1, beta = 0
        const gamma = try nn.Tensor.init(allocator, &.{config.embed_dim});
        @memset(gamma.data, 1.0);
        const beta = try nn.Tensor.init(allocator, &.{config.embed_dim});
        @memset(beta.data, 0.0);

        return .{
            .config = config,
            .token_embed = try nn.Embedding.init(allocator, config.vocab_size, config.embed_dim, rng),
            .pos_encoding = try nn.PositionalEncoding.init(allocator, config.max_seq_len, config.embed_dim),
            .blocks = blocks,
            .final_ln_gamma = gamma,
            .final_ln_beta = beta,
            .lm_head = try nn.Linear.init(allocator, config.embed_dim, config.vocab_size, rng),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LanguageModel) void {
        self.token_embed.deinit();
        self.pos_encoding.deinit();
        for (self.blocks) |*b| b.deinit();
        self.allocator.free(self.blocks);
        self.final_ln_gamma.deinit();
        self.final_ln_beta.deinit();
        self.lm_head.deinit();
    }

    /// Forward pass
    /// token_ids: [seq_len] -> logits: [seq_len, vocab_size]
    pub fn forward(self: *LanguageModel, token_ids: []const u32) !nn.Tensor {
        // 1. Token embedding
        var x = try self.token_embed.forward(token_ids);
        // 2. Add positional encoding
        try self.pos_encoding.apply(&x);
        // 3. Transformer blocks
        for (self.blocks) |*block| {
            const out = try block.forward(x);
            x.deinit();
            x = out;
        }
        // 4. Final layer norm
        try x.layerNorm(self.final_ln_gamma, self.final_ln_beta, 1e-5);
        // 5. LM head
        const logits = try self.lm_head.forward(x);
        x.deinit();
        return logits;
    }

    /// توليد النص باستخدام greedy sampling
    /// prompt_ids: IDs البداية
    /// max_tokens: أقصى عدد للتوكنز المولدة
    pub fn generate(
        self: *LanguageModel,
        prompt_ids: []const u32,
        max_tokens: usize,
        temperature: f32,
        rng: *std.Random,
    ) !std.ArrayList(u32) {
        var result = std.ArrayList(u32).init(self.allocator);
        // إضافة الـ prompt
        try result.appendSlice(prompt_ids);

        var step: usize = 0;
        while (step < max_tokens) : (step += 1) {
            // أخذ آخر max_seq_len توكنز فقط
            const start_idx = if (result.items.len > self.config.max_seq_len)
                result.items.len - self.config.max_seq_len
            else
                0;
            const ctx = result.items[start_idx..];

            // Forward
            var logits = try self.forward(ctx);
            defer logits.deinit();

            // أخذ logits للتوكن الأخير فقط
            const seq_len = logits.shape[0];
            const vocab_size = logits.shape[1];
            const last_logits = logits.data[(seq_len - 1) * vocab_size .. seq_len * vocab_size];

            // تطبيق temperature
            var scaled = try self.allocator.alloc(f32, vocab_size);
            defer self.allocator.free(scaled);
            for (last_logits, 0..) |v, i| {
                scaled[i] = v / temperature;
            }

            // softmax
            softmaxInPlace(scaled);

            // sampling
            const r = rng.float(f32);
            var cum: f32 = 0;
            var chosen: usize = 0;
            for (scaled, 0..) |p, i| {
                cum += p;
                if (r <= cum) {
                    chosen = i;
                    break;
                }
            }

            // إيقاف عند EOS
            if (chosen == Tokenizer.EOS) break;
            try result.append(@intCast(chosen));
        }
        return result;
    }

    /// حساب دالة الخسارة (cross-entropy)
    /// logits: [seq_len, vocab_size], targets: [seq_len]
    pub fn loss(
        self: *LanguageModel,
        logits: nn.Tensor,
        targets: []const u32,
    ) !f32 {
        const seq_len = logits.shape[0];
        const vocab_size = logits.shape[1];
        var total_loss: f32 = 0;
        var i: usize = 0;
        while (i < seq_len) : (i += 1) {
            const row = logits.data[i * vocab_size .. (i + 1) * vocab_size];
            // softmax + log
            var max_val: f32 = row[0];
            for (row[1..]) |v| {
                if (v > max_val) max_val = v;
            }
            var sum: f32 = 0;
            for (row) |v| sum += std.math.exp(v - max_val);
            const log_sum = @log(sum) + max_val;
            // خسارة الـ target
            const target = targets[i];
            if (target < vocab_size) {
                total_loss += log_sum - row[target];
            }
        }
        _ = self;
        return total_loss / @as(f32, @floatFromInt(seq_len));
    }

    /// حفظ النموذج
    pub fn save(self: *LanguageModel, dir: []const u8) !void {
        try std.fs.cwd().makePath(dir);

        // حفظ الإعدادات
        var path_buf: [256]u8 = undefined;
        const config_path = try std.fmt.bufPrint(&path_buf, "{s}/config.json", .{dir});
        const file = try std.fs.cwd().createFile(config_path, .{});
        defer file.close();
        var writer = file.writer();
        try writer.print(
            "{{\"vocab_size\":{d},\"embed_dim\":{d},\"num_heads\":{d},\"num_layers\":{d},\"max_seq_len\":{d},\"ffn_ratio\":{d}}}",
            .{
                self.config.vocab_size,
                self.config.embed_dim,
                self.config.num_heads,
                self.config.num_layers,
                self.config.max_seq_len,
                self.config.ffn_ratio,
            },
        );

        // حفظ embedding
        const embed_path = try std.fmt.bufPrint(&path_buf, "{s}/token_embed.bin", .{dir});
        try self.token_embed.save(embed_path);

        // حفظ كل block
        for (self.blocks, 0..) |block, i| {
            var name_buf: [64]u8 = undefined;
            const wq = try std.fmt.bufPrint(&name_buf, "block_{d}_wq", .{i});
            try block.attn.w_q.save(dir, wq);
            const wk = try std.fmt.bufPrint(&name_buf, "block_{d}_wk", .{i});
            try block.attn.w_k.save(dir, wk);
            const wv = try std.fmt.bufPrint(&name_buf, "block_{d}_wv", .{i});
            try block.attn.w_v.save(dir, wv);
            const wo = try std.fmt.bufPrint(&name_buf, "block_{d}_wo", .{i});
            try block.attn.w_o.save(dir, wo);
            const ffn1 = try std.fmt.bufPrint(&name_buf, "block_{d}_ffn1", .{i});
            try block.ffn1.save(dir, ffn1);
            const ffn2 = try std.fmt.bufPrint(&name_buf, "block_{d}_ffn2", .{i});
            try block.ffn2.save(dir, ffn2);
        }

        // حفظ LM head
        const lm_path = try std.fmt.bufPrint(&path_buf, "{s}/lm_head", .{dir});
        try self.lm_head.save(dir, "lm_head");
        _ = lm_path;
    }
};

fn softmaxInPlace(arr: []f32) void {
    var max_val: f32 = arr[0];
    for (arr[1..]) |v| {
        if (v > max_val) max_val = v;
    }
    var sum: f32 = 0;
    for (arr) |*v| {
        v.* = std.math.exp(v.* - max_val);
        sum += v.*;
    }
    for (arr) |*v| v.* /= sum;
}

test "model init and forward" {
    var rng = nn.tensor.createRng(42);
    var random = rng.random();

    const config = ModelConfig{
        .vocab_size = 100,
        .embed_dim = 32,
        .num_heads = 4,
        .num_layers = 2,
        .max_seq_len = 32,
        .ffn_ratio = 2,
    };

    var model = try LanguageModel.init(std.testing.allocator, config, &random);
    defer model.deinit();

    const ids = [_]u32{ 1, 5, 10, 15, 20 };
    var logits = try model.forward(&ids);
    defer logits.deinit();

    try std.testing.expectEqual(@as(usize, 5), logits.shape[0]);
    try std.testing.expectEqual(@as(usize, 100), logits.shape[1]);
}
