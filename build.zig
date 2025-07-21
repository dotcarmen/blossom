const std = @import("std");
const Build = std.Build;

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
    const base_blossom_iso = build_iso.addOutputFileArg("blossom.iso");

    // limine bios-install image.iso
    const limine_bios_install = std.Build.Step.Run.create(b, "run limine bios-install");
    limine_bios_install.addFileArg(limine.artifact("limine").getEmittedBin());
    limine_bios_install.addArg("bios-install");
    const blossom_iso = limine_bios_install.addModifyPathArg(base_blossom_iso);

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
                const workdir = b.addWriteFiles();
                const copied_ovmf_code_fd = workdir.addCopyFile(ovmf.path("ovmf-code-aarch64.fd"), "ovmf-code-aarch64.fd");
                const run_truncate = b.addSystemCommand(&.{ "truncate", "-c", "-s", "64M" });
                break :ovmf_code_fd run_truncate.addModifyPathArg(copied_ovmf_code_fd);
            },
            else => unreachable,
        },
    );

    run_qemu_uefi.addArg("-cdrom");
    run_qemu_uefi.addFileArg(blossom_iso);

    b.step("run-uefi", "Run BlossomOS with UEFI on qemu")
        .dependOn(&run_qemu_uefi.step);
}
