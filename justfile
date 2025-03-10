alias r := run
run target='install': (build target) vars-file
	# TODO: won't work on non-macos
	qemu-system-aarch64 -accel hvf \
		-m 2048 -cpu cortex-a72 -M virt \
		-drive file=/opt/homebrew/share/qemu/edk2-aarch64-code.fd,if=pflash,format=raw,readonly=on \
		-drive file=vars.fd,if=pflash,format=raw \
		-drive format=raw,file=fat:rw:zig-out \
		-nographic

alias b := build
build target='install':
	zig build {{target}}

vars-file:
	-rm vars.fd
	touch vars.fd
	truncate -s 64M vars.fd
