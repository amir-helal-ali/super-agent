// src/tools/translator.zig - مترجم عربي-إنجليزي-فرنسي-إسباني
const std = @import("std");

const DictEntry = struct { ar: []const u8, en: []const u8, fr: []const u8, es: []const u8 };
const DICT = [_]DictEntry{
    .{ .ar = "مرحبا", .en = "hello", .fr = "bonjour", .es = "hola" },
    .{ .ar = "السلام", .en = "peace", .fr = "paix", .es = "paz" },
    .{ .ar = "عليكم", .en = "upon you", .fr = "sur vous", .es = "sobre ti" },
    .{ .ar = "كيف", .en = "how", .fr = "comment", .es = "como" },
    .{ .ar = "شكرا", .en = "thank you", .fr = "merci", .es = "gracias" },
    .{ .ar = "نعم", .en = "yes", .fr = "oui", .es = "si" },
    .{ .ar = "لا", .en = "no", .fr = "non", .es = "no" },
    .{ .ar = "من", .en = "from", .fr = "de", .es = "de" },
    .{ .ar = "إلى", .en = "to", .fr = "a", .es = "a" },
    .{ .ar = "في", .en = "in", .fr = "dans", .es = "en" },
    .{ .ar = "على", .en = "on", .fr = "sur", .es = "en" },
    .{ .ar = "مع", .en = "with", .fr = "avec", .es = "con" },
    .{ .ar = "أنا", .en = "I", .fr = "je", .es = "yo" },
    .{ .ar = "أنت", .en = "you", .fr = "tu", .es = "tu" },
    .{ .ar = "هو", .en = "he", .fr = "il", .es = "el" },
    .{ .ar = "هي", .en = "she", .fr = "elle", .es = "ella" },
    .{ .ar = "نحن", .en = "we", .fr = "nous", .es = "nosotros" },
    .{ .ar = "هم", .en = "they", .fr = "ils", .es = "ellos" },
    .{ .ar = "كتاب", .en = "book", .fr = "livre", .es = "libro" },
    .{ .ar = "ماء", .en = "water", .fr = "eau", .es = "agua" },
    .{ .ar = "طعام", .en = "food", .fr = "nourriture", .es = "comida" },
    .{ .ar = "شمس", .en = "sun", .fr = "soleil", .es = "sol" },
    .{ .ar = "قمر", .en = "moon", .fr = "lune", .es = "luna" },
    .{ .ar = "سماء", .en = "sky", .fr = "ciel", .es = "cielo" },
    .{ .ar = "أرض", .en = "earth", .fr = "terre", .es = "tierra" },
    .{ .ar = "بحر", .en = "sea", .fr = "mer", .es = "mar" },
    .{ .ar = "جبل", .en = "mountain", .fr = "montagne", .es = "montana" },
    .{ .ar = "شجرة", .en = "tree", .fr = "arbre", .es = "arbol" },
    .{ .ar = "حب", .en = "love", .fr = "amour", .es = "amor" },
    .{ .ar = "عالم", .en = "world", .fr = "monde", .es = "mundo" },
    .{ .ar = "ذكاء", .en = "intelligence", .fr = "intelligence", .es = "inteligencia" },
    .{ .ar = "اصطناعي", .en = "artificial", .fr = "artificiel", .es = "artificial" },
    .{ .ar = "حاسوب", .en = "computer", .fr = "ordinateur", .es = "computadora" },
    .{ .ar = "برمجة", .en = "programming", .fr = "programmation", .es = "programacion" },
    .{ .ar = "كود", .en = "code", .fr = "code", .es = "codigo" },
    .{ .ar = "إنترنت", .en = "internet", .fr = "internet", .es = "internet" },
    .{ .ar = "بيانات", .en = "data", .fr = "donnees", .es = "datos" },
    .{ .ar = "نموذج", .en = "model", .fr = "modele", .es = "modelo" },
    .{ .ar = "تعلم", .en = "learning", .fr = "apprentissage", .es = "aprendizaje" },
};

pub fn translate(allocator: std.mem.Allocator, text: []const u8, target_lang: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();
    var it = std.mem.tokenizeAny(u8, text, " \t\n\r.,;:!?'\"()[]{}");
    var first = true;
    while (it.next()) |word| {
        if (!first) try result.append(' ');
        first = false;
        const translated = translateWord(word, target_lang);
        if (translated) |t| { try result.appendSlice(t); } else { try result.appendSlice(word); }
    }
    return result.toOwnedSlice();
}

fn translateWord(word: []const u8, target_lang: []const u8) ?[]const u8 {
    for (DICT) |entry| {
        if (std.mem.eql(u8, target_lang, "en")) {
            if (std.mem.eql(u8, entry.ar, word)) return entry.en;
            if (std.ascii.eqlIgnoreCase(entry.fr, word)) return entry.en;
            if (std.ascii.eqlIgnoreCase(entry.es, word)) return entry.en;
        } else if (std.mem.eql(u8, target_lang, "ar")) {
            if (std.ascii.eqlIgnoreCase(entry.en, word)) return entry.ar;
            if (std.ascii.eqlIgnoreCase(entry.fr, word)) return entry.ar;
            if (std.ascii.eqlIgnoreCase(entry.es, word)) return entry.ar;
        } else if (std.mem.eql(u8, target_lang, "fr")) {
            if (std.mem.eql(u8, entry.ar, word)) return entry.fr;
            if (std.ascii.eqlIgnoreCase(entry.en, word)) return entry.fr;
            if (std.ascii.eqlIgnoreCase(entry.es, word)) return entry.fr;
        } else if (std.mem.eql(u8, target_lang, "es")) {
            if (std.mem.eql(u8, entry.ar, word)) return entry.es;
            if (std.ascii.eqlIgnoreCase(entry.en, word)) return entry.es;
            if (std.ascii.eqlIgnoreCase(entry.fr, word)) return entry.es;
        }
    }
    return null;
}
