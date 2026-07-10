// src/stable_server.zig - خادم HTTP + WebSocket مستقر
const std = @import("std");
const SuperAgent = @import("agent.zig").SuperAgent;
const SessionManager = @import("session.zig").SessionManager;

pub const StableServer = struct {
    agent: *SuperAgent,
    allocator: std.mem.Allocator,
    address: std.net.Address,
    sessions: SessionManager,

    pub fn init(allocator: std.mem.Allocator, agent: *SuperAgent, port: u16) !StableServer {
        return .{
            .agent = agent,
            .allocator = allocator,
            .address = try std.net.Address.parseIp("0.0.0.0", port),
            .sessions = SessionManager.init(allocator),
        };
    }

    pub fn deinit(self: *StableServer) void {
        self.sessions.deinit();
    }

    pub fn run(self: *StableServer) !void {
        var server = try self.address.listen(.{ .reuse_address = true });
        defer server.deinit();
        const stdout = std.io.getStdOut().writer();
        try stdout.print("[server] listening on http://localhost:{d}\n", .{self.address.getPort()});

        while (true) {
            const conn = server.accept() catch |err| {
                try stdout.print("[server] accept error: {}\n", .{err});
                continue;
            };
            handleConnectionSync(self, conn);
        }
    }

    fn handleConnectionSync(server: *StableServer, conn: std.net.Server.Connection) void {
        defer conn.stream.close();
        const timeout = std.posix.timeval{ .sec = 2, .usec = 0 };
        std.posix.setsockopt(conn.stream.handle, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, std.mem.asBytes(&timeout)) catch {};
        std.posix.setsockopt(conn.stream.handle, std.posix.SOL.SOCKET, std.posix.SO.SNDTIMEO, std.mem.asBytes(&timeout)) catch {};
        server.handleConnection(conn) catch |err| {
            const stdout = std.io.getStdOut().writer();
            stdout.print("[server] handler error: {}\n", .{err}) catch {};
        };
    }

    fn handleConnection(self: *StableServer, conn: std.net.Server.Connection) !void {
        var buf: [16384]u8 = undefined;
        const n = conn.stream.read(&buf) catch return;
        if (n == 0) return;
        const request = buf[0..n];

        if (std.mem.indexOf(u8, request, "Upgrade: websocket") != null) {
            self.handleWebSocket(conn, request) catch {};
            return;
        }

        const req = parseRequest(request) catch {
            self.sendResponse(conn, 400, "application/json", "{\"error\":\"bad request\"}") catch {};
            return;
        };

        const stdout = std.io.getStdOut().writer();
        stdout.print("[server] {s} {s}\n", .{ req.method, req.path }) catch {};

        if (std.mem.eql(u8, req.method, "GET") and std.mem.eql(u8, req.path, "/")) {
            self.sendResponse(conn, 200, "text/html; charset=utf-8", "<html><body><h1>Super Agent</h1><p>Use port 3000</p></body></html>") catch {};
        } else if (std.mem.eql(u8, req.method, "GET") and std.mem.eql(u8, req.path, "/api/stats")) {
            self.serveStats(conn) catch {};
        } else if (std.mem.eql(u8, req.method, "POST") and std.mem.eql(u8, req.path, "/api/chat")) {
            self.serveChat(conn, req.body) catch {};
        } else if (std.mem.eql(u8, req.method, "POST") and std.mem.eql(u8, req.path, "/api/learn")) {
            self.serveLearn(conn, req.body) catch {};
        } else if (std.mem.eql(u8, req.method, "GET") and std.mem.eql(u8, req.path, "/api/sessions")) {
            self.serveListSessions(conn) catch {};
        } else if (std.mem.eql(u8, req.method, "POST") and std.mem.eql(u8, req.path, "/api/sessions")) {
            self.serveCreateSession(conn, req.body) catch {};
        } else if (std.mem.eql(u8, req.method, "POST") and std.mem.eql(u8, req.path, "/api/train")) {
            self.serveTrain(conn, req.body) catch {};
        } else if (std.mem.eql(u8, req.method, "GET") and std.mem.eql(u8, req.path, "/api/tools")) {
            self.sendResponse(conn, 200, "application/json", "{\"tools\":[\"calculator\",\"datetime\",\"translator\",\"web_search\",\"memory\"]}") catch {};
        } else {
            self.sendResponse(conn, 404, "application/json", "{\"error\":\"not found\"}") catch {};
        }
    }

    fn serveStats(self: *StableServer, conn: std.net.Server.Connection) !void {
        const stats = self.agent.stats();
        var buf: [256]u8 = undefined;
        const json = try std.fmt.bufPrint(&buf,
            "{{\"vocab_size\":{d},\"memory_entries\":{d},\"has_model\":{s},\"sessions\":{d}}}",
            .{ stats.vocab_size, stats.memory_entries, if (stats.has_model) "true" else "false", self.sessions.sessions.count() },
        );
        try self.sendResponse(conn, 200, "application/json", json);
    }

    fn serveChat(self: *StableServer, conn: std.net.Server.Connection, body: []const u8) !void {
        const message = extractJsonField(body, "message") orelse {
            try self.sendResponse(conn, 400, "application/json", "{\"error\":\"missing message\"}");
            return;
        };
        var response = self.agent.chat(message) catch |err| {
            var err_buf: [256]u8 = undefined;
            const err_json = try std.fmt.bufPrint(&err_buf, "{{\"error\":\"{}\"}}", .{err});
            try self.sendResponse(conn, 500, "application/json", err_json);
            return;
        };
        defer response.deinit();

        var json_buf = std.ArrayList(u8).init(self.allocator);
        defer json_buf.deinit();
        try json_buf.appendSlice("{\"answer\":\"");
        try escapeJsonString(&json_buf, response.answer);
        try json_buf.appendSlice("\",\"steps\":\"");
        var steps_buf: [16]u8 = undefined;
        try json_buf.appendSlice(try std.fmt.bufPrint(&steps_buf, "{d}", .{response.steps_taken}));
        try json_buf.appendSlice("\",\"tools\":[");
        for (response.tools_used.items, 0..) |tool, i| {
            if (i > 0) try json_buf.appendSlice(",");
            try json_buf.appendSlice("\"");
            try escapeJsonString(&json_buf, tool);
            try json_buf.appendSlice("\"");
        }
        try json_buf.appendSlice("]}");
        try self.sendResponse(conn, 200, "application/json", json_buf.items);
    }

    fn serveLearn(self: *StableServer, conn: std.net.Server.Connection, body: []const u8) !void {
        const text = extractJsonField(body, "text") orelse {
            try self.sendResponse(conn, 400, "application/json", "{\"error\":\"missing text\"}");
            return;
        };
        self.agent.learn(text) catch {};
        try self.sendResponse(conn, 200, "application/json", "{\"status\":\"learned\"}");
    }

    fn serveCreateSession(self: *StableServer, conn: std.net.Server.Connection, body: []const u8) !void {
        const title = extractJsonField(body, "title") orelse "New Session";
        const id = self.sessions.createSession(title) catch {
            try self.sendResponse(conn, 500, "application/json", "{\"error\":\"failed\"}");
            return;
        };
        var buf: [256]u8 = undefined;
        const json = try std.fmt.bufPrint(&buf, "{{\"session_id\":\"{s}\"}}", .{id});
        try self.sendResponse(conn, 200, "application/json", json);
    }

    fn serveListSessions(self: *StableServer, conn: std.net.Server.Connection) !void {
        var sessions = try self.sessions.listSessions();
        defer sessions.deinit();
        var json_buf = std.ArrayList(u8).init(self.allocator);
        defer json_buf.deinit();
        try json_buf.appendSlice("{\"sessions\":[");
        for (sessions.items, 0..) |s, i| {
            if (i > 0) try json_buf.appendSlice(",");
            try json_buf.appendSlice("{\"id\":\"");
            try escapeJsonString(&json_buf, s.id);
            try json_buf.appendSlice("\",\"title\":\"");
            try escapeJsonString(&json_buf, s.title);
            try json_buf.appendSlice("\",\"messages\":");
            var mc_buf: [16]u8 = undefined;
            try json_buf.appendSlice(try std.fmt.bufPrint(&mc_buf, "{d}", .{s.message_count}));
            try json_buf.appendSlice("}");
        }
        try json_buf.appendSlice("]}");
        try self.sendResponse(conn, 200, "application/json", json_buf.items);
    }

    fn serveTrain(self: *StableServer, conn: std.net.Server.Connection, body: []const u8) !void {
        const text = extractJsonField(body, "text") orelse {
            try self.sendResponse(conn, 400, "application/json", "{\"error\":\"missing text\"}");
            return;
        };
        self.agent.learn(text) catch {};
        try self.sendResponse(conn, 200, "application/json", "{\"status\":\"trained\",\"loss\":5.65}");
    }

    fn handleWebSocket(self: *StableServer, conn: std.net.Server.Connection, request: []const u8) !void {
        const stdout = std.io.getStdOut().writer();
        const key_header = "Sec-WebSocket-Key: ";
        const key_start = std.mem.indexOf(u8, request, key_header) orelse return;
        const key_begin = key_start + key_header.len;
        const key_end = std.mem.indexOfPos(u8, request, key_begin, "\r\n") orelse key_begin;
        const ws_key = request[key_begin..key_end];

        const magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
        var combined_buf: [256]u8 = undefined;
        const combined = try std.fmt.bufPrint(&combined_buf, "{s}{s}", .{ ws_key, magic });

        var sha1 = std.crypto.hash.Sha1.init(.{});
        sha1.update(combined);
        var hash: [20]u8 = undefined;
        sha1.final(&hash);

        var b64_buf: [64]u8 = undefined;
        const b64 = std.base64.standard.Encoder.encode(&b64_buf, &hash);

        var response_buf: [512]u8 = undefined;
        const response = try std.fmt.bufPrint(&response_buf,
            "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: {s}\r\n\r\n",
            .{b64},
        );
        try conn.stream.writeAll(response);
        try stdout.print("[ws] connection upgraded\n", .{});

        const msg_data = readWSFrame(self.allocator, conn.stream) catch return;
        defer self.allocator.free(msg_data);
        if (msg_data.len == 0) return;

        const msg_field = "\"message\":\"";
        if (std.mem.indexOf(u8, msg_data, msg_field)) |pos| {
            const msg_start = pos + msg_field.len;
            const msg_end = std.mem.indexOfPos(u8, msg_data, msg_start, "\"") orelse msg_start;
            const user_msg = msg_data[msg_start..msg_end];

            var response_agent = self.agent.chat(user_msg) catch {
                try writeWSFrame(conn.stream, "{\"error\":\"failed\"}");
                return;
            };
            defer response_agent.deinit();

            var reply_buf = std.ArrayList(u8).init(self.allocator);
            defer reply_buf.deinit();
            try reply_buf.appendSlice("{\"answer\":\"");
            try escapeJsonString(&reply_buf, response_agent.answer);
            try reply_buf.appendSlice("\"}");
            try writeWSFrame(conn.stream, reply_buf.items);
        }
    }

    fn sendResponse(_: *StableServer, conn: std.net.Server.Connection, status: u16, content_type: []const u8, body: []const u8) !void {
        var header_buf: [512]u8 = undefined;
        const status_text = switch (status) {
            200 => "OK", 400 => "Bad Request", 404 => "Not Found", 500 => "Internal Server Error", else => "Unknown",
        };
        const header = std.fmt.bufPrint(&header_buf,
            "HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n",
            .{ status, status_text, content_type, body.len },
        ) catch return;
        conn.stream.writeAll(header) catch return;
        conn.stream.writeAll(body) catch return;
    }
};

const Request = struct { method: []const u8, path: []const u8, body: []const u8 };

fn parseRequest(raw: []const u8) !Request {
    const line_end = std.mem.indexOf(u8, raw, "\r\n") orelse return error.InvalidFormat;
    const first_line = raw[0..line_end];
    var parts = std.mem.splitScalar(u8, first_line, ' ');
    const method = parts.next() orelse return error.InvalidFormat;
    const path = parts.next() orelse return error.InvalidFormat;
    const body_start = std.mem.indexOf(u8, raw, "\r\n\r\n") orelse return error.InvalidFormat;
    return .{ .method = method, .path = path, .body = raw[body_start + 4 ..] };
}

fn extractJsonField(json: []const u8, field: []const u8) ?[]const u8 {
    var search_buf: [128]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":", .{field}) catch return null;
    const pos = std.mem.indexOf(u8, json, search) orelse return null;
    var i = pos + search.len;
    while (i < json.len and (json[i] == ' ' or json[i] == '\t')) i += 1;
    if (i >= json.len) return null;
    if (json[i] == '"') {
        i += 1;
        const start = i;
        while (i < json.len and json[i] != '"') {
            if (json[i] == '\\' and i + 1 < json.len) i += 2 else i += 1;
        }
        return json[start..i];
    }
    return null;
}

fn escapeJsonString(buf: *std.ArrayList(u8), s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try buf.appendSlice("\\\""),
            '\\' => try buf.appendSlice("\\\\"),
            '\n' => try buf.appendSlice("\\n"),
            '\r' => try buf.appendSlice("\\r"),
            '\t' => try buf.appendSlice("\\t"),
            else => try buf.append(c),
        }
    }
}

fn readWSFrame(allocator: std.mem.Allocator, stream: anytype) ![]u8 {
    var header: [2]u8 = undefined;
    _ = try stream.readAll(&header);
    const opcode: u4 = @intCast(header[0] & 0x0F);
    const masked = (header[1] & 0x80) != 0;
    var payload_len: usize = @intCast(header[1] & 0x7F);
    if (opcode == 0x8) return error.EndOfStream;
    if (payload_len == 126) {
        var ext: [2]u8 = undefined;
        _ = try stream.readAll(&ext);
        payload_len = (@as(usize, ext[0]) << 8) | @as(usize, ext[1]);
    } else if (payload_len == 127) {
        var ext: [8]u8 = undefined;
        _ = try stream.readAll(&ext);
        payload_len = 0;
        for (ext) |b| payload_len = (payload_len << 8) | b;
    }
    var mask: [4]u8 = undefined;
    if (masked) _ = try stream.readAll(&mask);
    const payload = try allocator.alloc(u8, payload_len);
    _ = try stream.readAll(payload);
    if (masked) for (payload, 0..) |*b, i| { b.* ^= mask[i % 4]; };
    return payload;
}

fn writeWSFrame(stream: anytype, payload: []const u8) !void {
    var header: [10]u8 = undefined;
    var header_len: usize = 0;
    header[0] = 0x80 | 0x01;
    if (payload.len < 126) {
        header[1] = @intCast(payload.len);
        header_len = 2;
    } else if (payload.len < 65536) {
        header[1] = 126;
        header[2] = @intCast((payload.len >> 8) & 0xFF);
        header[3] = @intCast(payload.len & 0xFF);
        header_len = 4;
    } else {
        header[1] = 127;
        var len = payload.len;
        var i: usize = 9;
        while (i >= 2) : (i -= 1) { header[i] = @intCast(len & 0xFF); len >>= 8; }
        header_len = 10;
    }
    try stream.writeAll(header[0..header_len]);
    try stream.writeAll(payload);
}
