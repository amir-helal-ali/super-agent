// src/tests.zig - اختبارات الوحدة
const std = @import("std");

test "tensor basic operations" {
    _ = @import("nn/tensor.zig");
}

test "linear layer" {
    _ = @import("nn/linear.zig");
}

test "attention mechanism" {
    _ = @import("nn/attention.zig");
}

test "tokenizer" {
    _ = @import("tokenizer.zig");
}

test "model" {
    _ = @import("model.zig");
}

test "memory" {
    _ = @import("memory.zig");
}

test "calculator" {
    _ = @import("tools/calculator.zig");
}

test "web crawler" {
    _ = @import("web/crawler.zig");
}
