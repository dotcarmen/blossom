const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .abi = .none,
            .ofmt = .elf,
            .os_tag = .freestanding,
        },
        .whitelist = &.{
            .{ .abi = .none, .ofmt = .elf, .os_tag = .freestanding },
        },
    });

    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });

    const blossomk = b.addModule("blossomk", .{
        .code_model = .kernel,
        .root_source_file = b.path(b.pathJoin(&.{ "src", "root.zig" })),
        .optimize = optimize,
        .target = target,
        .link_libc = false,
        .unwind_tables = .none,
    });

    const blossomk_exe = b.addExecutable(.{
        .name = "blossom",
        .root_module = blossomk,
        .linkage = .static,
    });
    blossomk_exe.setLinkerScript(b.path("kernel.ld"));

    b.installArtifact(blossomk_exe);

    // const run_step = b.step("run", "Run the app");

    // const run_cmd = b.addRunArtifact(exe);
    // run_step.dependOn(&run_cmd.step);

    // run_cmd.step.dependOn(b.getInstallStep());

    // if (b.args) |args| {
    //     run_cmd.addArgs(args);
    // }

    // const mod_tests = b.addTest(.{
    //     .root_module = mod,
    // });

    // const run_mod_tests = b.addRunArtifact(mod_tests);

    // const exe_tests = b.addTest(.{
    //     .root_module = exe.root_module,
    // });

    // const run_exe_tests = b.addRunArtifact(exe_tests);

    // const test_step = b.step("test", "Run tests");
    // test_step.dependOn(&run_mod_tests.step);
    // test_step.dependOn(&run_exe_tests.step);
}
