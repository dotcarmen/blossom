const std = @import("std");
const Step = std.Build.Step;

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .cpu_model = .{ .explicit = &std.Target.aarch64.cpu.cortex_a72 },
        .os_tag = .uefi,
    });

    const kernel = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .code_model = .small,
        .optimize = optimize,
        .target = target,
    });

    const image = b.step("image", "build normal image");
    image.dependOn(step: {
        const compile_image = b.addExecutable(.{
            .name = "BOOTAA64",
            .root_module = kernel,
            .linkage = .static,
        });
        const image_artifact = b.addInstallArtifact(compile_image, .{
            .dest_dir = .{ .override = .{ .custom = "efi/boot" } },
        });
        break :step &image_artifact.step;
    });

    const test_image = b.step("test", "build image with tests");
    test_image.dependOn(step: {
        const compile_tests = b.addTest(.{
            .name = "BOOTAA64",
            .root_module = kernel,
            .test_runner = .{ .path = kernel.root_source_file.?, .mode = .simple },
        });
        const tests_artifact = b.addInstallArtifact(compile_tests, .{
            .dest_dir = .{ .override = .{ .custom = "efi/boot" } },
        });
        break :step &tests_artifact.step;
    });
}
