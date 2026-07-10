// src/nn/transformer.zig - كتلة Transformer كاملة
const std = @import("std");
const Tensor = @import("tensor.zig").Tensor;
const TensorError = @import("tensor.zig").TensorError;
const Linear = @import("linear.zig").Linear;
const MultiHeadAttention = @import("attention.zig").MultiHeadAttention;

/// كتلة Transformer: Attention + FFN + LayerNorm + Residual
pub const TransformerBlock = struct {
    attn: MultiHeadAttention,
    ln1_gamma: Tensor,
    ln1_beta: Tensor,
    ln2_gamma: Tensor,
    ln2_beta: Tensor,
    ffn1: Linear, // embed -> 4*embed
    ffn2: Linear, // 4*embed -> embed
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        embed_dim: usize,
        num_heads: usize,
        ffn_ratio: usize,
        rng: *std.Random,
    ) !TransformerBlock {
        const ffn_dim = embed_dim * ffn_ratio;
        return .{
            .attn = try MultiHeadAttention.init(allocator, embed_dim, num_heads, rng),
            .ln1_gamma = try makeOnes(allocator, embed_dim),
            .ln1_beta = try makeZeros(allocator, embed_dim),
            .ln2_gamma = try makeOnes(allocator, embed_dim),
            .ln2_beta = try makeZeros(allocator, embed_dim),
            .ffn1 = try Linear.init(allocator, embed_dim, ffn_dim, rng),
            .ffn2 = try Linear.init(allocator, ffn_dim, embed_dim, rng),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TransformerBlock) void {
        self.attn.deinit();
        self.ln1_gamma.deinit();
        self.ln1_beta.deinit();
        self.ln2_gamma.deinit();
        self.ln2_beta.deinit();
        self.ffn1.deinit();
        self.ffn2.deinit();
    }

    /// Forward
    /// x: [seq_len, embed_dim] -> out: [seq_len, embed_dim]
    pub fn forward(self: *TransformerBlock, x: Tensor) !Tensor {
        // Pre-LN: x_norm = LN(x); attn_out = x + Attn(x_norm)
        var x_norm = try x.clone();
        defer x_norm.deinit();
        try x_norm.layerNorm(self.ln1_gamma, self.ln1_beta, 1e-5);

        var attn_out = try self.attn.forward(x_norm);
        defer attn_out.deinit();

        // residual 1
        var h = try Tensor.init(self.allocator, x.shape);
        try Tensor.add(&h, x, attn_out);
        defer h.deinit();

        // FFN: x_norm2 = LN(h); ffn_out = h + FFN(x_norm2)
        var h_norm = try h.clone();
        defer h_norm.deinit();
        try h_norm.layerNorm(self.ln2_gamma, self.ln2_beta, 1e-5);

        var ffn_hidden = try self.ffn1.forward(h_norm);
        defer ffn_hidden.deinit();
        ffn_hidden.gelu(); // GELU activation
        var ffn_out = try self.ffn2.forward(ffn_hidden);
        defer ffn_out.deinit();

        // residual 2
        var out = try Tensor.init(self.allocator, x.shape);
        try Tensor.add(&out, h, ffn_out);
        return out;
    }
};

fn makeOnes(allocator: std.mem.Allocator, size: usize) !Tensor {
    const t = try Tensor.init(allocator, &.{size});
    @memset(t.data, 1.0);
    return t;
}

fn makeZeros(allocator: std.mem.Allocator, size: usize) !Tensor {
    const t = try Tensor.init(allocator, &.{size});
    @memset(t.data, 0.0);
    return t;
}
