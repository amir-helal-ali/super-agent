// src/web/http.zig - عميل HTTP خفيف الوزن
// يستخدم std.http (مدمج في Zig - لا اعتماديات خارجية)
const std = @import("std");

pub const HttpError = error{
    NetworkError,
    InvalidResponse,
    TooLarge,
    Timeout,
};

pub const HttpResponse = struct {
    status: u16,
    body: []u8,
    headers: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn deinit(self: *HttpResponse) void {
        self.allocator.free(self.body);
        var iter = self.headers.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
    }
};

/// جلب URL وإرجاع الرد
pub fn fetch(
    allocator: std.mem.Allocator,
    url_str: []const u8,
    max_size: usize,
) !HttpResponse {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var body = std.ArrayList(u8).init(allocator);
    defer body.deinit();

    const uri = try std.Uri.parse(url_str);

    var server_header_buffer: [16 * 1024]u8 = undefined;
    var req = try client.open(.GET, uri, .{
        .server_header_buffer = &server_header_buffer,
        .extra_headers = &.{
            .{ .name = "User-Agent", .value = "SuperAgent/1.0 (Zig; Educational)" },
            .{ .name = "Accept", .value = "text/html,application/xhtml+xml,text/plain,*/*" },
            .{ .name = "Accept-Language", .value = "ar,en-US;q=0.9,en;q=0.8" },
        },
    });
    defer req.deinit();

    try req.send();
    try req.finish();
    try req.wait();

    const status_code = @intFromEnum(req.response.status);

    var reader = req.reader();
    var buf: [8192]u8 = undefined;
    while (true) {
        const n = reader.read(&buf) catch break;
        if (n == 0) break;
        if (body.items.len + n > max_size) {
            try body.appendSlice(buf[0 .. max_size - body.items.len]);
            break;
        }
        try body.appendSlice(buf[0..n]);
    }

    // نسخ الـ body
    const body_copy = try allocator.dupe(u8, body.items);

    var headers = std.StringHashMap([]const u8).init(allocator);
    // نسخ الـ headers المهمة
    if (req.response.content_type) |ct| {
        try headers.put(
            try allocator.dupe(u8, "content-type"),
            try allocator.dupe(u8, ct),
        );
    }

    return HttpResponse{
        .status = @intCast(status_code),
        .body = body_copy,
        .headers = headers,
        .allocator = allocator,
    };
}

test "fetch basic" {
    // اختبار بسيط - يتطلب اتصال بالإنترنت
    // متخطى في الوضع الافتراضي
}
