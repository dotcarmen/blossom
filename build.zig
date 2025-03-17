const std = @import("std");
const Step = std.Build.Step;

const image_dir = std.Build.InstallDir{
    .custom = "efi/boot",
};

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    _ = b.step("test", "build image with tests");

    const home = std.process.getEnvVarOwned(b.allocator, "HOME") catch |err| {
        std.log.err("error getting HOME: {any}", .{err});
        return;
    };

    var opts = b.addOptions();
    opts.addOption(
        usize,
        "page_size",
        b.option(
            usize,
            "page_size",
            "the page size to use for the kernel",
        ) orelse 4096, // 4K
    );
    const opts_mod = opts.createModule();

    const zig_repo = blk: {
        const p = std.fs.path.join(b.allocator, &.{
            home,
            "github.com/ziglang/zig/lib",
        }) catch |err| {
            std.log.err("error joining path: {any}", .{err});
            return;
        };
        break :blk std.Build.LazyPath{
            .cwd_relative = p,
        };
    };

    const kernel_target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .cpu_model = .{ .explicit = &std.Target.aarch64.cpu.cortex_a72 },
        .os_tag = .freestanding,
    });
    const kernel = b.createModule(.{
        .root_source_file = b.path("kernel/root.zig"),
        .code_model = .small,
        .optimize = optimize,
        .target = kernel_target,
    });
    kernel.addImport("options", opts_mod);
    image_steps(b, kernel, "blossomk", zig_repo);

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
    bootloader.addImport("options", opts_mod);
    image_steps(b, bootloader, "BOOTAA64", zig_repo);
}

fn image_steps(
    b: *std.Build,
    module: *std.Build.Module,
    name: []const u8,
    zig_lib_dir: ?std.Build.LazyPath,
) void {
    const compile_exe = b.addExecutable(.{
        .name = name,
        .root_module = module,
        .linkage = .static,
        .zig_lib_dir = zig_lib_dir,
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
        .zig_lib_dir = zig_lib_dir,
    });
    const test_artifact = b.addInstallArtifact(compile_test, .{
        .dest_dir = .{ .override = image_dir },
    });
    b.top_level_steps.get("test").?.step.dependOn(&test_artifact.step);
}
