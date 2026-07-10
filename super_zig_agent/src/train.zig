// src/train.zig - نقطة دخول أداة التدريب
// تشغّل: train-agent [urls...]
const std = @import("std");
const nn = @import("nn/mod.zig");
const LanguageModel = @import("model.zig").LanguageModel;
const ModelConfig = @import("model.zig").ModelConfig;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Memory = @import("memory.zig").Memory;
const Trainer = @import("trainer.zig").Trainer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next(); // اسم البرنامج

    var urls = std.ArrayList([]const u8).init(allocator);
    defer urls.deinit();
    var files = std.ArrayList([]const u8).init(allocator);
    defer files.deinit();
    var continuous = false;
    var max_pages: usize = 20;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try printHelp();
            return;
        } else if (std.mem.eql(u8, arg, "--continuous")) {
            continuous = true;
        } else if (std.mem.eql(u8, arg, "--file")) {
            if (args.next()) |f| try files.append(f);
        } else if (std.mem.eql(u8, arg, "--max-pages")) {
            if (args.next()) |mp| {
                max_pages = std.fmt.parseInt(usize, mp, 10) catch 20;
            }
        } else if (std.mem.startsWith(u8, arg, "http")) {
            try urls.append(arg);
        }
    }

    std.debug.print("[train] initializing tokenizer...\n", .{});
    var tokenizer = try Tokenizer.init(allocator);
    defer tokenizer.deinit();

    // إضافة كلمات أساسية
    try addBasicVocabulary(&tokenizer);

    std.debug.print("[train] vocab size: {d}\n", .{tokenizer.vocab_size});

    std.debug.print("[train] initializing model...\n", .{});
    var rng = nn.tensor.createRng(42);
    var random = rng.random();

    const model_config = ModelConfig{
        .vocab_size = tokenizer.vocab_size,
        .embed_dim = 128, // خفيف
        .num_heads = 4,
        .num_layers = 2, // طبقتان فقط للسرعة
        .max_seq_len = 128,
        .ffn_ratio = 2,
    };

    var model = try LanguageModel.init(allocator, model_config, &random);
    defer model.deinit();

    std.debug.print("[train] model initialized. parameters: ~{d}\n", .{
        model_config.vocab_size * model_config.embed_dim +
            model_config.num_layers * (4 * model_config.embed_dim * model_config.embed_dim +
            2 * model_config.embed_dim * model_config.ffn_ratio * model_config.embed_dim) +
            model_config.embed_dim * model_config.vocab_size,
    });

    var memory = try Memory.init(allocator, "data/memory");
    defer memory.deinit();

    var trainer = Trainer.init(allocator, &model, &tokenizer, &memory);

    // تدريب على ملفات محلية أولاً
    for (files.items) |file| {
        std.debug.print("[train] training on file: {s}\n", .{file});
        const stats = trainer.trainFromFile(file) catch |err| {
            std.debug.print("[train] error: {}\n", .{err});
            continue;
        };
        std.debug.print("[train] file done. examples: {d}, avg_loss: {d:.4}\n", .{
            stats.examples, stats.avg_loss,
        });
    }

    // تدريب على نصوص أساسية مدمجة
    std.debug.print("[train] training on built-in text corpus...\n", .{});
    try trainOnBuiltinCorpus(&trainer);

    // تدريب من الويب
    if (urls.items.len > 0) {
        std.debug.print("[train] training from {d} URLs...\n", .{urls.items.len});
        trainer.trainFromWeb(urls.items, max_pages) catch |err| {
            std.debug.print("[train] web training error: {}\n", .{err});
        };
    }

    // التدريب المستمر
    if (continuous) {
        std.debug.print("[train] starting continuous learning...\n", .{});
        try trainer.continuousLearning(urls.items, 30);
    }

    // حفظ النموذج
    std.debug.print("[train] saving model...\n", .{});
    try model.save("data/model");

    // حفظ الـ tokenizer
    try std.fs.cwd().makePath("data/model");
    try tokenizer.save("data/model/tokenizer.txt");

    std.debug.print("[train] done! Model saved to data/model/\n", .{});
}

fn addBasicVocabulary(tok: *Tokenizer) !void {
    const words = [_][]const u8{
        // عربي - كلمات شائعة جداً
        "في", "من", "إلى", "على", "عن", "مع", "هذا", "هذه", "ذلك", "التي",
        "الذي", "كان", "كانت", "قد", "لقد", "ما", "كيف", "أين", "متى", "لماذا",
        "هو", "هي", "هم", "نحن", "أنا", "أنت", "لا", "نعم", "إذا", "أو",
        "ثم", "لكن", "أي", "كل", "بعض", "كثير", "قليل", "كبير", "صغير", "جديد",
        "قديم", "جيد", "سيء", "سهل", "صعب", "سريع", "بطيء", "قوي", "ضعيف",
        "اسمي", "أنا", "أنت", "نحن", "هو", "هي", "هم", "كنت", "تكون", "يكون",
        // ترحيب ومحادثة
        "مرحبا", "السلام", "عليكم", "أهلا", "سهلا", "صباح", "مساء", "خير",
        "شكرا", "عفوا", "آسف", "معذرة", "تفضل", "من", "فضلك",
        // أسئلة
        "ماذا", "كيف", "أين", "متى", "لماذا", "هل", "كم", "أي", "من",
        // موضوعات
        "ذكاء", "اصطناعي", "حاسوب", "برمجة", "كود", "نموذج", "بيانات", "تعلم",
        "إنترنت", "ويب", "صفحة", "نص", "كلمة", "جملة", "كتاب", "قراءة", "كتابة",
        "لغة", "عربية", "إنجليزية", "ترجمة", "سؤال", "جواب", "مساعدة", "خدمة",
        // إنجليزي
        "the", "be", "to", "of", "and", "a", "in", "that", "have", "I",
        "it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
        "this", "but", "his", "by", "from", "they", "we", "say", "her", "she",
        "or", "an", "will", "my", "one", "all", "would", "there", "their", "what",
        "hello", "world", "thank", "you", "please", "sorry", "yes", "no", "help",
        "computer", "programming", "code", "model", "data", "learning", "internet",
    };
    for (words) |w| {
        _ = try tok.addToken(w);
    }
}

fn trainOnBuiltinCorpus(trainer: *Trainer) !void {
    const corpus = [_][]const u8{
        "مرحبا بك في Super Agent. أنا وكيل ذكاء اصطناعي خارق خفيف الوزن.",
        "أعمل على أجهزة منخفضة الإمكانيات. أحتاج فقط 2 جيجابايت رام ومعالج 4 cores.",
        "لا أحتاج كارت شاشة. أتعلم من الإنترنت تلقائياً.",
        "أنا مبرمج بلغة Zig. Zig لغة سريعة وآمنة ومناسبة للأجهزة المنخفضة.",
        "الذكاء الاصطناعي هو محاكاة ذكاء البشر في الآلات.",
        "التعلم الآلي فرع من الذكاء الاصطناعي. يتعلم النموذج من البيانات.",
        "الشبكات العصبية محاكاة للدماغ البشري. تتكون من طبقات مترابطة.",
        "محولات الترانسفورمر أحدث ثورة في معالجة اللغة الطبيعية.",
        "Zig لغة برمجة systems. تتميز بالسرعة والأمان والتحكم الكامل.",
        "الإنترنت مصدر هائل للمعرفة. يمكن للوكيل التعلم منه تلقائياً.",
        "The quick brown fox jumps over the lazy dog.",
        "Artificial intelligence is the simulation of human intelligence in machines.",
        "Machine learning is a branch of AI. Models learn from data.",
        "Neural networks simulate the human brain. They consist of connected layers.",
        "Transformers revolutionized natural language processing.",
        "Zig is a systems programming language. It is fast and safe.",
    };

    for (corpus) |text| {
        _ = trainer.trainOnText(text) catch |err| {
            std.debug.print("[train] error on corpus: {}\n", .{err});
            continue;
        };
    }
    std.debug.print("[train] builtin corpus training done\n", .{});
}

fn printHelp() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        \\Super Agent Trainer - أداة تدريب الوكيل
        \\
        \\الاستخدام:
        \\  train-agent [options] [urls...]
        \\
        \\الخيارات:
        \\  -h, --help          عرض هذه المساعدة
        \\  --file <path>       التدريب على ملف نصي
        \\  --max-pages <n>     أقصى عدد صفحات ويب (افتراضي 20)
        \\  --continuous        تدريب مستمر دوري
        \\
        \\أمثلة:
        \\  train-agent
        \\  train-agent --file corpus.txt
        \\  train-agent https://example.com https://wikipedia.org
        \\  train-agent --continuous https://wikipedia.org
        \\
    , .{});
}
