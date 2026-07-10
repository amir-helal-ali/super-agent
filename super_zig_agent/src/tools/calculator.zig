// src/tools/calculator.zig - أداة الحاسبة
const std = @import("std");

pub const CalcValue = union(enum) {
    number: f64,
    err: []const u8,
};

/// تقييم تعبير رياضي بشكل آمن - بدون eval
pub fn evaluate(allocator: std.mem.Allocator, expr: []const u8) ![]u8 {
    // إزالة المسافات
    var clean = std.ArrayList(u8).init(allocator);
    defer clean.deinit();
    for (expr) |c| {
        if (c != ' ' and c != '\t') try clean.append(c);
    }

    // استبدال الرموز
    var i: usize = 0;
    while (i < clean.items.len) : (i += 1) {
        if (clean.items[i] == '^') clean.items[i] = '*'; // سنحتاج ** لكن نبسط
    }

    var pos: usize = 0;
    const result = parseExpr(clean.items, &pos, allocator) catch |err| {
        return std.fmt.allocPrint(allocator, "Error: {}", .{err});
    };

    if (pos != clean.items.len) {
        return std.fmt.allocPrint(allocator, "Error: unexpected character at position {d}", .{pos});
    }

    return switch (result) {
        .number => |n| std.fmt.allocPrint(allocator, "{d}", .{n}),
        .err => |e| std.fmt.allocPrint(allocator, "Error: {s}", .{e}),
    };
}

fn parseExpr(s: []const u8, pos: *usize, allocator: std.mem.Allocator) anyerror!CalcValue {
    var left = try parseTerm(s, pos, allocator);
    while (pos.* < s.len and (s[pos.*] == '+' or s[pos.*] == '-')) {
        const op = s[pos.*];
        pos.* += 1;
        const right = try parseTerm(s, pos, allocator);
        left = switch (left) {
            .number => |l| switch (right) {
                .number => |r| CalcValue{ .number = if (op == '+') l + r else l - r },
                .err => right,
            },
            .err => left,
        };
    }
    return left;
}

fn parseTerm(s: []const u8, pos: *usize, allocator: std.mem.Allocator) anyerror!CalcValue {
    var left = try parseFactor(s, pos, allocator);
    while (pos.* < s.len and (s[pos.*] == '*' or s[pos.*] == '/')) {
        const op = s[pos.*];
        pos.* += 1;
        const right = try parseFactor(s, pos, allocator);
        left = switch (left) {
            .number => |l| switch (right) {
                .number => |r| if (op == '*')
                    CalcValue{ .number = l * r }
                else if (r == 0)
                    CalcValue{ .err = "division by zero" }
                else
                    CalcValue{ .number = l / r },
                .err => right,
            },
            .err => left,
        };
    }
    return left;
}

fn parseFactor(s: []const u8, pos: *usize, allocator: std.mem.Allocator) anyerror!CalcValue {
    var base = try parseAtom(s, pos, allocator);
    while (pos.* < s.len and s[pos.*] == '^') {
        pos.* += 1;
        const exp = try parseAtom(s, pos, allocator);
        base = switch (base) {
            .number => |b| switch (exp) {
                .number => |e| CalcValue{ .number = std.math.pow(f64, b, e) },
                .err => exp,
            },
            .err => base,
        };
    }
    return base;
}

fn parseAtom(s: []const u8, pos: *usize, allocator: std.mem.Allocator) anyerror!CalcValue {
    if (pos.* >= s.len) return CalcValue{ .err = "unexpected end of input" };

    if (s[pos.*] == '(') {
        pos.* += 1;
        const result = try parseExpr(s, pos, allocator);
        if (pos.* < s.len and s[pos.*] == ')') {
            pos.* += 1;
        } else {
            return CalcValue{ .err = "missing closing parenthesis" };
        }
        return result;
    }

    if (s[pos.*] == '-') {
        pos.* += 1;
        const v = try parseAtom(s, pos, allocator);
        return switch (v) {
            .number => |n| CalcValue{ .number = -n },
            .err => v,
        };
    }

    // رقم
    if (std.ascii.isDigit(s[pos.*]) or s[pos.*] == '.') {
        const start = pos.*;
        while (pos.* < s.len and (std.ascii.isDigit(s[pos.*]) or s[pos.*] == '.')) : (pos.* += 1) {}
        const num_str = s[start..pos.*];
        const num = std.fmt.parseFloat(f64, num_str) catch {
            return CalcValue{ .err = "invalid number" };
        };
        return CalcValue{ .number = num };
    }

    // ثابت
    if (pos.* + 2 <= s.len and std.mem.eql(u8, s[pos.* .. pos.* + 2], "pi")) {
        pos.* += 2;
        return CalcValue{ .number = std.math.pi };
    }
    if (pos.* < s.len and s[pos.*] == 'e') {
        pos.* += 1;
        return CalcValue{ .number = std.math.e };
    }

    return CalcValue{ .err = "unexpected character" };
}

test "calculator basic" {
    const result = try evaluate(std.testing.allocator, "2 + 3 * 4");
    defer std.testing.allocator.free(result);
    // يجب أن يكون 14
    try std.testing.expect(std.mem.indexOf(u8, result, "14") != null);
}

test "calculator parentheses" {
    const result = try evaluate(std.testing.allocator, "(2 + 3) * 4");
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "20") != null);
}
