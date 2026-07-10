// src/main.zig - نقطة الدخول الرئيسية
// يوفر CLI تفاعلي للوكيل
const std = @import("std");
const SuperAgent = @import("agent.zig").SuperAgent;
const AgentConfig = @import("agent.zig").AgentConfig;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next(); // اسم البرنامج

    var config = AgentConfig{};
    var mode: Mode = .interactive;

    // تحليل الأوامر
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try printHelp();
            return;
        } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) {
            try std.io.getStdOut().writer().print("Super Agent v1.0.0 (Zig)\n", .{});
            return;
        } else if (std.mem.eql(u8, arg, "--chat") or std.mem.eql(u8, arg, "-c")) {
            mode = .single;
        } else if (std.mem.eql(u8, arg, "--stats")) {
            mode = .stats;
        } else if (std.mem.eql(u8, arg, "--learn")) {
            mode = .learn;
        } else if (std.mem.eql(u8, arg, "--server")) {
            mode = .server;
        } else if (std.mem.eql(u8, arg, "--lang")) {
            if (args.next()) |lang| {
                config.language = lang;
            }
        }
    }

    // إنشاء الوكيل
    std.debug.print("[init] Starting Super Agent...\n", .{});
    var agent = try SuperAgent.init(allocator, config);
    defer agent.deinit();

    std.debug.print("[init] Agent ready. Vocabulary: {d} tokens, Memory: {d} entries\n", .{
        agent.stats().vocab_size,
        agent.stats().memory_entries,
    });

    switch (mode) {
        .interactive => try interactiveMode(allocator, &agent),
        .single => try singleMode(allocator, &agent),
        .stats => try statsMode(&agent),
        .learn => try learnMode(allocator, &agent),
        .server => try serverMode(allocator, &agent),
    }
}

const Mode = enum {
    interactive,
    single,
    stats,
    learn,
    server,
};

/// الوضع التفاعلي - محادثة مباشرة
fn interactiveMode(_: std.mem.Allocator, agent: *SuperAgent) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n{s}\n", .{"========================================"});
    try stdout.print("{s}\n", .{"  Super Agent - الوكيل الخارق"});
    try stdout.print("{s}\n", .{"  اكتب 'exit' للخروج، 'help' للمساعدة"});
    try stdout.print("{s}\n\n", .{"========================================"});

    var line_buf: [4096]u8 = undefined;
    while (true) {
        try stdout.print("\n> ", .{});

        const line = stdin.readUntilDelimiterOrEof(&line_buf, '\n') catch |err| {
            try stdout.print("Error reading input: {}\n", .{err});
            continue;
        };

        if (line) |input| {
            const trimmed = std.mem.trim(u8, input, " \t\r");
            if (trimmed.len == 0) continue;

            if (std.mem.eql(u8, trimmed, "exit") or std.mem.eql(u8, trimmed, "quit")) {
                try stdout.print("Goodbye!\n", .{});
                break;
            }

            if (std.mem.eql(u8, trimmed, "help")) {
                try printHelpInteractive(stdout);
                continue;
            }

            if (std.mem.eql(u8, trimmed, "stats")) {
                try printStats(stdout, agent);
                continue;
            }

            // معالجة الرسالة
            var response = agent.chat(trimmed) catch |err| {
                try stdout.print("Error: {}\n", .{err});
                continue;
            };
            defer response.deinit();

            try stdout.print("\n{s}: {s}\n", .{ agent.config.name, response.answer });
            if (response.tools_used.items.len > 0) {
                try stdout.print("(أدوات مستخدمة: ", .{});
                for (response.tools_used.items, 0..) |t, i| {
                    if (i > 0) try stdout.print(", ", .{});
                    try stdout.print("{s}", .{t});
                }
                try stdout.print(")\n", .{});
            }
        }
    }
}

/// وضع الرسالة الواحدة
fn singleMode(_: std.mem.Allocator, agent: *SuperAgent) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var line_buf: [4096]u8 = undefined;
    const line = try stdin.readUntilDelimiterOrEof(&line_buf, '\n');
    if (line) |input| {
        var response = try agent.chat(input);
        defer response.deinit();
        try stdout.print("{s}\n", .{response.answer});
    }
}

/// وضع الإحصائيات
fn statsMode(agent: *SuperAgent) !void {
    const stdout = std.io.getStdOut().writer();
    try printStats(stdout, agent);
}

/// وضع التعلّم من نص
fn learnMode(_: std.mem.Allocator, agent: *SuperAgent) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    try stdout.print("أدخل نصاً للتعلم (Ctrl+D للإنهاء):\n", .{});

    var buf: [8192]u8 = undefined;
    var total: usize = 0;
    while (true) {
        const line = stdin.readUntilDelimiterOrEof(&buf, '\n') catch break;
        if (line) |l| {
            try agent.learn(l);
            total += l.len;
        }
    }
    try stdout.print("تم التعلم من {d} حرف.\n", .{total});
}

/// وضع الخادم (placeholder - سيُنفذ لاحقاً)
fn serverMode(_: std.mem.Allocator, _: *SuperAgent) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Server mode not yet implemented. Use --chat for interactive mode.\n", .{});
}

fn printHelp() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        \\Super Agent - وكيل ذكاء اصطناعي خارق خفيف الوزن
        \\
        \\الاستخدام:
        \\  super-agent [options]
        \\
        \\الخيارات:
        \\  -h, --help     عرض هذه المساعدة
        \\  -v, --version  عرض الإصدار
        \\  -c, --chat     وضع الرسالة الواحدة (يقرأ من stdin)
        \\  --stats        عرض إحصائيات الوكيل
        \\  --learn        وضع التعلم من نص (يقرأ من stdin)
        \\  --server       تشغيل كخادم HTTP
        \\  --lang <lang>  تعيين اللغة (ar/en)
        \\
        \\الأوامر التفاعلية:
        \\  help    عرض المساعدة
        \\  stats   عرض الإحصائيات
        \\  exit    الخروج
        \\
        \\أمثلة:
        \\  super-agent
        \\  echo "مرحبا" | super-agent --chat
        \\  super-agent --lang en
        \\
    , .{});
}

fn printHelpInteractive(writer: anytype) !void {
    try writer.print(
        \\الأوامر المتاحة:
        \\  help   - عرض هذه المساعدة
        \\  stats  - عرض إحصائيات الوكيل
        \\  exit   - الخروج
        \\
        \\يمكنك أيضاً:
        \\  - إجراء عمليات حسابية: 2 + 3 * 4
        \\  - سؤال عن معلومات محفوظة: "تذكر X"
        \\  - البحث على الويب: "ابحث عن X"
        \\
    , .{});
}

fn printStats(writer: anytype, agent: *SuperAgent) !void {
    const stats = agent.stats();
    try writer.print(
        \\إحصائيات Super Agent:
        \\  حجم القاموس: {d} توكن
        \\  مدخلات الذاكرة: {d}
        \\  النموذج مُحمّل: {s}
        \\
    , .{
        stats.vocab_size,
        stats.memory_entries,
        if (stats.has_model) "نعم" else "لا",
    });
}
