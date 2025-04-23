_default:
    @just --list

alias r := run

[macos]
run target='install' *FLAGS: (build target) vars-file
	qemu-system-aarch64 -accel hvf \
		-m 2048 -cpu cortex-a72 -M virt \
		-drive file=/opt/homebrew/share/qemu/edk2-aarch64-code.fd,if=pflash,format=raw,readonly=on \
		-drive file=vars.fd,if=pflash,format=raw \
		-drive format=raw,file=fat:rw:zig-out \
		-nographic {{FLAGS}}

alias b := build
build target='install': update-zig
	zig build {{target}}

vars-file:
	-rm vars.fd
	touch vars.fd
	truncate -s 64M vars.fd

[working-directory('zig')]
update-zig:
    git pull --force
