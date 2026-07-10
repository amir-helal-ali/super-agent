// src/web/crawler.zig - زاحف الويب للتعلم الذاتي
// يجلب النصوص من الإنترنت ليتعلم منها النموذج
const std = @import("std");
const http = @import("http.zig");

pub const Crawler = struct {
    allocator: std.mem.Allocator,
    visited: std.StringHashMap(void),
    queue: std.ArrayList([]const u8),
    max_pages: usize,
    rate_limit_ms: u64,

    pub fn init(allocator: std.mem.Allocator, max_pages: usize) Crawler {
        return .{
            .allocator = allocator,
            .visited = std.StringHashMap(void).init(allocator),
            .queue = std.ArrayList([]const u8).init(allocator),
            .max_pages = max_pages,
            .rate_limit_ms = 500, // احترام الخوادم
        };
    }

    pub fn deinit(self: *Crawler) void {
        self.visited.deinit();
        for (self.queue.items) |url| self.allocator.free(url);
        self.queue.deinit();
    }

    /// إضافة URL للقائمة
    pub fn addUrl(self: *Crawler, url: []const u8) !void {
        const owned = try self.allocator.dupe(u8, url);
        try self.queue.append(owned);
    }

    /// جلب صفحة واحدة وإرجاع نصها
    pub fn fetchPage(self: *Crawler, url: []const u8) !?[]u8 {
        if (self.visited.contains(url)) return null;
        try self.visited.put(url, {});

        std.debug.print("[crawler] fetching: {s}\n", .{url});

        var response = http.fetch(self.allocator, url, 2 * 1024 * 1024) catch |err| {
            std.debug.print("[crawler] error fetching {s}: {}\n", .{ url, err });
            return null;
        };
        defer response.deinit();

        if (response.status != 200) {
            std.debug.print("[crawler] HTTP {d} for {s}\n", .{ response.status, url });
            return null;
        }

        // استخراج النص من HTML
        const text = try extractText(self.allocator, response.body);
        return text;
    }

    /// جلب صفحات متعددة وإرجاع النصوص
    pub fn crawl(self: *Crawler) !std.ArrayList([]u8) {
        var results = std.ArrayList([]u8).init(self.allocator);
        var fetched: usize = 0;

        while (self.queue.items.len > 0 and fetched < self.max_pages) {
            const url = self.queue.orderedRemove(0);
            defer self.allocator.free(url);

            if (self.fetchPage(url)) |text_opt| {
                if (text_opt) |text| {
                    try results.append(text);
                    fetched += 1;
                }
            } else |err| {
                std.debug.print("[crawler] error: {}\n", .{err});
            }

            // احترام الخوادم - تأخير
            std.time.sleep(self.rate_limit_ms * std.time.ns_per_ms);
        }

        std.debug.print("[crawler] fetched {d} pages\n", .{fetched});
        return results;
    }
};

/// استخراج النص من HTML بدون مكتبات خارجية
pub fn extractText(allocator: std.mem.Allocator, html: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    var i: usize = 0;
    var in_tag = false;
    var in_script = false;
    var in_style = false;
    var in_title = false;

    while (i < html.len) {
        if (in_tag) {
            // فحص نوع التاج
            if (i + 7 <= html.len and std.mem.eql(u8, html[i .. i + 7], "script>")) {
                in_script = true;
                in_tag = false;
                i += 7;
                continue;
            }
            if (i + 6 <= html.len and std.mem.eql(u8, html[i .. i + 6], "style>")) {
                in_style = true;
                in_tag = false;
                i += 6;
                continue;
            }
            if (i + 6 <= html.len and std.mem.eql(u8, html[i .. i + 6], "title>")) {
                in_title = true;
                in_tag = false;
                i += 6;
                continue;
            }
            // نهاية التاج
            if (html[i] == '>') {
                in_tag = false;
                i += 1;
                continue;
            }
            i += 1;
        } else if (in_script) {
            // انتظار </script>
            if (i + 9 <= html.len and std.mem.eql(u8, html[i .. i + 9], "</script>")) {
                in_script = false;
                i += 9;
                continue;
            }
            i += 1;
        } else if (in_style) {
            if (i + 8 <= html.len and std.mem.eql(u8, html[i .. i + 8], "</style>")) {
                in_style = false;
                i += 8;
                continue;
            }
            i += 1;
        } else if (in_title) {
            if (i + 8 <= html.len and std.mem.eql(u8, html[i .. i + 8], "</title>")) {
                in_title = false;
                i += 8;
                // إضافة سطر جديد بعد العنوان
                try result.append('\n');
                continue;
            }
            // إضافة حروف العنوان
            try result.append(html[i]);
            i += 1;
        } else {
            // نص عادي
            if (i + 1 <= html.len and html[i] == '<') {
                in_tag = true;
                i += 1;
                continue;
            }
            // تحويل بعض الـ entities
            if (i + 6 <= html.len and std.mem.eql(u8, html[i .. i + 6], "&nbsp;")) {
                try result.append(' ');
                i += 6;
                continue;
            }
            if (i + 5 <= html.len and std.mem.eql(u8, html[i .. i + 5], "&amp;")) {
                try result.append('&');
                i += 5;
                continue;
            }
            if (i + 4 <= html.len and std.mem.eql(u8, html[i .. i + 4], "&lt;")) {
                try result.append('<');
                i += 4;
                continue;
            }
            if (i + 4 <= html.len and std.mem.eql(u8, html[i .. i + 4], "&gt;")) {
                try result.append('>');
                i += 4;
                continue;
            }
            if (i + 6 <= html.len and std.mem.eql(u8, html[i .. i + 6], "&quot;")) {
                try result.append('"');
                i += 6;
                continue;
            }
            // تحويل BR و P إلى سطور جديدة
            if (i + 4 <= html.len and (std.mem.eql(u8, html[i .. i + 4], "<br>") or
                std.mem.eql(u8, html[i .. i + 4], "<BR>")))
            {
                try result.append('\n');
                i += 4;
                continue;
            }

            try result.append(html[i]);
            i += 1;
        }
    }

    // تنظيف النص - إزالة المسافات الزائدة
    return cleanText(allocator, result.items);
}

/// تنظيف النص - إزالة المسافات الزائدة والأسطر الفارغة
pub fn cleanText(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    var prev_was_space = true; // لتجاوز المسافات في البداية
    var prev_was_newline = false;
    var in_text = false;

    for (text) |c| {
        if (c == ' ' or c == '\t') {
            if (in_text and !prev_was_space) {
                try result.append(' ');
                prev_was_space = true;
            }
        } else if (c == '\n' or c == '\r') {
            if (in_text and !prev_was_newline) {
                try result.append('\n');
                prev_was_newline = true;
                prev_was_space = true;
            }
        } else {
            try result.append(c);
            in_text = true;
            prev_was_space = false;
            prev_was_newline = false;
        }
    }

    return result.toOwnedSlice();
}

/// استخراج روابط من HTML
pub fn extractLinks(allocator: std.mem.Allocator, html: []const u8, base_url: []const u8) !std.ArrayList([]u8) {
    var links = std.ArrayList([]u8).init(allocator);

    var i: usize = 0;
    while (i < html.len) {
        // البحث عن href=
        if (i + 6 <= html.len and (std.mem.eql(u8, html[i .. i + 6], "href=\"") or
            std.mem.eql(u8, html[i .. i + 6], "href='")))
        {
            const quote = html[i + 5];
            i += 6;
            const start = i;
            while (i < html.len and html[i] != quote) : (i += 1) {}
            if (i < html.len) {
                const link = html[start..i];
                // تحويل الرابط النسبي إلى مطلق
                if (link.len > 0 and link[0] == '/') {
                    // تحويل لـ base_url + link
                    if (std.mem.indexOf(u8, base_url, "://")) |proto_end| {
                        const after_proto = base_url[proto_end + 3 ..];
                        if (std.mem.indexOf(u8, after_proto, "/")) |host_end| {
                            const host = base_url[0 .. proto_end + 3 + host_end];
                            const full = try std.fmt.allocPrint(allocator, "{s}{s}", .{ host, link });
                            try links.append(full);
                        }
                    }
                } else if (std.mem.startsWith(u8, link, "http://") or std.mem.startsWith(u8, link, "https://")) {
                    try links.append(try allocator.dupe(u8, link));
                }
            }
        }
        i += 1;
    }
    return links;
}
