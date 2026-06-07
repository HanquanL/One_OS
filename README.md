# RISC-V OS (working title)

A hobby operating system written from scratch in C++, targeting 64-bit RISC-V
under QEMU. Two goals drive the design:

1. **Understand an OS top to bottom** — every layer is hand-built and readable,
   with no magic underneath.
2. **Stay extensible** — clean seams at each layer boundary so features can be
   added later without rewrites.

Reference companion: MIT's **xv6-riscv** (read it as the map; this is the
territory we build ourselves).

---

## Status

- [x] **Milestone 0 — Boot to screen.** Boots in QEMU in M-mode, prints a banner
      by writing directly to the UART. No bootloader, no firmware, no libc.
- [ ] Milestone 1 and onward — see roadmap below.

---

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

---

## Current files

| File         | Role |
|--------------|------|
| `boot.S`     | First instructions: park extra harts, set the stack, call `kmain` |
| `kernel.cpp` | C++ entry `kmain`; writes bytes to the memory-mapped UART |
| `kernel.ld`  | Linker *script* (config for `ld`): places everything at 0x80000000, `_start` first |
| `Makefile`   | Build rules + `make run` |

---

## Roadmap

Each milestone adds one layer and maps back to a classic OS concept. The arc
deliberately climbs from the hardware up.

| #  | Milestone | What it adds | Concept it grounds |
|----|-----------|--------------|--------------------|
| 0  | Boot to screen ✅ | M-mode entry, direct UART output | The absolute bottom: a store to a hardware register |
| 1  | Traps & interrupts | Trap vector (`stvec`/`mtvec`), a trap handler; move kernel to S-mode under OpenSBI | Interrupt handling (RISC-V's answer to the x86 IDT) |
| 2  | Timer & input | Timer interrupt for preemption; read UART input | Preemptive multitasking groundwork; device input |
| 3  | Physical memory | Frame allocator over usable RAM | Physical memory management |
| 4  | Virtual memory | Sv39 page tables, `satp`, per-address-space maps | Memory protection — "property rights & zoning" |
| 5  | Heap | A kernel allocator (`kmalloc`) | Dynamic allocation; re-enables C++ `new`/`delete` |
| 6  | Processes & scheduler | Context switch + run queue (mechanism) with a pluggable policy | Scheduling algorithms — swap RR / priority / MLFQ freely |
| 7  | User mode & syscalls | Drop to U-mode; `ecall` trap into a syscall dispatch table | The citizen↔sovereign boundary; protected service requests |
| 8  | Filesystem & program loading | VFS layer + a concrete FS; load and run user ELF binaries | Persistence; **ELF loading = the run-time cousin of the linker assignment** |
| 9+ | Beyond | Device-model drivers, IPC, multi-hart (SMP), optional microkernel refactor | Real-system breadth |

---

## Target structure (the seams we design for)

Built incrementally, but the boundaries are planned from the start so extension
is cheap:

```
kernel/
  arch/riscv/   <- HAL: context switch, trap entry, paging primitives, timer, console
  arch/<later>/ <- the seam itself; a second architecture slots in here
  mm/           <- physical frame allocator, paging, heap
  sched/        <- mechanism (run queue, switch) kept SEPARATE from policy (which task next)
  syscall/      <- a dispatch TABLE, not a giant switch — add a syscall = add an entry
  fs/vfs/       <- virtual filesystem layer; concrete filesystems register under it
  drivers/      <- a tiny device model; drivers register against it
  lib/          <- freestanding C++ utilities (our own minimal containers)
```

**Guiding principle:** separate *mechanism* from *policy*, and put a thin
interface at every layer boundary. Cheap up front, sharpens understanding, and
is exactly how real kernels buy their flexibility. (It also keeps the door open
to a monolith → microkernel refactor later — clean boundaries *are* the whole
investment.)

**Privilege through-line:** RISC-V has three tiers — M (machine) → S
(supervisor) → U (user). We start as the M-mode sovereign with no separation;
the roadmap gradually erects the wall between kernel (S) and processes (U).

---

## Build-flag gotchas (learned the hard way)

- `-fno-pic -fno-pie -no-pie`: Ubuntu's GCC defaults to position-independent
  code, which builds a GOT and addresses everything indirectly. A freestanding
  kernel wants plain absolute addressing.
- `--build-id=none` + the `/DISCARD/` block in `kernel.ld`: stop stray
  `.note`/`.eh_frame` metadata sections from being placed ahead of `.text` and
  stealing address 0x80000000 from `_start` (which boots to silence).
