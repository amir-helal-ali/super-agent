// src/nn/attention.zig - طبقة الانتباه الذاتي (Self-Attention)
// مصممة لتكون خفيفة - Multi-Head Attention بدون GPU
const std = @import("std");
const Tensor = @import("tensor.zig").Tensor;
const TensorError = @import("tensor.zig").TensorError;
const Linear = @import("linear.zig").Linear;

pub const MultiHeadAttention = struct {
    num_heads: usize,
    head_dim: usize,
    embed_dim: usize,

    w_q: Linear,
    w_k: Linear,
    w_v: Linear,
    w_o: Linear,

    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        embed_dim: usize,
        num_heads: usize,
        rng: *std.Random,
    ) !MultiHeadAttention {
        if (embed_dim % num_heads != 0) return TensorError.InvalidShape;
        const head_dim = embed_dim / num_heads;

        return .{
            .num_heads = num_heads,
            .head_dim = head_dim,
            .embed_dim = embed_dim,
            .w_q = try Linear.init(allocator, embed_dim, embed_dim, rng),
            .w_k = try Linear.init(allocator, embed_dim, embed_dim, rng),
            .w_v = try Linear.init(allocator, embed_dim, embed_dim, rng),
            .w_o = try Linear.init(allocator, embed_dim, embed_dim, rng),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MultiHeadAttention) void {
        self.w_q.deinit();
        self.w_k.deinit();
        self.w_v.deinit();
        self.w_o.deinit();
    }

    /// Forward
    /// x: [seq_len, embed_dim] -> out: [seq_len, embed_dim]
    pub fn forward(self: *MultiHeadAttention, x: Tensor) !Tensor {
        const seq_len = x.shape[0];

        // Q, K, V
        var q = try self.w_q.forward(x);
        defer q.deinit();
        var k = try self.w_k.forward(x);
        defer k.deinit();
        var v = try self.w_v.forward(x);
        defer v.deinit();

        // إعادة تشكيل إلى [num_heads, seq_len, head_dim]
        // ثم حساب attention لكل head
        var concat = try Tensor.init(self.allocator, &.{ seq_len, self.embed_dim });
        defer concat.deinit();

        const scale = 1.0 / std.math.sqrt(@as(f32, @floatFromInt(self.head_dim)));

        var h: usize = 0;
        while (h < self.num_heads) : (h += 1) {
            // استخراج head h من Q, K, V
            var head_q = try self.extractHead(q, h);
            defer head_q.deinit();
            var head_k = try self.extractHead(k, h);
            defer head_k.deinit();
            var head_v = try self.extractHead(v, h);
            defer head_v.deinit();

            // scores = Q @ K^T * scale
            var k_t = try Tensor.transpose(self.allocator, head_k);
            defer k_t.deinit();
            var scores = try Tensor.matmul(self.allocator, head_q, k_t);
            defer scores.deinit();
            // scale
            for (scores.data) |*s| s.* *= scale;

            // causal mask (للتدريب التلقائي على اللغة)
            applyCausalMask(&scores);

            // softmax
            scores.softmax();

            // attention = scores @ V
            var attention = try Tensor.matmul(self.allocator, scores, head_v);
            defer attention.deinit();

            // نسخ لـ concat
            const embed_offset = h * self.head_dim;
            var i: usize = 0;
            while (i < seq_len) : (i += 1) {
                var j: usize = 0;
                while (j < self.head_dim) : (j += 1) {
                    concat.data[i * self.embed_dim + embed_offset + j] =
                        attention.data[i * self.head_dim + j];
                }
            }
        }

        // output projection
        const out = try self.w_o.forward(concat);
        return out;
    }

    /// استخراج head h من tensor [seq_len, embed_dim]
    /// ينتج [seq_len, head_dim]
    fn extractHead(self: *MultiHeadAttention, t: Tensor, head: usize) !Tensor {
        const seq_len = t.shape[0];
        var out = try Tensor.init(self.allocator, &.{ seq_len, self.head_dim });
        const offset = head * self.head_dim;
        var i: usize = 0;
        while (i < seq_len) : (i += 1) {
            var j: usize = 0;
            while (j < self.head_dim) : (j += 1) {
                out.data[i * self.head_dim + j] =
                    t.data[i * self.embed_dim + offset + j];
            }
        }
        return out;
    }

    fn applyCausalMask(scores: *Tensor) void {
        if (scores.ndim() != 2) return;
        const rows = scores.shape[0];
        const cols = scores.shape[1];
        var i: usize = 0;
        while (i < rows) : (i += 1) {
            var j: usize = i + 1;
            while (j < cols) : (j += 1) {
                scores.data[i * cols + j] = -1e9;
            }
        }
    }
};

test "attention forward" {
    var rng = @import("tensor.zig").createRng(42);
    var random = rng.random();

    var attn = try MultiHeadAttention.init(std.testing.allocator, 32, 4, &random);
    defer attn.deinit();

    var x = try Tensor.init(std.testing.allocator, &.{ 8, 32 });
    defer x.deinit();
    x.randn(&random, 0, 1);

    var y = try attn.forward(x);
    defer y.deinit();

    try std.testing.expectEqual(@as(usize, 8), y.shape[0]);
    try std.testing.expectEqual(@as(usize, 32), y.shape[1]);
}
