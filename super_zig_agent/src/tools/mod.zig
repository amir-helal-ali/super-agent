// src/tools/mod.zig
const std = @import("std");
pub const calculator = @import("calculator.zig");
pub const datetime = @import("datetime.zig");
pub const translator = @import("translator.zig");
pub const web_search = @import("web_search.zig");

pub const ToolResult = struct { name: []const u8, success: bool, output: []const u8 };
pub const AVAILABLE_TOOLS = [_][]const u8{ "calculator", "datetime", "translator", "web_search", "memory_recall", "memory_save" };
