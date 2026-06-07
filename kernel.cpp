// kernel.cpp — your first C++ that runs on the bare metal.
//
// There is no operating system beneath us, so there is no std::cout, no
// printf, no libc. To get a character onto the screen we talk DIRECTLY to
// the serial port (UART) by writing to the magic memory address where QEMU
// has wired it up. This is the literal bottom of "top to bottom".

#include <cstdint>

namespace {

// On QEMU's `virt` board the 16550-style UART is memory-mapped at this
// address. Reading/writing these bytes is reading/writing hardware registers.
volatile uint8_t* const UART0 = reinterpret_cast<uint8_t*>(0x1000'0000);

// Register offsets within the UART (in bytes).
constexpr unsigned THR = 0;          // Transmit Holding Register: write a byte to send it
constexpr unsigned LSR = 5;          // Line Status Register: tells us when we can send
constexpr uint8_t  LSR_TX_IDLE = 0x20; // bit set when THR is empty and ready

void uart_putc(char c) {
    // Spin until the transmitter is ready to accept another byte.
    while ((UART0[LSR] & LSR_TX_IDLE) == 0) { /* wait */ }
    UART0[THR] = static_cast<uint8_t>(c);
}

void uart_puts(const char* s) {
    for (; *s != '\0'; ++s) {
        uart_putc(*s);
    }
}

} // namespace

// extern "C" so the name isn't mangled — boot.S calls plain `kmain`.
extern "C" void kmain() {
    uart_puts("\n");
    uart_puts("================================\n");
    uart_puts(" Hello from kmain()             \n");
    uart_puts(" C++ running on bare-metal RISC-V\n");
    uart_puts("================================\n");

    // Nothing to return to. Idle forever.
    for (;;) {
        asm volatile("wfi");
    }
}
