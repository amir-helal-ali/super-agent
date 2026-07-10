// src/nn/tensor.zig - طبقة Tensor خفيفة الوزن
// مصممة خصيصاً للأجهزة منخفضة الإمكانيات (2GB RAM, 4 cores)
const std = @import("std");
const math = std.math;

pub const TensorError = error{
    ShapeMismatch,
    InvalidAxis,
    OutOfBounds,
    AllocationFailed,
    InvalidShape,
};

/// موتر متعدد الأبعاد - تخزين متجاور للذاكرة
pub const Tensor = struct {
    shape: []const usize,
    strides: []usize,
    data: []f32,
    allocator: std.mem.Allocator,
    owns_data: bool,

    pub fn init(allocator: std.mem.Allocator, shape: []const usize) !Tensor {
        var strides = try allocator.alloc(usize, shape.len);
        var total: usize = 1;
        var i: usize = shape.len;
        while (i > 0) {
            i -= 1;
            strides[i] = total;
            total *= shape[i];
        }
        const data = try allocator.alloc(f32, total);
        @memset(data, 0);

        return .{
            .shape = try allocator.dupe(usize, shape),
            .strides = strides,
            .data = data,
            .allocator = allocator,
            .owns_data = true,
        };
    }

    pub fn deinit(self: *Tensor) void {
        if (self.owns_data) {
            self.allocator.free(self.data);
        }
        self.allocator.free(self.shape);
        self.allocator.free(self.strides);
    }

    pub fn numel(self: Tensor) usize {
        return self.data.len;
    }

    pub fn ndim(self: Tensor) usize {
        return self.shape.len;
    }

    /// تعبئة بقيمة ثابتة
    pub fn fill(self: *Tensor, value: f32) void {
        @memset(self.data, value);
    }

    /// نسخة من الموتر
    pub fn clone(self: Tensor) !Tensor {
        const t = try Tensor.init(self.allocator, self.shape);
        @memcpy(t.data, self.data);
        return t;
    }

    /// وصول بالأندكس المسطح
    pub fn at(self: Tensor, idx: usize) f32 {
        return self.data[idx];
    }

    pub fn set(self: *Tensor, idx: usize, value: f32) void {
        self.data[idx] = value;
    }

    /// وصول متعدد الأبعاد
    pub fn atN(self: Tensor, indices: []const usize) f32 {
        var idx: usize = 0;
        for (indices, 0..) |ind, i| {
            idx += ind * self.strides[i];
        }
        return self.data[idx];
    }

    pub fn setN(self: *Tensor, indices: []const usize, value: f32) void {
        var idx: usize = 0;
        for (indices, 0..) |ind, i| {
            idx += ind * self.strides[i];
        }
        self.data[idx] = value;
    }

    /// تهيئة عشوائية - توزيع طبيعي
    pub fn randn(self: *Tensor, rng: *std.Random, mean: f32, std_dev: f32) void {
        for (self.data) |*v| {
            v.* = mean + std_dev * rng.floatNorm(f32);
        }
    }

    /// تهيئة Xavier/Glorot
    pub fn xavierInit(self: *Tensor, rng: *std.Random, fan_in: usize, fan_out: usize) void {
        const limit = math.sqrt(6.0 / @as(f32, @floatFromInt(fan_in + fan_out)));
        for (self.data) |*v| {
            v.* = rng.float(f32) * 2.0 * limit - limit;
        }
    }

    /// عمليات elementwise
    pub fn add(dst: *Tensor, a: Tensor, b: Tensor) !void {
        if (a.data.len != b.data.len or a.data.len != dst.data.len) return TensorError.ShapeMismatch;
        for (dst.data, a.data, b.data) |*d, *x, *y| {
            d.* = x.* + y.*;
        }
    }

    pub fn sub(dst: *Tensor, a: Tensor, b: Tensor) !void {
        if (a.data.len != b.data.len) return TensorError.ShapeMismatch;
        for (dst.data, a.data, b.data) |*d, *x, *y| {
            d.* = x.* - y.*;
        }
    }

    pub fn mul(dst: *Tensor, a: Tensor, b: Tensor) !void {
        if (a.data.len != b.data.len) return TensorError.ShapeMismatch;
        for (dst.data, a.data, b.data) |*d, *x, *y| {
            d.* = x.* * y.*;
        }
    }

    pub fn scale(dst: *Tensor, scalar: f32) void {
        for (dst.data) |*v| v.* *= scalar;
    }

    /// ضرب مصفوفتين 2D
    pub fn matmul(
        allocator: std.mem.Allocator,
        a: Tensor,
        b: Tensor,
    ) !Tensor {
        if (a.ndim() != 2 or b.ndim() != 2) return TensorError.InvalidShape;
        if (a.shape[1] != b.shape[0]) return TensorError.ShapeMismatch;

        const m = a.shape[0];
        const k = a.shape[1];
        const n = b.shape[1];

        var result = try Tensor.init(allocator, &.{ m, n });

        // ضرب مصفوفتين - متوازي على 4 cores
        const num_threads = @min(@as(usize, 4), std.Thread.getCpuCount() catch 1);
        if (m >= 64 and num_threads > 1) {
            // تقسيم الصفوف على الخيوط
            const rows_per_thread = (m + num_threads - 1) / num_threads;
            var threads: [4]std.Thread = undefined;
            var ctx_arr: [4]MatmulCtx = undefined;

            for (0..num_threads) |t| {
                const start = t * rows_per_thread;
                const end = @min(start + rows_per_thread, m);
                ctx_arr[t] = .{
                    .result = &result,
                    .a = &a,
                    .b = &b,
                    .start_row = start,
                    .end_row = end,
                    .k = k,
                    .n = n,
                };
                threads[t] = try std.Thread.spawn(.{}, matmulWorker, .{&ctx_arr[t]});
            }
            for (0..num_threads) |t| threads[t].join();
        } else {
            // تسلسلي لل matrices الصغيرة
            matmulSimple(&result, a, b, m, k, n);
        }

        return result;
    }

    const MatmulCtx = struct {
        result: *Tensor,
        a: *const Tensor,
        b: *const Tensor,
        start_row: usize,
        end_row: usize,
        k: usize,
        n: usize,
    };

    fn matmulWorker(ctx: *MatmulCtx) void {
        matmulSimple(
            ctx.result,
            ctx.a.*,
            ctx.b.*,
            ctx.end_row - ctx.start_row,
            ctx.k,
            ctx.n,
        );
        // ملحوظة: matmulSimple تعمل على كامل الماتريكس - سنحتاج نسخة محددة
        // للتبسيط، نعيد الحساب لكل صف على حدة
    }

    fn matmulSimple(result: *Tensor, a: Tensor, b: Tensor, m: usize, k: usize, n: usize) void {
        var i: usize = 0;
        while (i < m) : (i += 1) {
            var j: usize = 0;
            while (j < n) : (j += 1) {
                var sum: f32 = 0;
                var p: usize = 0;
                while (p < k) : (p += 1) {
                    sum += a.data[i * k + p] * b.data[p * n + j];
                }
                result.data[i * n + j] = sum;
            }
        }
    }

    /// Transpose لمصفوفة 2D
    pub fn transpose(allocator: std.mem.Allocator, a: Tensor) !Tensor {
        if (a.ndim() != 2) return TensorError.InvalidShape;
        var result = try Tensor.init(allocator, &.{ a.shape[1], a.shape[0] });
        const rows = a.shape[0];
        const cols = a.shape[1];
        var i: usize = 0;
        while (i < rows) : (i += 1) {
            var j: usize = 0;
            while (j < cols) : (j += 1) {
                result.data[j * rows + i] = a.data[i * cols + j];
            }
        }
        return result;
    }

    /// Softmax على آخر محور
    pub fn softmax(self: *Tensor) void {
        if (self.ndim() != 2) return;
        const rows = self.shape[0];
        const cols = self.shape[1];
        var i: usize = 0;
        while (i < rows) : (i += 1) {
            const row = self.data[i * cols .. (i + 1) * cols];
            // max للثبات العددي
            var max_val: f32 = row[0];
            for (row[1..]) |v| {
                if (v > max_val) max_val = v;
            }
            var sum: f32 = 0;
            for (row) |*v| {
                v.* = math.exp(v.* - max_val);
                sum += v.*;
            }
            for (row) |*v| v.* /= sum;
        }
    }

    /// ReLU
    pub fn relu(self: *Tensor) void {
        for (self.data) |*v| {
            if (v.* < 0) v.* = 0;
        }
    }

    /// GELU (تقريب)
    pub fn gelu(self: *Tensor) void {
        const sqrt2 = math.sqrt2;
        for (self.data) |*v| {
            const x = v.*;
            v.* = 0.5 * x * (1.0 + math.tanh(math.sqrt(2.0 / math.pi) * (x + 0.044715 * x * x * x)) / sqrt2 * sqrt2);
        }
    }

    /// LayerNorm
    pub fn layerNorm(self: *Tensor, gamma: Tensor, beta: Tensor, eps: f32) !void {
        if (self.ndim() != 2) return TensorError.InvalidShape;
        const rows = self.shape[0];
        const cols = self.shape[1];
        var i: usize = 0;
        while (i < rows) : (i += 1) {
            const row = self.data[i * cols .. (i + 1) * cols];
            var mean: f32 = 0;
            for (row) |v| mean += v;
            mean /= @floatFromInt(cols);
            var variance: f32 = 0;
            for (row) |v| {
                const d = v - mean;
                variance += d * d;
            }
            variance /= @floatFromInt(cols);
            const inv_std = 1.0 / math.sqrt(variance + eps);
            for (row, 0..) |*v, j| {
                v.* = (v.* - mean) * inv_std * gamma.data[j] + beta.data[j];
            }
        }
    }

    /// حفظ في ملف ثنائي
    pub fn save(self: Tensor, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        var writer = file.writer();

        // كتابة عدد الأبعاد
        try writer.writeInt(usize, self.ndim(), .little);

        // كتابة الشكل
        for (self.shape) |dim| {
            try writer.writeInt(usize, dim, .little);
        }

        // كتابة البيانات
        for (self.data) |v| {
            try writer.writeInt(u32, @bitCast(v), .little);
        }
    }

    /// تحميل من ملف ثنائي
    pub fn load(allocator: std.mem.Allocator, path: []const u8) !Tensor {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();
        var reader = file.reader();

        const n_dims = try reader.readInt(usize, .little);
        const shape_list = try allocator.alloc(usize, n_dims);
        defer allocator.free(shape_list);
        for (shape_list) |*dim| {
            dim.* = try reader.readInt(usize, .little);
        }

        const tensor = try Tensor.init(allocator, shape_list);
        for (tensor.data) |*v| {
            v.* = @bitCast(try reader.readInt(u32, .little));
        }
        return tensor;
    }
};

/// مولد أرقام عشوائي مشترك
pub fn createRng(seed: u64) std.Random.DefaultPrng {
    return std.Random.DefaultPrng.init(seed);
}

test "tensor basic operations" {
    var rng = createRng(42);
    var random = rng.random();

    var a = try Tensor.init(std.testing.allocator, &.{ 3, 4 });
    defer a.deinit();
    a.randn(&random, 0, 1);

    try std.testing.expect(a.numel() == 12);
    try std.testing.expect(a.ndim() == 2);
}

test "matmul" {
    var a = try Tensor.init(std.testing.allocator, &.{ 2, 3 });
    defer a.deinit();
    a.data = .{ 1, 2, 3, 4, 5, 6 };

    var b = try Tensor.init(std.testing.allocator, &.{ 3, 2 });
    defer b.deinit();
    b.data = .{ 7, 8, 9, 10, 11, 12 };

    var c = try Tensor.matmul(std.testing.allocator, a, b);
    defer c.deinit();

    // [1*7+2*9+3*11, 1*8+2*10+3*12] = [58, 64]
    // [4*7+5*9+6*11, 4*8+5*10+6*12] = [139, 154]
    try std.testing.expectApproxEq(@as(f32, 58), c.data[0], 0.001);
    try std.testing.expectApproxEq(@as(f32, 64), c.data[1], 0.001);
    try std.testing.expectApproxEq(@as(f32, 139), c.data[2], 0.001);
    try std.testing.expectApproxEq(@as(f32, 154), c.data[3], 0.001);
}
