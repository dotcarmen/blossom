qemu-system-aarch64 \
  -accel hvf \
  -m 2048 \
  -cpu cortex-a72 \
  -M virt \
  -drive file=/opt/homebrew/share/qemu/edk2-aarch64-code.fd,if=pflash,format=raw,readonly=on \
  -drive file=vars1.fd,if=pflash,format=raw \
  -drive format=raw,file=fat:rw:esp \
  -monitor stdio
