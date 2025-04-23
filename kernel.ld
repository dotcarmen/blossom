ENTRY(_start)

SECTIONS {
	. = 2M;

	.text.start : ALIGN(4K) {
		*(.text.start)
	}

	.kernel.environment : ALIGN(4K) {
		kernel_logger = .;
		KEEP(
			*(.kernel.logger)
		)
	}

	.text : ALIGN(4K) {
		*(.text)
	}

	.rodata : ALIGN(4K) {
		*(.rodata)
	}

	.data : ALIGN(4K) {
		*(.data)
	}

	.bss : ALIGN(4K) {
		*(COMMON)
		*(.bss)
	}
}
