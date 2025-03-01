choose-recipe:
	@just --choose

alias b := build
build +FLAGS='':
	mkdir -p esp/efi/boot
	cargo build -p boot --bin bootaa64 \
		--target aarch64-unknown-uefi \
		-Zbuild-std=alloc,core,compiler_builtins \
		-Zbuild-std-features=compiler-builtins-mem \
		-Zunstable-options \
		--artifact-dir=esp/efi/boot \
		{{FLAGS}}

_run_qemu +FLAGS='':
	-rm vars.fd
	touch vars.fd
	truncate -s 64M vars.fd
	qemu-system-aarch64 -accel hvf \
		-m 2048 -cpu cortex-a72 -M virt \
		-drive file=/opt/homebrew/share/qemu/edk2-aarch64-code.fd,if=pflash,format=raw,readonly=on \
		-drive file=vars.fd,if=pflash,format=raw \
		-drive format=raw,file=fat:rw:esp \
		-monitor stdio

alias r := run
run: build _run_qemu

alias t := test
test: #(build '--tests') _run_qemu
	cargo test --bin bootaa64 \
		--no-run \
		--target aarch64-unknown-uefi \
		-Zbuild-std=alloc,core,compiler_builtins \
		-Zbuild-std-features=compiler-builtins-mem
