const std = @import("std");
const Step = std.Build.Step;

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .cpu_model = .{ .explicit = &std.Target.aarch64.cpu.cortex_a72 },
        .os_tag = .uefi,
    });

    const src = b.path("src");
    // const is_test = b.addUserInputFlag("run-tests") catch @panic("oom");
    // const is_test = false;

    const kernel = b.createModule(.{
        .root_source_file = src.path(b, "root.zig"),
        .code_model = .small,
        .optimize = optimize,
        .target = target,
    });

    const kmain_file = src.path(b, "main.zig");
    const kmain = b.createModule(.{
        .root_source_file = kmain_file,
        .code_model = .small,
        .optimize = optimize,
        .target = target,
    });

    const image = b.addExecutable(.{
        .name = "BOOTAA64",
        .root_module = kmain,
        .linkage = .static,
    });

    const install_image = b.addInstallArtifact(image, .{
        .dest_dir = .{ .override = .{ .custom = "esp/efi/boot" } },
    });

    b.getInstallStep().dependOn(&install_image.step);

    const vars_fd = blk: {
        const make_file = b.addWriteFiles();
        const path = make_file.add("vars.fd", &.{});

        const truncate = std.Build.Step.Run.create(b, "truncate vars.fd");
        truncate.addArgs(&.{ "truncate", "-s", "64M" });
        truncate.addFileArg(path);
        b.getInstallStep().dependOn(&truncate.step);

        break :blk path;
    };

    const install_vars_fd = b.addInstallFile(vars_fd, "vars.fd");
    b.getInstallStep().dependOn(&install_vars_fd.step);

    const tests = b.addTest(.{
        .name = "BOOTAA64",
        .root_module = kernel,
        .test_runner = .{ .path = kmain_file, .mode = .simple },
    });
    tests.step.dependOn(&install_vars_fd.step);

    const build_tests = b.addInstallArtifact(tests, .{
        .dest_dir = .{ .override = .{ .custom = "esp/efi/boot" } },
    });

    const run_tests = b.step("test", "build test binary");
    run_tests.dependOn(&build_tests.step);
}
