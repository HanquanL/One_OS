# CLAUDE.md — Working agreement for One OS

Standing context for Claude Code. Read this, then read `README.md` and the
source files **before doing anything**.

## What this is

One OS: an operating system built from scratch in C++, targeting 64-bit RISC-V
under QEMU. **North star: boot and run on a real physical computer, not just
QEMU.** Full picture — goals, milestone roadmap, architecture seams, course-lab
tie-ins — lives in `README.md`. Don't duplicate it here; read it.

## Read first, every session

- `README.md` — goals, the milestone roadmap, the `arch/` seams, the build gotchas.
- `boot.S`, `kernel.cpp`, `kernel.ld`, `Makefile` — the current kernel. It's
  small; read all of it.

## Current status

- **Milestone 0** (boot to screen, M-mode, direct UART) is **DONE** and verified.
- **Next: Milestone 1** — traps & interrupts; move the kernel to S-mode under OpenSBI.
- Work milestone by milestone, in roadmap order. Do **not** jump ahead or scaffold
  future milestones before the current one boots.

## Build & test

- `make` builds `kernel.elf`; `make run` boots it under QEMU (quit: `Ctrl-A` then `X`).
- Toolchain: `g++-riscv64-linux-gnu` + `qemu-system-misc` (see README prerequisites).
- **ALWAYS boot under QEMU and confirm the expected output before claiming a
  change works.** For a kernel, "it compiles" is not "it works," and a silent
  boot is a real bug, not success.

## Hard-won build settings — do NOT regress these

- `-fno-pic -fno-pie -no-pie`: the kernel needs absolute addressing, not a GOT.
- `--build-id=none` + the `/DISCARD/` block in `kernel.ld`: keep stray
  `.note`/`.eh_frame` sections from stealing address `0x80000000` from `_start`.
  (Symptom if this regresses: the kernel boots to total silence.)
- `_start` MUST sit at `0x80000000`. Verify with `readelf -h kernel.elf` after any
  change to the linker script or section layout.
- Freestanding C++: `-ffreestanding -fno-exceptions -fno-rtti -nostdlib`. No STL,
  no exceptions, no RTTI, and no `new`/`delete` until the heap exists (Milestone 5).

## Architecture conventions (this is the whole point of the design)

- **Separate mechanism from policy.** Keep a thin interface at every layer boundary.
- **All architecture-specific code lives behind the `arch/riscv/` seam (the HAL).**
  Generic layers (`mm/`, `sched/`, `fs/`, ...) must contain no RISC-V-specific code.
  This seam is what makes the eventual real-hardware / x86 port possible — protect it.
- Schedulers and pagers are **pluggable policy classes behind a virtual interface**.
  (This is also how the course-lab algorithms drop in later — see README roadmap.)

## Coding style

- Favor RAII, strong typing, and `constexpr`. Avoid anything that needs a runtime
  we haven't built yet.
- Each subsystem prints one `[boot] ...` line as it comes up, to build a readable
  boot trace.
- Comment the *why*, especially for hardware addresses and magic constants.

## Don't

- Don't claim something works without booting it.
- Don't jump milestones or add speculative abstraction before it's needed.
- Don't regress the build flags above.
- Don't copy xv6 wholesale — read it as a reference, then build our own.
