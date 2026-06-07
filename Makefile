# Makefile — `make` builds kernel.elf, `make run` boots it in QEMU.

CXX     := riscv64-linux-gnu-g++
QEMU    := qemu-system-riscv64

# Compiler flags, each earning its place:
#   -march/-mabi   target the 64-bit RISC-V "GC" instruction set
#   -mcmodel=medany  let code address high addresses like 0x80000000
#   -ffreestanding   "there is no OS / no libc beneath you"
#   -fno-exceptions -fno-rtti   C++ features that need a runtime we don't have yet
#   -nostdlib        don't link any standard library or startup files
CXXFLAGS := -march=rv64gc -mabi=lp64d -mcmodel=medany \
            -ffreestanding -fno-exceptions -fno-rtti -nostdlib \
            -fno-pic -fno-pie -fno-asynchronous-unwind-tables \
            -Wall -Wextra -O2 -g

LDFLAGS  := -T kernel.ld -nostdlib -static -no-pie -Wl,--build-id=none

OBJS := boot.o kernel.o

all: kernel.elf

boot.o: boot.S
	$(CXX) $(CXXFLAGS) -c boot.S -o boot.o

kernel.o: kernel.cpp
	$(CXX) $(CXXFLAGS) -c kernel.cpp -o kernel.o

kernel.elf: $(OBJS) kernel.ld
	$(CXX) $(CXXFLAGS) $(LDFLAGS) $(OBJS) -o kernel.elf

# Boot it. -bios none means "no firmware, jump straight to our code in M-mode".
# -nographic routes the UART to this terminal. Quit QEMU with Ctrl-A then X.
run: kernel.elf
	$(QEMU) -machine virt -bios none -kernel kernel.elf -nographic

clean:
	rm -f $(OBJS) kernel.elf

.PHONY: all run clean
