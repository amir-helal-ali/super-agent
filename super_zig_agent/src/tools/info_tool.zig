// src/tools/info_tool.zig - أداة معلومات (طقس، عملات، حقائق)
const std = @import("std");
const web = @import("../web/mod.zig");

/// الحصول على معلومات الطقس لمدينة
pub fn getWeather(allocator: std.mem.Allocator, city: []const u8) ![]u8 {
    // استخدام wttr.in (مجاني، بدون API key)
    const url = try std.fmt.allocPrint(allocator, "https://wttr.in/{s}?format=%C+%t+%h+%w", .{city});
    defer allocator.free(url);

    var response = web.fetch(allocator, url, 4096) catch {
        return std.fmt.allocPrint(allocator, "تعذر جلب الطقس لمدينة {s}. تحقق من الاتصال.", .{city});
    };
    defer response.deinit();

    if (response.status == 200 and response.body.len > 0) {
        const weather_text = std.mem.trim(u8, response.body, " \t\n\r");
        return std.fmt.allocPrint(allocator,
            \\🌤️ الطقس في {s}:
            \\{s}
            \\(الحالة: درجة الحرارة: الرطوبة: الرياح:)
            , .{ city, weather_text });
    }

    return std.fmt.allocPrint(allocator, "تعذر جلب الطقس لمدينة {s}.", .{city});
}

/// الحصول على سعر عملة
pub fn getExchangeRate(allocator: std.mem.Allocator, from: []const u8, to: []const u8) ![]u8 {
    // استخدام open.er-api.com (مجاني)
    const url = try std.fmt.allocPrint(allocator, "https://open.er-api.com/v6/latest/{s}", .{from});
    defer allocator.free(url);

    var response = web.fetch(allocator, url, 8192) catch {
        return std.fmt.allocPrint(allocator, "تعذر جلب سعر الصرف.", .{});
    };
    defer response.deinit();

    if (response.status == 200 and response.body.len > 0) {
        // البحث عن السعر في JSON
        const search_key = try std.fmt.allocPrint(allocator, "\"{s}\":", .{to});
        defer allocator.free(search_key);

        if (std.mem.indexOf(u8, response.body, search_key)) |pos| {
            var start = pos + search_key.len;
            while (start < response.body.len and (response.body[start] == ' ' or response.body[start] == '"')) start += 1;
            var end = start;
            while (end < response.body.len and response.body[end] != ',' and response.body[end] != '}' and response.body[end] != ' ') end += 1;

            if (end > start) {
                const rate_str = response.body[start..end];
                return std.fmt.allocPrint(allocator,
                    \\💱 سعر الصرف:
                    \\1 {s} = {s} {s}
                    , .{ from, rate_str, to });
            }
        }
    }

    return std.fmt.allocPrint(allocator, "تعذر جلب سعر صرف {s} إلى {s}.", .{ from, to });
}

/// كشف هل الطلب عن الطقس
pub fn isWeatherQuery(input: []const u8) ?[]const u8 {
    const indicators = [_][]const u8{ "طقس", "الطقس", "حرارة", "weather", "temperature" };
    for (indicators) |ind| {
        if (std.mem.indexOf(u8, input, ind) != null) {
            // استخراج اسم المدينة
            const city_markers = [_][]const u8{ "في ", "in ", "بـ" };
            for (city_markers) |cm| {
                if (std.mem.indexOf(u8, input, cm)) |pos| {
                    const start = pos + cm.len;
                    var end = start;
                    while (end < input.len and input[end] != ' ' and input[end] != '.' and input[end] != '\n' and input[end] != '؟' and input[end] != '?') {
                        end += 1;
                    }
                    if (end > start) return input[start..end];
                }
            }
            return "Cairo"; // افتراضي
        }
    }
    return null;
}

/// كشف هل الطلب عن العملات
pub fn isCurrencyQuery(input: []const u8) ?struct { from: []const u8, to: []const u8 } {
    const indicators = [_][]const u8{ "سعر", "عملة", "صرف", "exchange", "currency", "dollar", "دولار", "يورو", "euro" };
    for (indicators) |ind| {
        if (std.mem.indexOf(u8, input, ind) != null) {
            // محاولة استخراج العملات
            if (std.mem.indexOf(u8, input, "دولار") != null or std.mem.indexOf(u8, input, "dollar") != null or std.mem.indexOf(u8, input, "USD") != null) {
                return .{ .from = "USD", .to = "EGP" };
            }
            if (std.mem.indexOf(u8, input, "يورو") != null or std.mem.indexOf(u8, input, "euro") != null or std.mem.indexOf(u8, input, "EUR") != null) {
                return .{ .from = "EUR", .to = "EGP" };
            }
            return .{ .from = "USD", .to = "EGP" };
        }
    }
    return null;
}
