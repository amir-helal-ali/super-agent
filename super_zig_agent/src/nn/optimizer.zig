// src/nn/optimizer.zig - Adam optimizer + gradient clipping
const std = @import("std");
const Var = @import("autograd.zig").Var;

pub const Adam = struct {
    learning_rate: f32,
    beta1: f32,
    beta2: f32,
    eps: f32,
    m: std.AutoHashMap(usize, []f32),
    v: std.AutoHashMap(usize, []f32),
    t: std.AutoHashMap(usize, u32),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, lr: f32) Adam {
        return .{
            .learning_rate = lr, .beta1 = 0.9, .beta2 = 0.999, .eps = 1e-8,
            .m = std.AutoHashMap(usize, []f32).init(allocator),
            .v = std.AutoHashMap(usize, []f32).init(allocator),
            .t = std.AutoHashMap(usize, u32).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Adam) void {
        var iter_m = self.m.iterator();
        while (iter_m.next()) |entry| self.allocator.free(entry.value_ptr.*);
        self.m.deinit();
        var iter_v = self.v.iterator();
        while (iter_v.next()) |entry| self.allocator.free(entry.value_ptr.*);
        self.v.deinit();
        self.t.deinit();
    }

    pub fn step(self: *Adam, params: *Var, id: usize) !void {
        if (self.m.get(id) == null) {
            const new_m = try self.allocator.alloc(f32, params.value.data.len);
            @memset(new_m, 0);
            try self.m.put(id, new_m);
        }
        if (self.v.get(id) == null) {
            const new_v = try self.allocator.alloc(f32, params.value.data.len);
            @memset(new_v, 0);
            try self.v.put(id, new_v);
        }
        if (self.t.get(id) == null) try self.t.put(id, 0);
        const m = self.m.get(id).?;
        const v = self.v.get(id).?;
        const t = self.t.get(id).?;
        const new_t = t + 1;
        try self.t.put(id, new_t);
        const beta1_t = std.math.pow(f32, self.beta1, @as(f32, @floatFromInt(new_t)));
        const beta2_t = std.math.pow(f32, self.beta2, @as(f32, @floatFromInt(new_t)));
        for (params.value.data, params.grad.data, m, v) |*p, *g, *m_val, *v_val| {
            m_val.* = self.beta1 * m_val.* + (1.0 - self.beta1) * g.*;
            v_val.* = self.beta2 * v_val.* + (1.0 - self.beta2) * g.* * g.*;
            const m_hat = m_val.* / (1.0 - beta1_t);
            const v_hat = v_val.* / (1.0 - beta2_t);
            p.* -= self.learning_rate * m_hat / (std.math.sqrt(v_hat) + self.eps);
        }
    }
};

pub fn clipGradients(grad: []f32, max_norm: f32) void {
    var norm: f32 = 0;
    for (grad) |g| norm += g * g;
    norm = std.math.sqrt(norm);
    if (norm > max_norm) {
        const scale = max_norm / (norm + 1e-6);
        for (grad) |*g| g.* *= scale;
    }
}
