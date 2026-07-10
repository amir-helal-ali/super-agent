// src/nn/autograd.zig - نظام التمايز التلقائي
const std = @import("std");
const Tensor = @import("tensor.zig").Tensor;
const TensorError = @import("tensor.zig").TensorError;

pub const Var = struct {
    value: Tensor,
    grad: Tensor,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, value: Tensor) !Var {
        const grad = try Tensor.init(allocator, value.shape);
        @memset(grad.data, 0);
        return .{ .value = value, .grad = grad, .allocator = allocator };
    }

    pub fn deinit(self: *Var) void {
        self.value.deinit();
        self.grad.deinit();
    }

    pub fn zeroGrad(self: *Var) void {
        @memset(self.grad.data, 0);
    }
};

pub const Node = struct {
    inputs: []*Var,
    output: *Var,
    backward_fn: *const fn (node: *const Node, ctx: *Context) anyerror!void,
    params: ?*anyopaque = null,
};

pub const Context = struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayList(Node),

    pub fn init(allocator: std.mem.Allocator) Context {
        return .{ .allocator = allocator, .nodes = std.ArrayList(Node).init(allocator) };
    }

    pub fn deinit(self: *Context) void {
        self.reset();
        self.nodes.deinit();
    }

    pub fn reset(self: *Context) void {
        for (self.nodes.items) |*node| {
            node.output.deinit();
            self.allocator.destroy(node.output);
            if (node.inputs.len > 0) self.allocator.free(node.inputs);
        }
        self.nodes.clearRetainingCapacity();
    }

    pub fn track(self: *Context, node: Node) !void {
        try self.nodes.append(node);
    }
};

pub const Ops = struct {
    fn makeNode(
        ctx: *Context,
        inputs: []const *Var,
        output_value: Tensor,
        backward_fn: *const fn (node: *const Node, ctx: *Context) anyerror!void,
        params: ?*anyopaque,
    ) !*Var {
        const inputs_copy = try ctx.allocator.alloc(*Var, inputs.len);
        @memcpy(inputs_copy, inputs);
        const output = try ctx.allocator.create(Var);
        output.* = try Var.init(ctx.allocator, output_value);
        try ctx.track(.{
            .inputs = inputs_copy,
            .output = output,
            .backward_fn = backward_fn,
            .params = params,
        });
        return output;
    }

    pub fn add(ctx: *Context, a: *Var, b: *Var) !*Var {
        if (a.value.data.len != b.value.data.len) return TensorError.ShapeMismatch;
        const out = try Tensor.init(ctx.allocator, a.value.shape);
        try Tensor.add(@constCast(&out), a.value, b.value);
        return makeNode(ctx, &.{ a, b }, out, addBackward, null);
    }

    fn addBackward(node: *const Node, _: *Context) !void {
        const a = node.inputs[0];
        const b = node.inputs[1];
        const out = node.output;
        for (a.grad.data, out.grad.data) |*ag, *og| ag.* += og.*;
        for (b.grad.data, out.grad.data) |*bg, *og| bg.* += og.*;
    }

    pub fn matmul(ctx: *Context, a: *Var, b: *Var) !*Var {
        if (a.value.ndim() != 2 or b.value.ndim() != 2) return TensorError.InvalidShape;
        if (a.value.shape[1] != b.value.shape[0]) return TensorError.ShapeMismatch;
        const out = try Tensor.matmul(ctx.allocator, a.value, b.value);
        return makeNode(ctx, &.{ a, b }, out, matmulBackward, null);
    }

    fn matmulBackward(node: *const Node, ctx: *Context) !void {
        const a = node.inputs[0];
        const b = node.inputs[1];
        const out = node.output;
        var b_t = try Tensor.transpose(ctx.allocator, b.value);
        defer b_t.deinit();
        var da = try Tensor.matmul(ctx.allocator, out.grad, b_t);
        defer da.deinit();
        for (a.grad.data, da.data) |*ag, *g| ag.* += g.*;
        var a_t = try Tensor.transpose(ctx.allocator, a.value);
        defer a_t.deinit();
        var db = try Tensor.matmul(ctx.allocator, a_t, out.grad);
        defer db.deinit();
        for (b.grad.data, db.data) |*bg, *g| bg.* += g.*;
    }

    pub fn gelu(ctx: *Context, a: *Var) !*Var {
        var out = try Tensor.init(ctx.allocator, a.value.shape);
        @memcpy(out.data, a.value.data);
        out.gelu();
        return makeNode(ctx, &.{a}, out, geluBackward, null);
    }

    fn geluBackward(node: *const Node, _: *Context) !void {
        const a = node.inputs[0];
        const out = node.output;
        const sqrt_2_over_pi: f32 = 0.7978845608;
        for (a.grad.data, a.value.data, out.grad.data) |*ag, *av, *og| {
            const x = av.*;
            const tanh_arg = sqrt_2_over_pi * (x + 0.044715 * x * x * x);
            const tanh_val = std.math.tanh(tanh_arg);
            const sech2 = 1.0 - tanh_val * tanh_val;
            const deriv = 0.5 * (1.0 + tanh_val + x * sech2 * sqrt_2_over_pi * (1.0 + 3.0 * 0.044715 * x * x));
            ag.* += og.* * deriv;
        }
    }

    pub fn softmax(ctx: *Context, a: *Var) !*Var {
        var out = try Tensor.init(ctx.allocator, a.value.shape);
        @memcpy(out.data, a.value.data);
        out.softmax();
        return makeNode(ctx, &.{a}, out, softmaxBackward, null);
    }

    fn softmaxBackward(node: *const Node, _: *Context) !void {
        const a = node.inputs[0];
        const out = node.output;
        if (out.value.ndim() != 2) return;
        const rows = out.value.shape[0];
        const cols = out.value.shape[1];
        var i: usize = 0;
        while (i < rows) : (i += 1) {
            const s_row = out.value.data[i * cols .. (i + 1) * cols];
            const grad_out = out.grad.data[i * cols .. (i + 1) * cols];
            const grad_in = a.grad.data[i * cols .. (i + 1) * cols];
            var dot: f32 = 0;
            for (grad_out, s_row) |g, s| dot += g * s;
            for (grad_in, grad_out, s_row) |*gi, go, s| gi.* += s * (go - dot);
        }
    }

    pub fn addBias(ctx: *Context, a: *Var, b: *Var) !*Var {
        if (a.value.ndim() != 2 or b.value.ndim() != 1) return TensorError.InvalidShape;
        if (a.value.shape[1] != b.value.shape[0]) return TensorError.ShapeMismatch;
        const out = try Tensor.init(ctx.allocator, a.value.shape);
        const rows = a.value.shape[0];
        const cols = a.value.shape[1];
        var i: usize = 0;
        while (i < rows) : (i += 1) {
            var j: usize = 0;
            while (j < cols) : (j += 1) {
                out.data[i * cols + j] = a.value.data[i * cols + j] + b.value.data[j];
            }
        }
        return makeNode(ctx, &.{ a, b }, out, addBiasBackward, null);
    }

    fn addBiasBackward(node: *const Node, _: *Context) !void {
        const a = node.inputs[0];
        const b = node.inputs[1];
        const out = node.output;
        const rows = a.value.shape[0];
        const cols = a.value.shape[1];
        for (a.grad.data, out.grad.data) |*ag, *og| ag.* += og.*;
        var j: usize = 0;
        while (j < cols) : (j += 1) {
            var sum: f32 = 0;
            var i: usize = 0;
            while (i < rows) : (i += 1) sum += out.grad.data[i * cols + j];
            b.grad.data[j] += sum;
        }
    }

    pub const LossResult = struct {
        loss: *Var,
        value: f32,
    };

    pub fn crossEntropyLoss(ctx: *Context, logits: *Var, targets: []const u32) !LossResult {
        if (logits.value.ndim() != 2) return TensorError.InvalidShape;
        const batch = logits.value.shape[0];
        const vocab = logits.value.shape[1];
        if (targets.len != batch) return TensorError.ShapeMismatch;

        var total_loss: f32 = 0;
        const probs = try ctx.allocator.alloc(f32, batch * vocab);
        var i: usize = 0;
        while (i < batch) : (i += 1) {
            const row = logits.value.data[i * vocab .. (i + 1) * vocab];
            const prob_row = probs[i * vocab .. (i + 1) * vocab];
            var max_val: f32 = row[0];
            for (row[1..]) |v| {
                if (v > max_val) max_val = v;
            }
            var sum: f32 = 0;
            for (row, 0..) |v, j| {
                prob_row[j] = std.math.exp(v - max_val);
                sum += prob_row[j];
            }
            for (prob_row) |*p| p.* /= sum;
            const target = targets[i];
            if (target < vocab) total_loss += -@log(probs[i * vocab + target] + 1e-10);
        }
        const avg_loss = total_loss / @as(f32, @floatFromInt(batch));
        const loss_value = try Tensor.init(ctx.allocator, &.{1});
        loss_value.data[0] = avg_loss;

        const cache = try ctx.allocator.create(CELossCache);
        cache.* = .{ .probs = probs, .targets = targets, .batch = batch, .vocab = vocab };
        const output = try makeNode(ctx, &.{logits}, loss_value, ceLossBackward, @ptrCast(cache));
        return .{ .loss = output, .value = avg_loss };
    }

    const CELossCache = struct {
        probs: []f32,
        targets: []const u32,
        batch: usize,
        vocab: usize,
    };

    fn ceLossBackward(node: *const Node, ctx: *Context) !void {
        const logits = node.inputs[0];
        const cache: *CELossCache = @ptrCast(@alignCast(node.params.?));
        const grad_scale = node.output.grad.data[0] / @as(f32, @floatFromInt(cache.batch));
        var i: usize = 0;
        while (i < cache.batch) : (i += 1) {
            const prob_row = cache.probs[i * cache.vocab .. (i + 1) * cache.vocab];
            const grad_row = logits.grad.data[i * cache.vocab .. (i + 1) * cache.vocab];
            const target = cache.targets[i];
            for (prob_row, 0..) |p, j| {
                const t: f32 = if (j == target) 1.0 else 0.0;
                grad_row[j] += grad_scale * (p - t);
            }
        }
        ctx.allocator.free(cache.probs);
        ctx.allocator.destroy(cache);
    }
};

pub fn backward(ctx: *Context) !void {
    var i: usize = ctx.nodes.items.len;
    while (i > 0) {
        i -= 1;
        try ctx.nodes.items[i].backward_fn(&ctx.nodes.items[i], ctx);
    }
}
