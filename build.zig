const std = @import("std");
const Step = std.Build.Step;

const image_dir = std.Build.InstallDir{
    .custom = "efi/boot",
};

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    _ = b.step("test", "build image with tests");

    // const kernel_target = b.resolveTargetQuery(.{
    //     .cpu_arch = .aarch64,
    //     .cpu_model = .{ .explicit = &std.Target.aarch64.cpu.cortex_a72 },
    //     .os_tag = .freestanding,
    // });
    // const kernel = b.createModule(.{
    //     .root_source_file = b.path("kernel/root.zig"),
    //     .code_model = .small,
    //     .optimize = optimize,
    //     .target = kernel_target,
    // });
    // image_steps(b, kernel, "blossomk");

    const boot_target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .cpu_model = .{ .explicit = &std.Target.aarch64.cpu.cortex_a72 },
        .os_tag = .uefi,
    });
    const bootloader = b.createModule(.{
        .root_source_file = b.path("boot/root.zig"),
        .code_model = .small,
        .optimize = optimize,
        .target = boot_target,
    });
    image_steps(b, bootloader, "BOOTAA64");
}

fn image_steps(b: *std.Build, module: *std.Build.Module, name: []const u8) void {
    const compile_exe = b.addExecutable(.{
        .name = name,
        .root_module = module,
        .linkage = .static,
    });
    const exe_artifact = b.addInstallArtifact(compile_exe, .{
        .dest_dir = .{ .override = image_dir },
    });
    b.getInstallStep().dependOn(&exe_artifact.step);

    const compile_test = b.addTest(.{
        .name = name,
        .root_module = module,
        .test_runner = .{
            .mode = .simple,
            .path = module.root_source_file.?,
        },
    });
    const test_artifact = b.addInstallArtifact(compile_test, .{
        .dest_dir = .{ .override = image_dir },
    });
    b.top_level_steps.get("test").?.step.dependOn(&test_artifact.step);
}
