// src/tools/datetime.zig
const std = @import("std");

pub fn getCurrentTime(allocator: std.mem.Allocator) ![]u8 {
    const now = std.time.timestamp();
    const epoch_secs = @as(u64, @intCast(now));
    const epoch_day = std.time.epoch.EpochSeconds{ .secs = epoch_secs };
    const day_secs = epoch_day.getDaySeconds();
    const year_day = epoch_day.getEpochDay().calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const hours = day_secs.getHoursIntoDay();
    const mins = day_secs.getMinutesIntoHour();
    const secs = day_secs.getSecondsIntoMinute();
    const year = year_day.year;
    const month = month_day.month.numeric();
    const day = month_day.day_index + 1;
    const month_names = [_][]const u8{ "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر" };
    const month_name = if (month >= 1 and month <= 12) month_names[month - 1] else "غير معروف";
    return std.fmt.allocPrint(allocator, "{d} {s} {d} - {d:0>2}:{d:0>2}:{d:0>2} UTC", .{ day, month_name, year, hours, mins, secs });
}

pub fn formatResponse(allocator: std.mem.Allocator, query: []const u8) !?[]u8 {
    const time_indicators = [_][]const u8{ "وقت", "ساعة", "time", "clock" };
    const date_indicators = [_][]const u8{ "تاريخ", "يوم", "date", "today" };
    var is_time = false;
    var is_date = false;
    for (time_indicators) |ind| { if (std.mem.indexOf(u8, query, ind) != null) is_time = true; }
    for (date_indicators) |ind| { if (std.mem.indexOf(u8, query, ind) != null) is_date = true; }
    if (!is_time and !is_date) return null;
    const now_str = try getCurrentTime(allocator);
    defer allocator.free(now_str);
    if (is_time and is_date) return try std.fmt.allocPrint(allocator, "الوقت والتاريخ الحالي: {s}", .{now_str});
    if (is_time) return try std.fmt.allocPrint(allocator, "الوقت الحالي: {s}", .{now_str});
    return try std.fmt.allocPrint(allocator, "التاريخ الحالي: {s}", .{now_str});
}
