const std = @import("std");
const Build = std.Build;
const Step = std.Build.Step;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .abi = .none,
            .ofmt = .elf,
            .os_tag = .freestanding,
        },
        .whitelist = &.{
            .{ .cpu_arch = .aarch64, .abi = .none, .ofmt = .elf, .os_tag = .freestanding },
        },
    });

    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });

    const otf = b.addModule("otf", .{
        .root_source_file = b.path(b.pathJoin(&.{ "otf", "root.zig" })),
        .target = target,
        .optimize = optimize,
    });

    const limine = b.dependency("limine", .{
        .api_revision = 3,
        .target = @as([]const u8, target.result.zigTriple(b.allocator) catch @panic("OOM")),
        .optimize = @as(std.builtin.OptimizeMode, if (optimize == .Debug) .ReleaseSafe else .ReleaseFast),
    });

    const blossom = b.addModule("blossom", .{
        .root_source_file = b.path(b.pathJoin(&.{ "src", "root.zig" })),
        .optimize = optimize,
        .target = target,
        .link_libc = false,
        .unwind_tables = .none,
    });
    blossom.addImport("limine", limine.module("limine"));
    blossom.addImport("otf", otf);

    const blossom_exe = b.addExecutable(.{
        .name = "blossom.elf",
        .root_module = blossom,
        .linkage = .static,
    });
    blossom_exe.setLinkerScript(b.path("kernel.ld"));
    b.installArtifact(blossom_exe);

    const iso_root = b.addWriteFiles();
    _ = iso_root.addCopyFile(
        blossom_exe.getEmittedBin(),
        b.pathJoin(&.{ "boot", "blossom.elf" }),
    );
    inline for (.{
        "limine-bios.sys",
        "limine-bios-cd.bin",
        "limine-uefi-cd.bin",
    }) |file|
        _ = iso_root.addCopyFile(
            limine.namedLazyPath(file),
            b.pathJoin(&.{ "boot", "limine", file }),
        );
    _ = iso_root.add("limine.conf",
        \\timeout: 3
        \\
        \\/BlossomOS
        \\    protocol: limine
        \\    kernel_path: boot():/boot/blossom.elf
        \\
    );

    const iso_root_dir = iso_root.getDirectory();

    // xorriso -as mkisofs -R -r -J -b boot/limine/limine-bios-cd.bin \
    //     -no-emul-boot -boot-load-size 4 -boot-info-table -hfsplus \
    //     -apm-block-size 2048 --efi-boot boot/limine/limine-uefi-cd.bin \
    //     -efi-boot-part --efi-boot-image --protective-msdos-label \
    //     <iso root directory> -o image.iso
    const build_iso = b.addSystemCommand(&.{
        "xorriso",        "-as",
        "mkisofs",        "-R",
        "-r",             "-J",
        "-b",             b.pathJoin(&.{ "boot", "limine", "limine-bios-cd.bin" }),
        "-no-emul-boot",  "-boot-load-size",
        "4",              "-boot-info-table",
        "-hfsplus",       "-apm-block-size",
        "2048",           "--efi-boot",
        b.pathJoin(&.{
            "boot",
            "limine",
            "limine-uefi-cd.bin",
        }),
        "-efi-boot-part", "--efi-boot-image",
        "--protective-msdos-label",
    });

    build_iso.addDirectoryArg(iso_root_dir);
    build_iso.addArg("-o");
    const base_blossom_iso = build_iso.addOutputFileArg("blossom.iso");
    build_iso.addCheck(.{ .expect_stderr_match = "ISO image produced:" });

    // limine bios-install image.iso
    const limine_bios_install = LimineBiosInstall.create(b, limine, base_blossom_iso);
    const blossom_iso = limine_bios_install.getEmittedIso();

    const install_blossom_iso = b.addInstallFile(blossom_iso, "blossom.iso");
    b.getInstallStep().dependOn(&install_blossom_iso.step);

    const run_qemu_uefi = b.addSystemCommand(
        switch (target.result.cpu.arch) {
            .aarch64 => &.{
                "qemu-system-aarch64", "-M",
                "virt",                "-cpu",
                "cortex-a72",          "-device",
                "ramfb",               "-device",
                "qemu-xhci",           "-device",
                "usb-kbd",             "-device",
                "usb-mouse",
            },
            else => unreachable,
        },
    );

    run_qemu_uefi.addArgs(
        b.option(
            []const []const u8,
            "qemu_opt",
            "Additional options for QEMU",
        ) orelse &.{ "-m", "2G" },
    );

    const ovmf = b.dependency("edk2_ovmf_nightly", .{});
    run_qemu_uefi.addArg("-drive");
    run_qemu_uefi.addPrefixedFileArg(
        "if=pflash,unit=0,readonly=on,format=raw,file=",
        ovmf_code_fd: switch (target.result.cpu.arch) {
            .aarch64 => {
                const trunc = Truncate.create(b, "64M", ovmf.path("ovmf-code-aarch64.fd"));
                break :ovmf_code_fd trunc.getTruncatedFile();
            },
            else => unreachable,
        },
    );

    run_qemu_uefi.addArg("-cdrom");
    run_qemu_uefi.addFileArg(blossom_iso);

    b.step("run-uefi", "Run BlossomOS with UEFI on qemu")
        .dependOn(&run_qemu_uefi.step);

    const test_otf = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path(b.pathJoin(&.{ "otf", "root.zig" })),
            .optimize = .Debug,
            .target = b.resolveTargetQuery(.{}),
        }),
        .name = "otf_test",
    });

    const run_test_otf = b.addRunArtifact(test_otf);

    const test_step = b.step("test", "run tests");
    test_step.dependOn(&run_test_otf.step);
}

// TODO: https://codeberg.org/ziglang/zig/issues/30658#issuecomment-9490664
pub const LimineBiosInstall = struct {
    pub const base_id: Step.Id = .custom;

    step: Step,
    cli: Build.LazyPath,
    iso: Build.LazyPath,
    output: Build.GeneratedFile,

    pub fn create(b: *Build, limine: *Build.Dependency, iso: Build.LazyPath) *LimineBiosInstall {
        const cli = limine.artifact("limine").getEmittedBin();

        const lbi = b.allocator.create(LimineBiosInstall) catch @panic("OOM");
        lbi.* = .{
            .step = .init(.{
                .id = base_id,
                .name = "limine bios-install",
                .owner = b,
                .makeFn = make,
            }),
            .cli = cli,
            .iso = iso,
            .output = .{ .step = &lbi.step },
        };
        iso.addStepDependencies(&lbi.step);
        cli.addStepDependencies(&lbi.step);

        return lbi;
    }

    pub fn getEmittedIso(lbi: *LimineBiosInstall) Build.LazyPath {
        return .{ .generated = .{ .file = &lbi.output } };
    }

    fn make(step: *Step, opts: Step.MakeOptions) !void {
        const lbi = step.cast(LimineBiosInstall).?;
        const gpa = step.owner.allocator;

        try step.addWatchInput(lbi.iso);

        var man = step.owner.graph.cache.obtain();
        defer man.deinit();

        const source_iso = lbi.iso.getPath3(step.owner, step);
        _ = try man.addFilePath(source_iso, null);

        const cache_hit = try step.cacheHit(&man);
        const digest = man.final();
        const output_file_path = step.owner.pathJoin(&.{ "iso", &digest, source_iso.basename() });
        const output_file_cache_path = try step.owner.cache_root.join(gpa, &.{output_file_path});

        lbi.output.path = output_file_cache_path;
        if (cache_hit) return;

        _ = try std.Io.Dir.cwd().updateFile(
            step.owner.graph.io,
            try source_iso.toString(gpa),
            step.owner.cache_root.handle.adaptToNewApi(),
            output_file_path,
            .{},
        );

        var argv: [3][]const u8 = .{
            try lbi.cli.getPath3(step.owner, step).toString(gpa),
            "bios-install",
            output_file_cache_path,
        };

        try step.handleChildProcUnsupported();
        step.result_failed_command = try Step.allocPrintCmd(gpa, null, &argv);
        try Step.handleVerbose(step.owner, null, &argv);

        var proc: std.process.Child = .init(&argv, gpa);
        proc.stdin_behavior = .Pipe;
        proc.stderr_behavior = .Pipe;
        proc.stdout_behavior = .Pipe;
        proc.progress_node = opts.progress_node;

        var stderr: std.ArrayList(u8) = .empty;
        var stdout: std.ArrayList(u8) = .empty;

        try proc.spawn();
        errdefer _ = proc.kill() catch {};

        try proc.collectOutput(gpa, &stdout, &stderr, 50 * 1024);
        const term = try proc.wait();
        step.handleChildProcessTerm(term) catch |err| {
            if (stderr.items.len > 0)
                try step.result_error_msgs.append(gpa, stderr.items);
            return err;
        };

        step.result_failed_command = null;
    }
};

// TODO: https://codeberg.org/ziglang/zig/issues/30658#issuecomment-9490664
pub const Truncate = struct {
    pub const base_id: Step.Id = .custom;

    step: Step,
    input: Build.LazyPath,
    size: []const u8,
    output: Build.GeneratedFile,

    pub fn create(b: *Build, size: []const u8, file: Build.LazyPath) *Truncate {
        const trunc = b.allocator.create(Truncate) catch @panic("OOM");
        trunc.* = .{
            .step = .init(.{
                .id = base_id,
                .name = "truncate",
                .owner = b,
                .makeFn = make,
            }),
            .input = file,
            .size = size,
            .output = .{ .step = &trunc.step },
        };
        file.addStepDependencies(&trunc.step);

        return trunc;
    }

    pub fn getTruncatedFile(trunc: *Truncate) Build.LazyPath {
        return .{ .generated = .{ .file = &trunc.output } };
    }

    fn make(step: *Step, opts: Step.MakeOptions) !void {
        const trunc = step.cast(Truncate).?;
        const gpa = step.owner.allocator;

        try step.addWatchInput(trunc.input);

        var man = step.owner.graph.cache.obtain();
        defer man.deinit();

        const source_file = trunc.input.getPath3(step.owner, step);
        _ = try man.addFilePath(source_file, null);

        const cache_hit = try step.cacheHit(&man);
        const digest = man.final();
        const output_file_path = step.owner.pathJoin(&.{ "o", &digest, source_file.basename() });
        const output_file_cache_path = try step.owner.cache_root.join(gpa, &.{output_file_path});

        trunc.output.path = output_file_cache_path;
        if (cache_hit) return;

        _ = try std.Io.Dir.cwd().updateFile(
            step.owner.graph.io,
            try source_file.toString(gpa),
            step.owner.cache_root.handle.adaptToNewApi(),
            output_file_path,
            .{},
        );

        var argv: [5][]const u8 = .{
            "truncate", "-c", "-s", trunc.size, try source_file.toString(gpa),
        };

        try step.handleChildProcUnsupported();
        step.result_failed_command = try Step.allocPrintCmd(gpa, null, &argv);
        try Step.handleVerbose(step.owner, null, &argv);

        var proc: std.process.Child = .init(&argv, gpa);
        proc.stdin_behavior = .Pipe;
        proc.stderr_behavior = .Pipe;
        proc.stdout_behavior = .Pipe;
        proc.progress_node = opts.progress_node;

        var stderr: std.ArrayList(u8) = .empty;
        var stdout: std.ArrayList(u8) = .empty;

        try proc.spawn();
        errdefer _ = proc.kill() catch {};

        try proc.collectOutput(gpa, &stdout, &stderr, 50 * 1024);
        const term = try proc.wait();
        if (stderr.items.len > 0)
            try step.result_error_msgs.append(gpa, stderr.items);
        try step.handleChildProcessTerm(term);
        step.result_failed_command = null;
    }
};
