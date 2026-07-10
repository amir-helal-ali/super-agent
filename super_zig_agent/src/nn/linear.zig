// src/nn/linear.zig - طبقة Linear (Dense)
const std = @import("std");
const Tensor = @import("tensor.zig").Tensor;
const TensorError = @import("tensor.zig").TensorError;

/// طبقة خطية: y = x @ W^T + b
pub const Linear = struct {
    weight: Tensor, // [out_features, in_features]
    bias: Tensor, // [out_features]
    // تدرجات
    grad_weight: Tensor,
    grad_bias: Tensor,
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        in_features: usize,
        out_features: usize,
        rng: *std.Random,
    ) !Linear {
        var weight = try Tensor.init(allocator, &.{ out_features, in_features });
        weight.xavierInit(rng, in_features, out_features);

        const bias = try Tensor.init(allocator, &.{out_features});
        @memset(bias.data, 0);

        return .{
            .weight = weight,
            .bias = bias,
            .grad_weight = try Tensor.init(allocator, &.{ out_features, in_features }),
            .grad_bias = try Tensor.init(allocator, &.{out_features}),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Linear) void {
        self.weight.deinit();
        self.bias.deinit();
        self.grad_weight.deinit();
        self.grad_bias.deinit();
    }

    /// Forward: y = x @ W^T + b
    /// x: [batch, in_features] -> y: [batch, out_features]
    pub fn forward(self: *Linear, x: Tensor) !Tensor {
        if (x.ndim() != 2) return TensorError.InvalidShape;
        if (x.shape[1] != self.weight.shape[1]) return TensorError.ShapeMismatch;

        const batch = x.shape[0];
        const out_features = self.weight.shape[0];

        // x @ W^T
        var w_t = try Tensor.transpose(self.allocator, self.weight);
        defer w_t.deinit();

        var out = try Tensor.matmul(self.allocator, x, w_t);

        // إضافة bias
        var i: usize = 0;
        while (i < batch) : (i += 1) {
            var j: usize = 0;
            while (j < out_features) : (j += 1) {
                out.data[i * out_features + j] += self.bias.data[j];
            }
        }

        return out;
    }

    /// تحديث الأوزان بـ SGD
    pub fn update(self: *Linear, lr: f32) void {
        for (self.weight.data, self.grad_weight.data) |*w, *gw| {
            w.* -= lr * gw.*;
        }
        for (self.bias.data, self.grad_bias.data) |*b, *gb| {
            b.* -= lr * gb.*;
        }
    }

    /// صفّر التدرجات
    pub fn zeroGrad(self: *Linear) void {
        @memset(self.grad_weight.data, 0);
        @memset(self.grad_bias.data, 0);
    }

    /// حفظ
    pub fn save(self: Linear, dir: []const u8, name: []const u8) !void {
        var path_buf: [256]u8 = undefined;
        const w_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}_weight.bin", .{ dir, name });
        try self.weight.save(w_path);

        const b_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}_bias.bin", .{ dir, name });
        try self.bias.save(b_path);
    }
};

test "linear forward" {
    var rng = @import("tensor.zig").createRng(42);
    var random = rng.random();

    var linear = try Linear.init(std.testing.allocator, 3, 2, &random);
    defer linear.deinit();

    var x = try Tensor.init(std.testing.allocator, &.{ 1, 3 });
    defer x.deinit();
    x.data[0] = 1;
    x.data[1] = 2;
    x.data[2] = 3;

    var y = try linear.forward(x);
    defer y.deinit();

    try std.testing.expectEqual(@as(usize, 2), y.numel());
}
