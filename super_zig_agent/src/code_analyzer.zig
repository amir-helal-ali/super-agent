// src/code_analyzer.zig - تحليل وتصحيح وتوليد الكود البرمجي
const std = @import("std");

pub const CodeAnalyzer = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CodeAnalyzer {
        return .{ .allocator = allocator };
    }

    /// كشف هل الطلب يحتاج كود
    pub fn isCodeRequest(input: []const u8) bool {
        const code_indicators = [_][]const u8{
            "اكتب كود", "اكتب برنامج", "اكتب دالة", "اكتب function",
            "write code", "write a function", "write a program",
            "كيف اكتب", "كيف أكتب", "how to write",
            "مثال برمجي", "code example", "snippet",
            "حلل كود", "صحح كود", "debug", "fix code",
            "اشرح كود", "explain code",
        };
        for (code_indicators) |ind| {
            if (std.mem.indexOf(u8, input, ind) != null) return true;
        }
        return false;
    }

    /// توليد كود بناءً على الطلب
    pub fn generate(self: *CodeAnalyzer, input: []const u8) ![]u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        defer buf.deinit();

        // كشف اللغة
        const lang = self.detectLanguage(input);
        // كشف الموضوع
        const topic = self.detectTopic(input);

        try buf.appendSlice("💻 إليك الكود المطلوب:\n\n");

        switch (lang) {
            .zig => try self.generateZig(&buf, topic),
            .python => try self.generatePython(&buf, topic),
            .javascript => try self.generateJavaScript(&buf, topic),
            .rust => try self.generateRust(&buf, topic),
            .general => try self.generateGeneral(&buf, topic),
        }

        return buf.toOwnedSlice();
    }

    fn detectLanguage(self: *CodeAnalyzer, input: []const u8) Language {
        _ = self;
        if (std.mem.indexOf(u8, input, "zig") != null) return .zig;
        if (std.mem.indexOf(u8, input, "python") != null or std.mem.indexOf(u8, input, "بايثون") != null) return .python;
        if (std.mem.indexOf(u8, input, "javascript") != null or std.mem.indexOf(u8, input, "js") != null or std.mem.indexOf(u8, input, "جافاسكريبت") != null) return .javascript;
        if (std.mem.indexOf(u8, input, "rust") != null or std.mem.indexOf(u8, input, "راست") != null) return .rust;
        return .general;
    }

    fn detectTopic(self: *CodeAnalyzer, input: []const u8) CodeTopic {
        _ = self;
        if (std.mem.indexOf(u8, input, "factorial") != null or std.mem.indexOf(u8, input, "مضروب") != null) return .factorial;
        if (std.mem.indexOf(u8, input, "fibonacci") != null or std.mem.indexOf(u8, input, "فيبوناتشي") != null) return .fibonacci;
        if (std.mem.indexOf(u8, input, "sort") != null or std.mem.indexOf(u8, input, "ترتيب") != null) return .sort;
        if (std.mem.indexOf(u8, input, "search") != null or std.mem.indexOf(u8, input, "بحث") != null) return .search;
        if (std.mem.indexOf(u8, input, "prime") != null or std.mem.indexOf(u8, input, "أولي") != null) return .prime;
        if (std.mem.indexOf(u8, input, "hello") != null or std.mem.indexOf(u8, input, "مرحبا") != null) return .hello;
        if (std.mem.indexOf(u8, input, "palindrome") != null or std.mem.indexOf(u8, input, "متناظرة") != null) return .palindrome;
        if (std.mem.indexOf(u8, input, "reverse") != null or std.mem.indexOf(u8, input, "عكس") != null) return .reverse;
        if (std.mem.indexOf(u8, input, "sum") != null or std.mem.indexOf(u8, input, "مجموع") != null) return .sum;
        if (std.mem.indexOf(u8, input, "list") != null or std.mem.indexOf(u8, input, "قائمة") != null) return .list;
        return .general;
    }

    fn generateZig(self: *CodeAnalyzer, buf: *std.ArrayList(u8), topic: CodeTopic) !void {
        _ = self;
        try buf.appendSlice("```zig\n");
        try buf.appendSlice("const std = @import(\"std\");\n\n");

        switch (topic) {
            .factorial => {
                try buf.appendSlice("pub fn factorial(n: u64) u64 {\n");
                try buf.appendSlice("    if (n <= 1) return 1;\n");
                try buf.appendSlice("    return n * factorial(n - 1);\n");
                try buf.appendSlice("}\n\n");
                try buf.appendSlice("pub fn main() !void {\n");
                try buf.appendSlice("    const result = factorial(5);\n");
                try buf.appendSlice("    std.debug.print(\"5! = {d}\\n\", .{result});\n");
                try buf.appendSlice("}\n");
            },
            .fibonacci => {
                try buf.appendSlice("pub fn fibonacci(n: u32) u64 {\n");
                try buf.appendSlice("    if (n <= 1) return n;\n");
                try buf.appendSlice("    return fibonacci(n - 1) + fibonacci(n - 2);\n");
                try buf.appendSlice("}\n");
            },
            .hello => {
                try buf.appendSlice("pub fn main() !void {\n");
                try buf.appendSlice("    const stdout = std.io.getStdOut().writer();\n");
                try buf.appendSlice("    try stdout.print(\"مرحبا من Zig!\\n\", .{});\n");
                try buf.appendSlice("}\n");
            },
            .prime => {
                try buf.appendSlice("pub fn isPrime(n: u32) bool {\n");
                try buf.appendSlice("    if (n < 2) return false;\n");
                try buf.appendSlice("    var i: u32 = 2;\n");
                try buf.appendSlice("    while (i * i <= n) : (i += 1) {\n");
                try buf.appendSlice("        if (n % i == 0) return false;\n");
                try buf.appendSlice("    }\n");
                try buf.appendSlice("    return true;\n");
                try buf.appendSlice("}\n");
            },
            .reverse => {
                try buf.appendSlice("pub fn reverseString(s: []u8) void {\n");
                try buf.appendSlice("    var left: usize = 0;\n");
                try buf.appendSlice("    var right: usize = s.len - 1;\n");
                try buf.appendSlice("    while (left < right) {\n");
                try buf.appendSlice("        const tmp = s[left];\n");
                try buf.appendSlice("        s[left] = s[right];\n");
                try buf.appendSlice("        s[right] = tmp;\n");
                try buf.appendSlice("        left += 1;\n");
                try buf.appendSlice("        right -= 1;\n");
                try buf.appendSlice("    }\n");
                try buf.appendSlice("}\n");
            },
            else => {
                try buf.appendSlice("pub fn main() !void {\n");
                try buf.appendSlice("    const stdout = std.io.getStdOut().writer();\n");
                try buf.appendSlice("    try stdout.print(\"Hello from Zig!\\n\", .{});\n");
                try buf.appendSlice("}\n");
            },
        }

        try buf.appendSlice("```\n\n");
        try buf.appendSlice("⚡ Zig سريعة وآمنة - تجمع بين قوة C وأمان Rust.");
    }

    fn generatePython(self: *CodeAnalyzer, buf: *std.ArrayList(u8), topic: CodeTopic) !void {
        _ = self;
        try buf.appendSlice("```python\n");

        switch (topic) {
            .factorial => {
                try buf.appendSlice("def factorial(n):\n");
                try buf.appendSlice("    if n <= 1:\n");
                try buf.appendSlice("        return 1\n");
                try buf.appendSlice("    return n * factorial(n - 1)\n\n");
                try buf.appendSlice("print(f\"5! = {factorial(5)}\")\n");
            },
            .fibonacci => {
                try buf.appendSlice("def fibonacci(n):\n");
                try buf.appendSlice("    if n <= 1:\n");
                try buf.appendSlice("        return n\n");
                try buf.appendSlice("    return fibonacci(n - 1) + fibonacci(n - 2)\n\n");
                try buf.appendSlice("for i in range(10):\n");
                try buf.appendSlice("    print(fibonacci(i), end=\" \")\n");
            },
            .sort => {
                try buf.appendSlice("def bubble_sort(arr):\n");
                try buf.appendSlice("    n = len(arr)\n");
                try buf.appendSlice("    for i in range(n):\n");
                try buf.appendSlice("        for j in range(0, n - i - 1):\n");
                try buf.appendSlice("            if arr[j] > arr[j + 1]:\n");
                try buf.appendSlice("                arr[j], arr[j + 1] = arr[j + 1], arr[j]\n");
                try buf.appendSlice("    return arr\n\n");
                try buf.appendSlice("print(bubble_sort([64, 34, 25, 12, 22]))\n");
            },
            .prime => {
                try buf.appendSlice("def is_prime(n):\n");
                try buf.appendSlice("    if n < 2:\n");
                try buf.appendSlice("        return False\n");
                try buf.appendSlice("    for i in range(2, int(n**0.5) + 1):\n");
                try buf.appendSlice("        if n % i == 0:\n");
                try buf.appendSlice("            return False\n");
                try buf.appendSlice("    return True\n\n");
                try buf.appendSlice("primes = [x for x in range(2, 50) if is_prime(x)]\n");
                try buf.appendSlice("print(primes)\n");
            },
            .palindrome => {
                try buf.appendSlice("def is_palindrome(s):\n");
                try buf.appendSlice("    s = s.lower().replace(\" \", \"\")\n");
                try buf.appendSlice("    return s == s[::-1]\n\n");
                try buf.appendSlice("print(is_palindrome(\"racecar\"))  # True\n");
                try buf.appendSlice("print(is_palindrome(\"hello\"))    # False\n");
            },
            .reverse => {
                try buf.appendSlice("def reverse_string(s):\n");
                try buf.appendSlice("    return s[::-1]\n\n");
                try buf.appendSlice("print(reverse_string(\"Hello World\"))\n");
            },
            .sum => {
                try buf.appendSlice("def sum_list(numbers):\n");
                try buf.appendSlice("    total = 0\n");
                try buf.appendSlice("    for num in numbers:\n");
                try buf.appendSlice("        total += num\n");
                try buf.appendSlice("    return total\n\n");
                try buf.appendSlice("print(sum_list([1, 2, 3, 4, 5]))  # 15\n");
            },
            .hello => {
                try buf.appendSlice("def greet(name):\n");
                try buf.appendSlice("    return f\"مرحبا {name}!\"\n\n");
                try buf.appendSlice("print(greet(\"عالم\"))\n");
            },
            else => {
                try buf.appendSlice("# مثال Python\n");
                try buf.appendSlice("def main():\n");
                try buf.appendSlice("    print(\"Hello from Python!\")\n\n");
                try buf.appendSlice("if __name__ == \"__main__\":\n");
                try buf.appendSlice("    main()\n");
            },
        }

        try buf.appendSlice("```\n\n");
        try buf.appendSlice("🐍 Python سهلة وقوية - مثالية للمبتدئين والـ AI.");
    }

    fn generateJavaScript(self: *CodeAnalyzer, buf: *std.ArrayList(u8), topic: CodeTopic) !void {
        _ = self;
        try buf.appendSlice("```javascript\n");

        switch (topic) {
            .factorial => {
                try buf.appendSlice("function factorial(n) {\n");
                try buf.appendSlice("    if (n <= 1) return 1;\n");
                try buf.appendSlice("    return n * factorial(n - 1);\n");
                try buf.appendSlice("}\n\n");
                try buf.appendSlice("console.log(`5! = ${factorial(5)}`);\n");
            },
            .fibonacci => {
                try buf.appendSlice("function fibonacci(n) {\n");
                try buf.appendSlice("    if (n <= 1) return n;\n");
                try buf.appendSlice("    return fibonacci(n - 1) + fibonacci(n - 2);\n");
                try buf.appendSlice("}\n\n");
                try buf.appendSlice("const fib = Array.from({length: 10}, (_, i) => fibonacci(i));\n");
                try buf.appendSlice("console.log(fib.join(' '));\n");
            },
            .sort => {
                try buf.appendSlice("function bubbleSort(arr) {\n");
                try buf.appendSlice("    const n = arr.length;\n");
                try buf.appendSlice("    for (let i = 0; i < n; i++) {\n");
                try buf.appendSlice("        for (let j = 0; j < n - i - 1; j++) {\n");
                try buf.appendSlice("            if (arr[j] > arr[j + 1]) {\n");
                try buf.appendSlice("                [arr[j], arr[j + 1]] = [arr[j + 1], arr[j]];\n");
                try buf.appendSlice("            }\n");
                try buf.appendSlice("        }\n");
                try buf.appendSlice("    }\n");
                try buf.appendSlice("    return arr;\n");
                try buf.appendSlice("}\n\n");
                try buf.appendSlice("console.log(bubbleSort([64, 34, 25, 12, 22]));\n");
            },
            .palindrome => {
                try buf.appendSlice("function isPalindrome(s) {\n");
                try buf.appendSlice("    const clean = s.toLowerCase().replace(/\\s/g, '');\n");
                try buf.appendSlice("    return clean === clean.split('').reverse().join('');\n");
                try buf.appendSlice("}\n\n");
                try buf.appendSlice("console.log(isPalindrome('racecar')); // true\n");
            },
            .reverse => {
                try buf.appendSlice("function reverseString(s) {\n");
                try buf.appendSlice("    return s.split('').reverse().join('');\n");
                try buf.appendSlice("}\n\n");
                try buf.appendSlice("console.log(reverseString('Hello World'));\n");
            },
            .hello => {
                try buf.appendSlice("function greet(name) {\n");
                try buf.appendSlice("    return `مرحبا ${name}!`;\n");
                try buf.appendSlice("}\n\n");
                try buf.appendSlice("console.log(greet('عالم'));\n");
            },
            else => {
                try buf.appendSlice("// مثال JavaScript\n");
                try buf.appendSlice("function main() {\n");
                try buf.appendSlice("    console.log('Hello from JavaScript!');\n");
                try buf.appendSlice("}\n\n");
                try buf.appendSlice("main();\n");
            },
        }

        try buf.appendSlice("```\n\n");
        try buf.appendSlice("🌐 JavaScript تعمل في كل مكان - المتصفح والخادم.");
    }

    fn generateRust(self: *CodeAnalyzer, buf: *std.ArrayList(u8), topic: CodeTopic) !void {
        _ = self;
        try buf.appendSlice("```rust\n");

        switch (topic) {
            .factorial => {
                try buf.appendSlice("fn factorial(n: u64) -> u64 {\n");
                try buf.appendSlice("    if n <= 1 { return 1; }\n");
                try buf.appendSlice("    n * factorial(n - 1)\n");
                try buf.appendSlice("}\n\n");
                try buf.appendSlice("fn main() {\n");
                try buf.appendSlice("    println!(\"5! = {}\", factorial(5));\n");
                try buf.appendSlice("}\n");
            },
            .hello => {
                try buf.appendSlice("fn main() {\n");
                try buf.appendSlice("    println!(\"مرحبا من Rust!\");\n");
                try buf.appendSlice("}\n");
            },
            else => {
                try buf.appendSlice("fn main() {\n");
                try buf.appendSlice("    println!(\"Hello from Rust!\");\n");
                try buf.appendSlice("}\n");
            },
        }

        try buf.appendSlice("```\n\n");
        try buf.appendSlice("🦀 Rust آمنة وسريعة - بديل حديث لـ C++.");
    }

    fn generateGeneral(self: *CodeAnalyzer, buf: *std.ArrayList(u8), _: CodeTopic) !void {
        _ = self;
        try buf.appendSlice("اختر لغة برمجة وسأساعدك:\n\n");
        try buf.appendSlice("• `اكتب كود Python لحساب المضروب`\n");
        try buf.appendSlice("• `اكتب كود Zig لفحص الأرقام الأولية`\n");
        try buf.appendSlice("• `اكتب كود JavaScript لترتيب مصفوفة`\n");
        try buf.appendSlice("• `اكتب كود Rust لطباعة привет`\n\n");
        try buf.appendSlice("المواضيع المتاحة:\n");
        try buf.appendSlice("factorial, fibonacci, sort, search, prime, palindrome, reverse, sum\n");
    }
};

const Language = enum { zig, python, javascript, rust, general };
const CodeTopic = enum { factorial, fibonacci, sort, search, prime, hello, palindrome, reverse, sum, list, general };
