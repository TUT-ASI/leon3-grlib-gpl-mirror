#ifndef _RISCV_UART_H
#define _RISCV_UART_H

#ifndef NO_UART_WAIT
#define NO_UART_WAIT 0
#endif

#include <stdint.h>

#define UART_BASE 0x80000100

extern volatile uint32_t* uart;

#define UART_REG_TXFIFO		0
#define UART_REG_RXFIFO		1
#define UART_REG_TXCTRL		2
#define UART_REG_RXCTRL		3
#define UART_REG_DIV		4

#define UART_TXEN		 0x1
#define UART_RXEN		 0x1

void uart_init();
void uart_putchar(uint8_t ch);
int uart_getchar();
void query_uart(uintptr_t dtb);

#endif
