# Milestone 0 — Boot-to-screen: C++ on bare-metal RISC-V

A minimal kernel that QEMU boots in machine mode and which prints a banner by
talking directly to the UART. No bootloader, no firmware, no libc.

## Prerequisites (Ubuntu/Debian)

```
sudo apt-get install -y g++-riscv64-linux-gnu qemu-system-misc
```

## Build & run

```
make        # produces kernel.elf
make run    # boots it in QEMU; quit with Ctrl-A then X
```

Expected output:

```
================================
 Hello from kmain()
 C++ running on bare-metal RISC-V
================================
```

## Files

| File        | Role |
|-------------|------|
| `boot.S`    | First instructions: park extra cores, set the stack, call `kmain` |
| `kernel.cpp`| C++ entry `kmain`; writes bytes to the memory-mapped UART |
| `kernel.ld` | Linker script: places everything at 0x80000000, `_start` first |
| `Makefile`  | Build rules + `make run` |

## Boot flow

reset -> CPU jumps to 0x80000000 in M-mode -> `_start` (boot.S) -> set sp ->
`kmain()` -> store bytes into UART register at 0x10000000 -> idle in `wfi`.

## Two non-obvious build flags (learned the hard way)

- `-fno-pic -fno-pie -no-pie`: Ubuntu's GCC defaults to position-independent
  code, which builds a GOT and uses GOT-relative addressing. A freestanding
  kernel wants plain absolute addressing.
- `--build-id=none` + the `/DISCARD/` block in the linker script: stop stray
  `.note`/`.eh_frame` metadata sections from being placed ahead of `.text` and
  stealing address 0x80000000 from `_start`.
