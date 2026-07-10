// src/model.zig - النموذج اللغوي (Mini GPT) v2 - محسن
// زيادة الحجم + top-k sampling + repetition penalty
const std = @import("std");
const nn = @import("nn/mod.zig");
const Tokenizer = @import("tokenizer.zig").Tokenizer;

pub const ModelConfig = struct {
    vocab_size: usize = 8000,
    embed_dim: usize = 128, // زيادة من 256 لـ 128 (أفضل للأجهزة المنخفضة)
    num_heads: usize = 4,
    num_layers: usize = 2,
    max_seq_len: usize = 64,
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
    lm_head: nn.Linear,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: ModelConfig, rng: *std.Random) !LanguageModel {
        const blocks = try allocator.alloc(nn.TransformerBlock, config.num_layers);
        for (blocks) |*b| {
            b.* = try nn.TransformerBlock.init(
                allocator, config.embed_dim, config.num_heads, config.ffn_ratio, rng,
            );
        }

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

    pub fn forward(self: *LanguageModel, token_ids: []const u32) !nn.Tensor {
        var x = try self.token_embed.forward(token_ids);
        try self.pos_encoding.apply(&x);
        for (self.blocks) |*block| {
            const out = try block.forward(x);
            x.deinit();
            x = out;
        }
        try x.layerNorm(self.final_ln_gamma, self.final_ln_beta, 1e-5);
        const logits = try self.lm_head.forward(x);
        x.deinit();
        return logits;
    }

    /// توليد النص مع top-k sampling + repetition penalty
    pub fn generate(
        self: *LanguageModel,
        prompt_ids: []const u32,
        max_tokens: usize,
        temperature: f32,
        rng: *std.Random,
    ) !std.ArrayList(u32) {
        return self.generateAdvanced(prompt_ids, max_tokens, temperature, 40, 1.3, rng);
    }

    /// توليد متقدم مع top-k + repetition penalty
    pub fn generateAdvanced(
        self: *LanguageModel,
        prompt_ids: []const u32,
        max_tokens: usize,
        temperature: f32,
        top_k: usize,
        repetition_penalty: f32,
        rng: *std.Random,
    ) !std.ArrayList(u32) {
        var result = std.ArrayList(u32).init(self.allocator);
        try result.appendSlice(prompt_ids);

        // تتبع آخر 8 توكنز لمنع التكرار
        var recent_tokens = std.ArrayList(u32).init(self.allocator);
        defer recent_tokens.deinit();

        var step: usize = 0;
        while (step < max_tokens) : (step += 1) {
            const start_idx = if (result.items.len > self.config.max_seq_len)
                result.items.len - self.config.max_seq_len
            else
                0;
            const ctx = result.items[start_idx..];

            var logits = try self.forward(ctx);
            defer logits.deinit();

            const seq_len = logits.shape[0];
            const vocab_size = logits.shape[1];
            const last_logits = logits.data[(seq_len - 1) * vocab_size .. seq_len * vocab_size];

            // نسخ logits
            var probs = try self.allocator.alloc(f32, vocab_size);
            defer self.allocator.free(probs);

            // تطبيق repetition penalty
            for (last_logits, 0..) |v, i| {
                var penalty: f32 = 1.0;
                for (recent_tokens.items) |rt| {
                    if (rt == i) {
                        penalty = repetition_penalty;
                        break;
                    }
                }
                if (v > 0) {
                    probs[i] = v / penalty / temperature;
                } else {
                    probs[i] = v * penalty / temperature;
                }
            }

            // softmax
            softmaxInPlace(probs);

            // top-k filtering
            const k = @min(top_k, vocab_size);
            var top_indices = try self.allocator.alloc(usize, k);
            defer self.allocator.free(top_indices);
            var top_probs = try self.allocator.alloc(f32, k);
            defer self.allocator.free(top_probs);

            // إيجاد top-k
            var i: usize = 0;
            while (i < k) : (i += 1) {
                top_indices[i] = i;
                top_probs[i] = probs[i];
            }
            // ترتيب top-k
            var j: usize = k;
            while (j < vocab_size) : (j += 1) {
                // إيجاد أصغر عنصر في top-k
                var min_idx: usize = 0;
                var min_val: f32 = top_probs[0];
                var m: usize = 1;
                while (m < k) : (m += 1) {
                    if (top_probs[m] < min_val) {
                        min_val = top_probs[m];
                        min_idx = m;
                    }
                }
                // استبدال إذا كان الحالي أكبر
                if (probs[j] > min_val) {
                    top_probs[min_idx] = probs[j];
                    top_indices[min_idx] = j;
                }
            }

            // إعادة تطبيع top-k
            var top_sum: f32 = 0;
            for (top_probs) |p| top_sum += p;
            if (top_sum > 0) {
                for (top_probs) |*p| p.* /= top_sum;
            }

            // sampling من top-k
            const r = rng.float(f32);
            var cum: f32 = 0;
            var chosen: usize = top_indices[0];
            for (top_probs, 0..) |p, idx| {
                cum += p;
                if (r <= cum) {
                    chosen = top_indices[idx];
                    break;
                }
            }

            // إيقاف عند EOS
            if (chosen == Tokenizer.EOS) break;

            // تحديث recent_tokens
            if (recent_tokens.items.len >= 8) {
                _ = recent_tokens.orderedRemove(0);
            }
            try recent_tokens.append(@intCast(chosen));

            try result.append(@intCast(chosen));
        }
        return result;
    }

    pub fn loss(self: *LanguageModel, logits: nn.Tensor, targets: []const u32) !f32 {
        const seq_len = logits.shape[0];
        const vocab_size = logits.shape[1];
        var total_loss: f32 = 0;
        var i: usize = 0;
        while (i < seq_len) : (i += 1) {
            const row = logits.data[i * vocab_size .. (i + 1) * vocab_size];
            var max_val: f32 = row[0];
            for (row[1..]) |v| {
                if (v > max_val) max_val = v;
            }
            var sum: f32 = 0;
            for (row) |v| sum += std.math.exp(v - max_val);
            const log_sum = @log(sum) + max_val;
            const target = targets[i];
            if (target < vocab_size) {
                total_loss += log_sum - row[target];
            }
        }
        _ = self;
        return total_loss / @as(f32, @floatFromInt(seq_len));
    }

    pub fn save(self: *LanguageModel, dir: []const u8) !void {
        try std.fs.cwd().makePath(dir);
        var path_buf: [256]u8 = undefined;
        const config_path = try std.fmt.bufPrint(&path_buf, "{s}/config.json", .{dir});
        const file = try std.fs.cwd().createFile(config_path, .{});
        defer file.close();
        try file.writer().print(
            "{{\"vocab_size\":{d},\"embed_dim\":{d},\"num_heads\":{d},\"num_layers\":{d},\"max_seq_len\":{d},\"ffn_ratio\":{d}}}",
            .{ self.config.vocab_size, self.config.embed_dim, self.config.num_heads, self.config.num_layers, self.config.max_seq_len, self.config.ffn_ratio },
        );

        const embed_path = try std.fmt.bufPrint(&path_buf, "{s}/token_embed.bin", .{dir});
        try self.token_embed.save(embed_path);

        for (self.blocks, 0..) |block, i| {
            var name_buf: [64]u8 = undefined;
            try block.attn.w_q.save(dir, try std.fmt.bufPrint(&name_buf, "block_{d}_wq", .{i}));
            try block.attn.w_k.save(dir, try std.fmt.bufPrint(&name_buf, "block_{d}_wk", .{i}));
            try block.attn.w_v.save(dir, try std.fmt.bufPrint(&name_buf, "block_{d}_wv", .{i}));
            try block.attn.w_o.save(dir, try std.fmt.bufPrint(&name_buf, "block_{d}_wo", .{i}));
            try block.ffn1.save(dir, try std.fmt.bufPrint(&name_buf, "block_{d}_ffn1", .{i}));
            try block.ffn2.save(dir, try std.fmt.bufPrint(&name_buf, "block_{d}_ffn2", .{i}));
        }

        try self.lm_head.save(dir, "lm_head");
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
