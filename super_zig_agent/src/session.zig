// src/session.zig - إدارة الجلسات
const std = @import("std");

pub const Role = enum { user, assistant, system };

pub const Message = struct {
    role: Role,
    content: []u8,
    timestamp: i64,
    pub fn deinit(self: *Message, allocator: std.mem.Allocator) void { allocator.free(self.content); }
};

pub const Session = struct {
    id: []u8, title: []u8, messages: std.ArrayList(Message),
    created_at: i64, updated_at: i64, allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator, id: []const u8, title: []const u8) !Session {
        const now = std.time.timestamp();
        return .{ .id = try allocator.dupe(u8, id), .title = try allocator.dupe(u8, title), .messages = std.ArrayList(Message).init(allocator), .created_at = now, .updated_at = now, .allocator = allocator };
    }
    pub fn deinit(self: *Session) void {
        for (self.messages.items) |*m| m.deinit(self.allocator);
        self.messages.deinit();
        self.allocator.free(self.id);
        self.allocator.free(self.title);
    }
    pub fn addMessage(self: *Session, role: Role, content: []const u8) !void {
        try self.messages.append(.{ .role = role, .content = try self.allocator.dupe(u8, content), .timestamp = std.time.timestamp() });
        self.updated_at = std.time.timestamp();
    }
};

pub const SessionManager = struct {
    sessions: std.StringHashMap(*Session), allocator: std.mem.Allocator, counter: u64,
    pub fn init(allocator: std.mem.Allocator) SessionManager {
        return .{ .sessions = std.StringHashMap(*Session).init(allocator), .allocator = allocator, .counter = 0 };
    }
    pub fn deinit(self: *SessionManager) void {
        var iter = self.sessions.iterator();
        while (iter.next()) |entry| { entry.value_ptr.*.deinit(); self.allocator.destroy(entry.value_ptr.*); self.allocator.free(entry.key_ptr.*); }
        self.sessions.deinit();
    }
    pub fn createSession(self: *SessionManager, title: []const u8) ![]u8 {
        self.counter += 1;
        const id = try std.fmt.allocPrint(self.allocator, "sess_{d}", .{self.counter});
        const session = try self.allocator.create(Session);
        session.* = try Session.init(self.allocator, id, title);
        const key = try self.allocator.dupe(u8, id);
        try self.sessions.put(key, session);
        return id;
    }
    pub fn getSession(self: *SessionManager, id: []const u8) ?*Session { return self.sessions.get(id); }
    pub fn deleteSession(self: *SessionManager, id: []const u8) bool {
        if (self.sessions.fetchRemove(id)) |entry| { entry.value.deinit(); self.allocator.destroy(entry.value); self.allocator.free(entry.key); return true; }
        return false;
    }
    pub const SessionInfo = struct { id: []const u8, title: []const u8, message_count: usize, created_at: i64, updated_at: i64 };
    pub fn listSessions(self: *SessionManager) !std.ArrayList(SessionInfo) {
        var result = std.ArrayList(SessionInfo).init(self.allocator);
        var iter = self.sessions.iterator();
        while (iter.next()) |entry| {
            const s = entry.value_ptr.*;
            try result.append(.{ .id = s.id, .title = s.title, .message_count = s.messages.items.len, .created_at = s.created_at, .updated_at = s.updated_at });
        }
        return result;
    }
};
