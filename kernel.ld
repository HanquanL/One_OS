/* kernel.ld — the linker script.
 *
 * This is the grown-up cousin of your two-pass linker assignment: it decides
 * WHERE each section lands in memory and WHICH instruction is the entry point.
 * QEMU's `virt` machine begins executing at physical address 0x80000000, so
 * everything must be laid out starting there, with our _start first. */

OUTPUT_ARCH("riscv")
ENTRY(_start)              /* the symbol the CPU jumps to first */

SECTIONS
{
    . = 0x80000000;       /* set the location counter to where RAM/execution begins */

    .text : {
        *(.text.boot)     /* boot.S goes FIRST so _start sits exactly at 0x80000000 */
        *(.text .text.*)  /* then all other code */
    }

    .rodata : {
        *(.rodata .rodata.*)   /* read-only data: our string literals live here */
    }

    .data : {
        *(.data .data.*)       /* initialised globals */
    }

    .bss : {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;         /* the stack from boot.S lives in here */
    }

    /* Throw away metadata sections that would otherwise get auto-placed
     * ahead of .text and steal address 0x80000000 from _start. */
    /DISCARD/ : {
        *(.note .note.*)
        *(.comment)
        *(.eh_frame .eh_frame_hdr)
        *(.riscv.attributes)
    }
}
