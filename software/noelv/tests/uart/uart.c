#include <string.h>
#include "uart.h"

#include <stdint.h>

/*
 *  The following defines the bits in the APBUART Status Registers.
 */
#define UART_STATUS_DR   0x00000001	/* Data Ready */
#define UART_STATUS_TSE  0x00000002	/* TX Send Register Empty */
#define UART_STATUS_THE  0x00000004	/* TX Hold Register Empty */
#define UART_STATUS_BR   0x00000008	/* Break Error */
#define UART_STATUS_OE   0x00000010	/* RX Overrun Error */
#define UART_STATUS_PE   0x00000020	/* RX Parity Error */
#define UART_STATUS_FE   0x00000040	/* RX Framing Error */
#define UART_STATUS_ERR  0x00000078	/* Error Mask */

/*
 *  The following defines the bits in the APBUART Ctrl Registers.
 */
#define UART_CTRL_RE     0x00000001	/* Receiver enable */
#define UART_CTRL_TE     0x00000002	/* Transmitter enable */
#define UART_CTRL_RI     0x00000004	/* Receiver interrupt enable */
#define UART_CTRL_TI     0x00000008	/* Transmitter irq */
#define UART_CTRL_PS     0x00000010	/* Parity select */
#define UART_CTRL_PE     0x00000020	/* Parity enable */
#define UART_CTRL_FL     0x00000040	/* Flow control enable */
#define UART_CTRL_LB     0x00000080	/* Loopback enable */

#define UART_TX_READY(status)	(((status) & UART_STATUS_THE) != 0)
#define UART_RX_DATA(status)	(((status) & UART_STATUS_DR) != 0)

#define UART_MAX_TIMEOUT 1000 * 1000 // 1/100 s

volatile uint32_t* uart;

typedef volatile struct grlib_apbuart_regs_map {
  uint32_t data;
  uint32_t status;
  uint32_t ctrl;
  uint32_t scaler;
} uart_regs;

/* void uart_putchar(uint8_t ch) */
/* { */
/* #ifdef __riscv_atomic */
/*     int32_t r; */
/*     do { */
/*       __asm__ __volatile__ ( */
/*         "amoor.w %0, %2, %1\n" */
/*         : "=r" (r), "+A" (uart[UART_REG_TXFIFO]) */
/*         : "r" (ch)); */
/*     } while (r < 0); */
/* #else */
/*     volatile uint32_t *tx = uart + UART_REG_TXFIFO; */
/*     while ((int32_t)(*tx) < 0); */
/*     *tx = ch; */
/* #endif */
/* } */

void uart_putchar(uint8_t ch)
{	
  volatile uint32_t status;

  if (NO_UART_WAIT) {
    do {
      status = ((uart_regs *) UART_BASE)->status;	
    } while (!UART_TX_READY(status));
  }

  ((uart_regs *) UART_BASE)->data = ch;
}

/* int uart_getchar() */
/* { */
/*   int32_t ch = uart[UART_REG_RXFIFO]; */
/*   if (ch < 0) return -1; */
/*   return ch; */
/* } */

int uart_getchar()
{
  volatile uint32_t status;
  do {
    status = ((uart_regs *) UART_BASE)->status;
  } while (!UART_RX_DATA(status));
	
  char ch = ((uart_regs *) UART_BASE)->data;
  if (ch < 0) return -1;
  return ch;
}

struct uart_scan
{
  int compat;
  uint64_t reg;
};

#ifdef FDT_H

static void uart_open(const struct fdt_scan_node *node, void *extra)
{
  struct uart_scan *scan = (struct uart_scan *)extra;
  memset(scan, 0, sizeof(*scan));
}

static void uart_prop(const struct fdt_scan_prop *prop, void *extra)
{
  struct uart_scan *scan = (struct uart_scan *)extra;
  if (!strcmp(prop->name, "compatible") && !strcmp((const char*)prop->value, "grlib,apbuart")) {
    scan->compat = 1;
  } else if (!strcmp(prop->name, "reg")) {
    fdt_get_address(prop->node->parent, prop->value, &scan->reg);
  }
}

static void uart_done(const struct fdt_scan_node *node, void *extra)
{
  struct uart_scan *scan = (struct uart_scan *)extra;
  if (!scan->compat || !scan->reg || uart) return;

  // Enable Rx/Tx channels
  //uart = (void*)(uintptr_t)scan->reg;
  //uart[UART_REG_TXCTRL] = UART_TXEN;
  //uart[UART_REG_RXCTRL] = UART_RXEN;

  uart = (void *) UART_BASE;
  ((uart_regs *) UART_BASE)->ctrl = UART_CTRL_RE | UART_CTRL_TE;
  ((uart_regs *) UART_BASE)->data = 0;

}

void query_uart(uintptr_t fdt)
{
  struct fdt_cb cb;
  struct uart_scan scan;

  memset(&cb, 0, sizeof(cb));
  cb.open = uart_open;
  cb.prop = uart_prop;
  cb.done = uart_done;
  cb.extra = &scan;

  fdt_scan(fdt, &cb);
}

#endif

void uart_init()
{
  uart = (void *) UART_BASE; // TODO Properly initialize uart
  
  // Initialize Control Register
  if (NO_UART_WAIT) {  // workaround to not clear ctrl register in hardware (needed in simulation due to X)
    ((uart_regs *) UART_BASE)->ctrl = (((uart_regs *) UART_BASE)->ctrl) | UART_CTRL_RE | UART_CTRL_TE;
  } else {
    ((uart_regs *) UART_BASE)->ctrl = UART_CTRL_RE | UART_CTRL_TE;
  };

  // Initialize Holding Register
  ((uart_regs *) UART_BASE)->data = 0;

  //((uart_regs *) UART_BASE)->ctrl = UART_CTRL_RE | UART_CTRL_TE;
}

