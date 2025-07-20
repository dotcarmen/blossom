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

    const limine = b.dependency("limine", .{
        .api_revision = 3,
    });

    const blossom = b.addModule("blossom", .{
        .root_source_file = b.path(b.pathJoin(&.{ "src", "root.zig" })),
        .optimize = optimize,
        .target = target,
        .link_libc = false,
        .unwind_tables = .none,
    });
    blossom.addImport("limine", limine.module("limine"));

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
    const blossom_iso = build_iso.addOutputFileArg("blossom.iso");

    // limine bios-install image.iso
    const limine_bios_install = std.Build.Step.Run.create(b, "run limine bios-install");
    limine_bios_install.addFileArg(limine.artifact("limine").getEmittedBin());
    limine_bios_install.addArg("bios-install");
    limine_bios_install.addFileArg(blossom_iso);
    limine_bios_install.has_side_effects = true;

    b.getInstallStep().dependOn(install_blossom_iso: {
        const install_step = b.addInstallFile(blossom_iso, "blossom.iso");
        install_step.step.dependOn(&limine_bios_install.step);
        break :install_blossom_iso &install_step.step;
    });

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
