# One OS

A hobby operating system written from scratch in C++, targeting 64-bit RISC-V
under QEMU. Two goals drive the design:

1. **Understand an OS top to bottom** — every layer is hand-built and readable,
   with no magic underneath.
2. **Stay extensible** — clean seams at each layer boundary so features can be
   added later without rewrites.

**North star:** the end goal is an OS that boots and runs on a *real physical
computer*, not just under QEMU. QEMU is the development environment; real
hardware is the finish line.

The roadmap is also aligned to cover the four programming labs
(Linker, Scheduler, VMM, I/O Scheduling) as *real* subsystems rather than
simulators — see the "Lab" column below.

Reference companion: MIT's **xv6-riscv** (read it as the map; this is the
territory we build ourselves).

---

## Status

- [x] **Milestone 0 — Boot to screen.** Boots in QEMU in M-mode, prints a banner
      by writing directly to the UART. No bootloader, no firmware, no libc.
      (Already exercises Lab 1's consumer side: the `ld` linker + `kernel.ld`.)
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
  ___                ___  ____
 / _ \ _ __   ___   / _ \/ ___|
| | | | '_ \ / _ \ | | | \___ \
| |_| | | | |  __/ | |_| |___) |
 \___/|_| |_|\___|  \___/|____/

     a from-scratch C++ kernel on RISC-V (rv64)
[boot] core 0, machine mode (M)
[boot] kmain() reached -- entering idle loop
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

Each milestone adds one layer, maps back to a classic OS concept, and (where
applicable) realizes one of the course labs as a real subsystem.

| #   | Milestone | What it adds | Concept it grounds | Lab |
|-----|-----------|--------------|--------------------|-----|
| 0   | Boot to screen ✅ | M-mode entry, direct UART output | The absolute bottom: a store to a hardware register | 1 (uses `ld` + `kernel.ld`) |
| 1   | Traps & interrupts | Trap vector (`stvec`/`mtvec`), a handler; move kernel to S-mode under OpenSBI | Interrupt handling (RISC-V's answer to the x86 IDT) | — |
| 2   | Timer & input | Timer interrupt for preemption; read UART input | Preemptive multitasking groundwork; device input | — |
| 3   | Physical memory | Frame allocator over usable RAM | Physical memory management | — |
| 4   | Virtual memory | Sv39 page tables, `satp`, per-address-space maps | Memory protection; **PTE mechanics** (R/M bits = RISC-V Accessed/Dirty) | 3 (page tables) |
| 5   | Heap | A kernel allocator (`kmalloc`) | Dynamic allocation; re-enables C++ `new`/`delete` | — |
| 6   | Processes & scheduler | Context switch + run queue (mechanism) with a pluggable policy | Scheduling algorithms — RR / priority / MLFQ | **2** (port the policy classes) |
| 7   | User mode & syscalls | Drop to U-mode; `ecall` trap into a syscall dispatch table | The citizen↔sovereign boundary | — |
| 8   | Block device & I/O scheduler | virtio-blk driver + a request queue with pluggable policy | The block layer | **4** (LOOK/CLOOK/FLOOK) |
| 9   | Filesystem & program loading | VFS layer + a concrete FS; load and run user ELF binaries | Persistence; **ELF loading = load-time relocation** | **1** (loader) |
| 10  | Demand paging & replacement | Page-fault-driven swap; victim selection | Paging under memory pressure | **3** (FIFO/Clock/NRU/Aging/WS) |
| 11  | Beyond | IPC, multi-hart (SMP), optional microkernel refactor | Real-system breadth | — |
| 12  | Real hardware: boot & install | Real bootloader + firmware handoff; bootable disk/USB/SD image; retire the `-kernel` shortcut | **The finish line** — runs on a physical machine (the project's final goal) | — |

**On the labs vs. the real thing:** the labs are deterministic simulators; One OS
is interrupt- and trap-driven. They're complementary — the labs give us reference
algorithms and deterministic test cases; One OS gives those algorithms real
machinery to plug into. Labs 2 and 3 already mandate the exact mechanism-vs-policy
design used in `sched/` and the device model below, so their subclasses port in
with little change. (Lab 4's seek algorithms matter least on virtio hardware —
there it's mainly the block-layer architecture being exercised.)

**On reaching real hardware (Milestone 12):** the `-bios none -kernel` boot we
use today is a QEMU development shortcut that skips real boot machinery. Getting
to a physical machine means a proper bootloader, the firmware handoff, and a
bootable image — plus a target-hardware choice: a real RISC-V board (keeps
everything built so far) or an x86_64 port (reuses the generic layers, rewrites
the `arch/` floor). The choice can wait; the early milestones are identical
either way.

---

## Target structure (the seams we design for)

Built incrementally, but the boundaries are planned from the start so extension
is cheap:

```
kernel/
  arch/riscv/   <- HAL: context switch, trap entry, paging primitives, timer, console
  arch/<later>/ <- the seam itself; a second architecture slots in here
  mm/           <- physical frame allocator, paging, heap, page replacement (Lab 3)
  sched/        <- mechanism (run queue, switch) kept SEPARATE from policy (Lab 2)
  syscall/      <- a dispatch TABLE, not a giant switch — add a syscall = add an entry
  fs/vfs/       <- virtual filesystem layer; concrete filesystems register under it
  block/        <- block layer + pluggable I/O scheduler (Lab 4) over the device model
  drivers/      <- a tiny device model; drivers (virtio-blk, UART) register against it
  loader/       <- ELF program loader (Lab 1, load-time relocation)
  lib/          <- freestanding C++ utilities (our own minimal containers)
```

**Guiding principle:** separate *mechanism* from *policy*, and put a thin
interface at every layer boundary. Cheap up front, sharpens understanding, and
is exactly how real kernels buy their flexibility — and exactly what the course
labs force you to do. (It also keeps the door open to a monolith → microkernel
refactor later — clean boundaries *are* the whole investment.)

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

