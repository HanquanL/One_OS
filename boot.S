# boot.S — the very first code that runs.
# QEMU's `virt` machine (with -bios none) drops us here at physical
# address 0x80000000, running in M-mode (machine mode: the top privilege
# tier). On entry: a0 = this core's hart id, a1 = pointer to the device tree.

.section .text.boot      # a named section so the linker can place it FIRST
.global _start
_start:
    # On a multi-core machine every CPU ("hart") starts executing here at
    # once. We only want one of them running our kernel; park the rest.
    csrr  t0, mhartid     # read this hart's hardware id
    bnez  t0, park        # if it isn't hart 0, send it to the parking loop

    # Set up a stack. C++ needs one before we can call any function.
    # The stack grows DOWNWARD, so we point sp at the TOP of the region.
    la    sp, stack_top

    call  kmain           # jump into C++; should never return

park:
    wfi                   # "wait for interrupt": idle the core, low power
    j     park            # if something wakes us, just idle again

# Reserve 16 KiB of zero-initialised memory for the stack (lives in .bss).
.section .bss
.align 16
stack_bottom:
    .skip 4096 * 4
stack_top:
