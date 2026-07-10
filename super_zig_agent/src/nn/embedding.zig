// src/nn/embedding.zig - طبقة Embedding
const std = @import("std");
const Tensor = @import("tensor.zig").Tensor;
const TensorError = @import("tensor.zig").TensorError;

pub const Embedding = struct {
    weight: Tensor, // [vocab_size, embed_dim]
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        vocab_size: usize,
        embed_dim: usize,
        rng: *std.Random,
    ) !Embedding {
        var weight = try Tensor.init(allocator, &.{ vocab_size, embed_dim });
        weight.randn(rng, 0, 0.02);
        return .{ .weight = weight, .allocator = allocator };
    }

    pub fn deinit(self: *Embedding) void {
        self.weight.deinit();
    }

    /// Forward: تحويل IDs إلى embeddings
    /// token_ids: [seq_len] -> embeddings: [seq_len, embed_dim]
    pub fn forward(self: *Embedding, token_ids: []const u32) !Tensor {
        const embed_dim = self.weight.shape[1];
        var out = try Tensor.init(self.allocator, &.{ token_ids.len, embed_dim });
        for (token_ids, 0..) |id, i| {
            if (id >= self.weight.shape[0]) return TensorError.OutOfBounds;
            const src = self.weight.data[id * embed_dim .. (id + 1) * embed_dim];
            const dst = out.data[i * embed_dim .. (i + 1) * embed_dim];
            @memcpy(dst, src);
        }
        return out;
    }

    /// حفظ
    pub fn save(self: Embedding, path: []const u8) !void {
        try self.weight.save(path);
    }

    pub fn load(allocator: std.mem.Allocator, path: []const u8) !Embedding {
        const weight = try Tensor.load(allocator, path);
        return .{ .weight = weight, .allocator = allocator };
    }
};

/// Positional Encoding - ثابت (لا يُتدرب)
pub const PositionalEncoding = struct {
    encoding: Tensor, // [max_len, embed_dim]
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, max_len: usize, embed_dim: usize) !PositionalEncoding {
        var encoding = try Tensor.init(allocator, &.{ max_len, embed_dim });
        const pi_val: f32 = 3.14159265358979323846;
        _ = pi_val;

        var pos: usize = 0;
        while (pos < max_len) : (pos += 1) {
            var i: usize = 0;
            while (i < embed_dim) : (i += 2) {
                const angle = @as(f32, @floatFromInt(pos)) *
                    std.math.pow(f32, 10000.0, -@as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(embed_dim)));
                encoding.data[pos * embed_dim + i] = std.math.sin(angle);
                if (i + 1 < embed_dim) {
                    encoding.data[pos * embed_dim + i + 1] = std.math.cos(angle);
                }
            }
        }
        return .{ .encoding = encoding, .allocator = allocator };
    }

    pub fn deinit(self: *PositionalEncoding) void {
        self.encoding.deinit();
    }

    /// إضافة positional encoding
    pub fn apply(self: *PositionalEncoding, x: *Tensor) !void {
        if (x.ndim() != 2) return TensorError.InvalidShape;
        const seq_len = x.shape[0];
        if (seq_len > self.encoding.shape[0]) return TensorError.OutOfBounds;

        for (x.data, 0..) |*v, idx| {
            v.* += self.encoding.data[idx];
        }
    }
};
