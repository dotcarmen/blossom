const std = @import("std");
const Step = std.Build.Step;

const parseTargetQuery = std.Build.parseTargetQuery;

const image_dir = std.Build.InstallDir{
    .custom = "efi/boot",
};

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const arch = b.option(
        []const u8,
        "arch",
        "the target architecture to build for",
    ) orelse "native";
    const mcpu = b.option(
        []const u8,
        "cpu",
        "Target CPU features to add or subtract",
    );

    const install_step = b.getInstallStep();
    const test_step = b.step("test", "build image with tests");

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

    const zig_lib_dir = b.path("zig/lib");

    const kernel_target = try parseTargetQuery(.{
        .arch_os_abi = b.fmt("{s}-freestanding-none", .{arch}),
        .cpu_features = mcpu,
    });
    const kernel = b.createModule(.{
        .root_source_file = b.path("kernel/root.zig"),
        .code_model = .small,
        .optimize = optimize,
        .unwind_tables = .none,
        .target = b.resolveTargetQuery(kernel_target),
    });
    kernel.addImport("$kernel", kernel);
    kernel.addImport("$options", opts_mod);
    image_steps(b, kernel, "blossomk", zig_lib_dir, .{
        .linker_script = b.path("kernel.ld"),
        .install_step = install_step,
        .test_step = test_step,
    });

    const bootloader_target = try parseTargetQuery(.{
        .arch_os_abi = b.fmt("{s}-uefi-none", .{arch}),
        .cpu_features = mcpu,
    });
    const bootloader = b.createModule(.{
        .root_source_file = b.path("boot/root.zig"),
        .code_model = .small,
        .optimize = optimize,
        .target = b.resolveTargetQuery(bootloader_target),
    });
    bootloader.addImport("$kernel", kernel);
    image_steps(b, bootloader, "BOOTAA64", zig_lib_dir, .{
        .install_step = install_step,
        .test_step = test_step,
    });
}

fn image_steps(
    b: *std.Build,
    module: *std.Build.Module,
    name: []const u8,
    zig_lib_dir: ?std.Build.LazyPath,
    opts: struct {
        linker_script: ?std.Build.LazyPath = null,
        install_step: *Step,
        test_step: *Step,
    },
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
    opts.install_step.dependOn(&exe_artifact.step);

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
    opts.test_step.dependOn(&test_artifact.step);

    if (opts.linker_script) |s| {
        compile_exe.setLinkerScript(s);
        compile_test.setLinkerScript(s);
    }
}
