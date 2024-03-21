#include <stdio.h>
#include "report.h"

#define SET_DLAB    0x80
#define LOOP_BACK   0x10
#define ENABLE_FIFO 0x01
#define ENABLE_TX   0x01
#define ENABLE_RX   0x02
#define THRE_INT_EN 0x02
#define RDA_INT_EN  0x01

static inline int loadmem(addr_t addr) {
  int tmp;
#ifdef NOELV_SYSTEST
  asm volatile ("lw %0, 0(%1)"
#else
  asm volatile (" lda [%1]1, %0 "
#endif
    : "=r"(tmp)
    : "r"(addr)
  );
  return tmp;
}

struct uart_regs {
   // UART 16550 Registers
   volatile uint32_t data;     // TX data (Write)/ RX data (Read)/ Divisor Latch[LS] (DLAB=1)                  0x00
   volatile uint32_t ier;      // Interrupt Enable Register/ Divisor Latch[MS] (DLAB=1)                        0x04
   volatile uint32_t iir_fcr;  // FIFO Control Register (Write)/ Interrupt Identification Register (Read)      0x08
   volatile uint32_t lcr;      // Line Control Register                                                        0x0c
   volatile uint32_t mcr;      // MODEM Control Register                                                       0x10                                                 
   volatile uint32_t lsr;      // Line Status Register                                                         0x14
   volatile uint32_t msr;      // MODEM Status Register                                                        0x18
   volatile uint32_t scr;      // Scratch Register                                                             0x1c
   // Custom Registers                                                                                         
   volatile uint32_t ccr;      // Custom Control Register                                                      0x20
   volatile uint32_t rfc;      // Receiver FIFO Count                                                          0x24
   volatile uint32_t tfc;      // Transciever FIFO Count                                                       0x28
   volatile uint32_t dmr;      // Debug Mode Register                                                          0x2c
   volatile uint32_t dbr;      // Debug Register                                                               0x30
};


#define FIFO_RX_CNT     ((loadmem((addr_t)&uart->rfc)))
#define FIFO_TX_CNT     ((loadmem((addr_t)&uart->tfc)))
#define FIFO_TX_EMPTY   ((loadmem((addr_t)&uart->lsr) >> 5) & 0x1)
#define TX_EMPTY        ((loadmem((addr_t)&uart->lsr) >> 6) & 0x1)
#define DATA_READY      (loadmem((addr_t)&uart->lsr) & 1)


static char test[] = "40ti94a+0ygiyu05yhap5yi4h+a+iiyxhi4k59j0q905jkoyphoptjrhia4iy0+4";
static int testsize = sizeof test / sizeof test[0];


int apbuart16550_test(addr_t addr) {
  volatile struct uart_regs *uart = (struct uart_regs *) addr;
  volatile int temp;
  int i;
  int fifosize;
  if (report_device(0x010D5000)) return 17;
  // Set scaler to low value to speed up simulations
  uart->lcr  = SET_DLAB; // Set DLAB to modify Scaler
  uart->data = 1;        // Set Scaler to 1
  uart->lcr  = 0;        // Clear DLAB 
  // Enable FIFO mode and LOOP BACK mode
  uart->mcr     = LOOP_BACK;          // Set Loop Back Mode
  uart->iir_fcr = ENABLE_FIFO | 0x80; // 0x0c sets to 8 FIFO trigger level
  // Check that FIFO mode is implemented
  temp = loadmem((addr_t)&uart->iir_fcr);
  if (temp & 0b11000000) 
    fifosize = 16;
  else
    fifosize = 1;
  // Enable the Received Data Available and the Transmitter 
  // Holding Register Empty interrupts.
  uart->ier = THRE_INT_EN | RDA_INT_EN; 



  /*
   * TRANSMITTER TEST
   */
  uart->ccr = 0; // Disable TX and RX
  if (FIFO_TX_EMPTY == 0 || TX_EMPTY == 0) {
    fail(1); // THRE bit or TEMT bit incorrect
    return 1;
  }
  uart->data = (addr_t) test[0];
  if (FIFO_TX_EMPTY == 1 || TX_EMPTY == 1) {
    fail(2); // THRE bit or TEMT bit incorrect
    return 2;
  }
  if (fifosize > 1) {
    for (i = 1; i < fifosize; i++) {
      uart->data = (addr_t) test[i % testsize];
    }
    if (FIFO_TX_CNT != fifosize) {
      fail(3); // TCNT error
      return 3;
    }
  }

  /*
   * RECEIVER TEST (WITH LOOPBACK)
   */
  if (DATA_READY != 0) {
    fail(4); // DR bit incorrect
    return 4;
  }
  uart->ccr = ENABLE_RX | ENABLE_TX;
  if (fifosize == 1) {
    while (DATA_READY == 0);
  } else {
    while (FIFO_RX_CNT != fifosize); // Wait until receiver FIFO full.
  }
  if (DATA_READY == 0) {
    fail(5); // DR bit incorrect
    return 5;
  }
  if (fifosize > 1) {
    if ((FIFO_RX_CNT) != fifosize) {
      fail(6); // RCNT error
      return 6;
    }
    // Check for Trigger level Reached interrupt
    temp = loadmem((addr_t)&uart->iir_fcr);
    if (temp != 0b11000100) {
      fail(temp);
      fail(7);
      return(7);
    }
  }
  for (i = 0; i < fifosize; i++) {
    temp = loadmem((addr_t)&uart->data);
    if (temp != test[i % testsize]) {
      fail(8); // data error
      return 8;
    }
    if (FIFO_RX_CNT == 7) {
      // When the number of data is less than
      // the Trigger Level Reached interrupt is reset
      // and it is possible to check the Transmitter
      // Holding Register Empty interrupt
      temp = loadmem((addr_t)&uart->iir_fcr);
      if (temp != 0b11000010) {
        fail(9);
        return(9);
      }
      // Check interrupt is cleared
      temp = loadmem((addr_t)&uart->iir_fcr);
      if (temp != 0b11000001) {
        fail(10);
        return(10);
      }
    }
  }
  if (fifosize > 1) {
    if ((FIFO_RX_CNT) != 0) {
      fail(12); // RCNT error
      return 12;
    }
  }
  if (DATA_READY != 0) {
    fail(13); // dr bit error
    return 13;
  }
  return 0;
}
