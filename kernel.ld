ENTRY(_start)

PHDRS {
  limine_requests PT_LOAD;
  text PT_LOAD;
  rodata PT_LOAD;
  data PT_LOAD;
}

SECTIONS {
    . = 0xFFFFFFFF80000000;

    .limine_requests : {
        KEEP(*(.limine_requests_start))
        KEEP(*(.limine_requests))
        KEEP(*(.limine_requests_end))
    } : limine_requests

    .text : ALIGN(CONSTANT(MAXPAGESIZE)) {
        *(.text .text.*)
    } : text

    .rodata : ALIGN(CONSTANT(MAXPAGESIZE)) {
        *(.rodata .rodata.*)
    } : rodata

    .data : ALIGN(CONSTANT(MAXPAGESIZE)) {
        *(.data .data.*)
    } : data

    /* bss needs to be the last thing mapped to data phdr */
    .bss : ALIGN(CONSTANT(MAXPAGESIZE)) {
        *(.bss .bss.*)
        *(COMMON)
    } : data

    /* Discard .note.* and .eh_frame* since they may cause issues on some hosts. */
    /DISCARD/ : {
        *(.eh_frame*)
        *(.note .note.*)
    }
}
