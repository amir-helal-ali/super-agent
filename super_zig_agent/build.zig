// build.zig - إعداد بناء مشروع الوكيل الخارق
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });

    // === الوكيل الرئيسي ===
    const exe = b.addExecutable(.{
        .name = "super-agent",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = false,
    });

    // ربط libc لاستخدام sockets و threading
    exe.linkLibC();
    b.installArtifact(exe);

    // === أمر التشغيل ===
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the super agent");
    run_step.dependOn(&run_cmd.step);

    // === أمر التدريب ===
    const train_exe = b.addExecutable(.{
        .name = "train-agent",
        .root_source_file = b.path("src/train.zig"),
        .target = target,
        .optimize = optimize,
    });
    train_exe.linkLibC();
    b.installArtifact(train_exe);

    const train_cmd = b.addRunArtifact(train_exe);
    train_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        train_cmd.addArgs(args);
    }
    const train_step = b.step("train", "Train the agent from web data");
    train_step.dependOn(&train_cmd.step);

    // === الاختبارات ===
    const tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.linkLibC();
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
