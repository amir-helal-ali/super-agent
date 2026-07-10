// src/web/mod.zig
pub const http = @import("http.zig");
pub const crawler = @import("crawler.zig");

pub const HttpResponse = http.HttpResponse;
pub const Crawler = crawler.Crawler;
pub const fetch = http.fetch;
pub const extractText = crawler.extractText;
