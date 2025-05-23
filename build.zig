const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const strip = b.option(
        bool,
        "strip",
        "Whether to strip debug symbols",
    );
    const log_level: std.log.Level = b.option(
        std.log.Level,
        "log-level",
        "Log level",
    ) orelse
        if (optimize == .Debug)
            .debug
        else
            .err;
    const options = b.addOptions();
    options.addOption(std.log.Level, "log_level", log_level);
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
        .imports = &.{
            .{ .name = "build_params", .module = options.createModule() },
        },
    });
    const exe = b.addExecutable(.{
        .name = "Sodusolver",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
