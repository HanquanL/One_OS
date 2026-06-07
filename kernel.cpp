// kernel.cpp — One OS entry point.
//
// There is no operating system beneath us: no std::cout, no printf, no libc.
// To put a character on screen we write DIRECTLY to the memory-mapped UART —
// the address where QEMU's `virt` board exposes the serial port. This is the
// literal bottom of "top to bottom".
 
#include <cstdint>
 
namespace {
 
// 16550-style UART, memory-mapped on the QEMU `virt` board.
volatile uint8_t* const UART0 = reinterpret_cast<uint8_t*>(0x1000'0000);
 
constexpr unsigned THR = 0;            // Transmit Holding Register: write to send
constexpr unsigned LSR = 5;            // Line Status Register: ready-to-send flag
constexpr uint8_t  LSR_TX_IDLE = 0x20; // set when THR can accept another byte
 
// Send one raw byte, once the transmitter is free.
void uart_write(uint8_t b) {
    while ((UART0[LSR] & LSR_TX_IDLE) == 0) { /* wait */ }
    UART0[THR] = b;
}
 
// Send a character, cooking '\n' into CR+LF the way serial consoles expect.
void uart_putc(char c) {
    if (c == '\n') uart_write('\r');
    uart_write(static_cast<uint8_t>(c));
}
 
void uart_puts(const char* s) {
    for (; *s != '\0'; ++s) uart_putc(*s);
}
 
// The boot banner. A raw string literal R"(...)" lets the ASCII art keep its
// backslashes without any escaping.
const char* const BANNER = R"(
  ___                ___  ____
 / _ \ _ __   ___   / _ \/ ___|
| | | | '_ \ / _ \ | | | \___ \
| |_| | | | |  __/ | |_| |___) |
 \___/|_| |_|\___|  \___/|____/
 
     a from-scratch C++ kernel on RISC-V (rv64)
)";
 
} // namespace
 
extern "C" void kmain() {
    uart_puts(BANNER);
    uart_puts("[boot] core 0, machine mode (M)\n");
    uart_puts("[boot] kmain() reached -- entering idle loop\n");
 
    for (;;) {
        asm volatile("wfi");
    }
}
 