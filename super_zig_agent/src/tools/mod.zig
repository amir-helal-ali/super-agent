// src/tools/mod.zig - أدوات الوكيل
pub const calculator = @import("calculator.zig");

pub const ToolResult = struct {
    name: []const u8,
    success: bool,
    output: []const u8,
};

/// تنفيذ أداة حسب الاسم
pub fn execute(
    allocator: std.mem.Allocator,
    tool_name: []const u8,
    args: []const []const u8,
) !ToolResult {
    if (std.mem.eql(u8, tool_name, "calculator")) {
        if (args.len < 1) {
            return .{ .name = "calculator", .success = false, .output = "missing expression argument" };
        }
        const result = try calculator.evaluate(allocator, args[0]);
        return .{ .name = "calculator", .success = true, .output = result };
    }

    if (std.mem.eql(u8, tool_name, "memory_save")) {
        // args[0] = key, args[1] = value
        // يتم معالجته في الـ agent مباشرة
        return .{ .name = "memory_save", .success = true, .output = "saved" };
    }

    return .{ .name = tool_name, .success = false, .output = "unknown tool" };
}

const std = @import("std");
