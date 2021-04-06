#include "grcanfd.h"

int grcanfd_test(addr_t paddr)
{

  // start of test
  report_device(0x010B5000);

  // can-fd register structures
  struct grcanfd_ctrl {
    volatile unsigned long conf;        /* 0x000 */
    volatile unsigned long stat;        /* 0x004 */
    volatile unsigned long ctrl;        /* 0x008 */
    volatile unsigned long capab;       /* 0x00C */
    volatile unsigned long dummy10;      /* 0x010 */
    volatile unsigned long dummy14;      /* 0x014 */
    volatile unsigned long smask;       /* 0x018 */
    volatile unsigned long scode;       /* 0x01C */
  };

  struct grcanfd_bit {
    volatile unsigned long nombr;       /* 0x040 */
    volatile unsigned long databr;      /* 0x044 */
    volatile unsigned long txdelcmp;     /* 0x048 */
  };

  struct grcanfd_copen {
    volatile unsigned long ctrl;        /* 0x080 */
    volatile unsigned long hbto;        /* 0x084 */
    volatile unsigned long hbcnt;       /* 0x088 */
    volatile unsigned long sts;        /* 0x08C */
  };

  struct grcanfd_irq {
    volatile unsigned long pimsr;       /* 0x100 */
    volatile unsigned long pimr;        /* 0x104 */
    volatile unsigned long pisr;        /* 0x108 */
    volatile unsigned long pir;        /* 0x10C */
    volatile unsigned long imr;        /* 0x110 */
    volatile unsigned long picr;        /* 0x114 */
  };

  struct grcanfd_tx {
    volatile unsigned long ctrl;        /* 0x200 */
    volatile unsigned long addr;        /* 0x204 */
    volatile unsigned long size;        /* 0x208 */
    volatile unsigned long wr;         /* 0x20C */
    volatile unsigned long rd;         /* 0x210 */
    volatile unsigned long irq;        /* 0x214 */
  };

  struct grcanfd_rx {
    volatile unsigned long ctrl;        /* 0x300 */
    volatile unsigned long addr;        /* 0x304 */
    volatile unsigned long size;        /* 0x308 */
    volatile unsigned long wr;         /* 0x30C */
    volatile unsigned long rd;         /* 0x310 */
    volatile unsigned long irq;        /* 0x314 */
    volatile unsigned long mask;        /* 0x318 */
    volatile unsigned long code;        /* 0x31C */
  };

  // local registers
  struct grcanfd_ctrl  *lctrl  = (struct grcanfd_ctrl *)  (paddr);
  struct grcanfd_bit  *lbit  = (struct grcanfd_bit *)  (paddr+0x040);
  struct grcanfd_copen *lcopen = (struct grcanfd_copen *) (paddr+0x080);
  struct grcanfd_irq  *lirq  = (struct grcanfd_irq *)  (paddr+0x100);
  struct grcanfd_tx   *ltx   = (struct grcanfd_tx *)   (paddr+0x200);
  struct grcanfd_rx   *lrx   = (struct grcanfd_rx *)   (paddr+0x300);

  // transmit and receive buffers, allocate 2kB per buffer
  volatile long int txbuf[512];
  volatile long int rxbuf[512];

  // Memory pointers
  volatile int *memorytx;
  volatile int *memoryrx;

  volatile int i = 0;

  // search for start of allocated TX memory
  long int memorytxbase;
  memorytxbase = (long int)&txbuf[0];
  // search for 1k boundary within allocated memory, store as base
  memorytxbase = memorytxbase & 0xFFFFFC00;
  memorytxbase = memorytxbase + 0x400;

  // search for start of allocated RX memory
  long int memoryrxbase;
  memoryrxbase = (long int)&rxbuf[0];
  // search for 1k boundary within allocated memory, store as base
  memoryrxbase = memoryrxbase & 0xFFFFFC00;
  memoryrxbase = memoryrxbase + 0x400;

  // CAN bus configuration
  int SELECTION = 0;
  int ENABLE = 0x1;
  int LOOPBACK = 1;
  int LOOPBACK_SEL = 0;

  // Nominal bit-time configuration
  int NOM_SCALER = 1;
  int NOM_PH1 = 16;
  int NOM_PH2 = 8;
  int NOM_SJW = 6;

  // Data bit-time configuration
  int DATA_SCALER = 0;
  int DATA_PH1 = 3;
  int DATA_PH2 = 2;
  int DATA_SJW = 2;

  // CAN output 0 test
  report_subtest(0x1);

  // Setup TX buffer
  memorytx = (int*)memorytxbase;
  *memorytx = 0x913579BD;
  memorytx++;
  *memorytx = 0x80000000;
  memorytx++;
  *memorytx = 0x01020304;
  memorytx++;
  *memorytx = 0x05060708;
  memorytx++;

  // Reset CAN-FD codec
  lctrl->ctrl  = 0x00000002;
  // Configure the CAN bus and the bit times
  lctrl->conf  = (LOOPBACK_SEL<<7) | (LOOPBACK<<6) | (SELECTION<<3) | (ENABLE<<1);
  lbit->nombr  = (NOM_SCALER<<16) | (NOM_PH1<<10) | (NOM_PH2<<5) | (NOM_SJW<<0);
  lbit->databr = (DATA_SCALER<<16) | (DATA_PH1<<10) | (DATA_PH2<<5) | (DATA_SJW<<0);
  // Clear all interrupt bits
  lirq->picr  = 0xFFFFFFFF;
  //  lirq->imr   = 0x00000200;
  // Enable the CAN-FD codec
  lctrl->ctrl  = 0x00000001;

  // Classical CAN frame TX test
  report_subtest(0x2);

  // TX circular buffer configuration
  ltx->addr = memorytxbase;
  ltx->size = 0x00000080;
  ltx->wr  = 0x00000000;
  ltx->rd  = 0x00000000;
  ltx->irq  = 0x00000010; // trigger interrupt after first packet
  ltx->ctrl = 0x00000001;

  // RX circular buffer configuration
  lrx->addr = memoryrxbase;
  lrx->size = 0x00000080;
  lrx->wr  = 0x00000000;
  lrx->rd  = 0x00000000;
  lrx->irq  = 0x00000010; // trigger interrupt after first packet
  lrx->mask = 0x00000000; // all frames accepted
  lrx->ctrl = 0x00000001;

  // send message
  ltx->wr  = 0x00000010; // 1 classical CAN frame

  // wait until the message is transmitted
  while ((ltx->rd & 0xFFFF) != 0x0010) ;

  while(i < 20) i++;
  i = 0;

  // check status
  if (lctrl->stat != 0x00000000) fail(1);
  if (lirq->pir != 0x00000760) fail(2);

  // Set RX pointer to base memory start and read out the frame
  memoryrx = (int*)memoryrxbase;
  if (*memoryrx != 0x913579BD) fail(3);
  memoryrx++;
  if (*memoryrx != 0x80000000) fail(4);
  memoryrx++;
  if (*memoryrx != 0x01020304) fail(5);
  memoryrx++;
  if (*memoryrx != 0x05060708) fail(6);
  memoryrx++;

  // CAN output 1 test
  report_subtest(0x3);

  SELECTION = 1;
  ENABLE = 2;

  // Disable TX and RX channels and the codec before reconfiguring the CAN bus
  ltx->ctrl  = 0x00000000;
  lrx->ctrl  = 0x00000000;
  lctrl->ctrl = 0x00000000;
  // Reconfigure the CAN bus
  lctrl->conf = (LOOPBACK_SEL<<7) | (LOOPBACK<<6) | (SELECTION<<3) | (ENABLE<<1);
  // Clear all interrupt bits
  lirq->picr  = 0xFFFFFFFF;
  // Enable the CAN-FD codec
  lctrl->ctrl = 0x00000001;

  // Setup TX buffer
  memorytx = (int*)memorytxbase;
  *memorytx = 0x87CB4126;
  memorytx++;
  *memorytx = 0x80000000;
  memorytx++;
  *memorytx = 0xF1F2F3F4;
  memorytx++;
  *memorytx = 0xA5A6A7A8;
  memorytx++;

  // Classical CAN frame TX test
  report_subtest(0x5);

  // Reconfigure the TX circular buffer
  ltx->addr = memorytxbase;
  ltx->wr  = 0x00000000;
  ltx->rd  = 0x00000000;
  ltx->ctrl = 0x00000001;

  // Reconfigure the RX circular buffer
  lrx->addr = memoryrxbase;
  lrx->wr  = 0x00000000;
  lrx->rd  = 0x00000000;
  lrx->ctrl = 0x00000001;

  // send message
  ltx->wr  = 0x00000010; // 1 classical CAN frame

  // wait until the message is transmitted
  while ((ltx->rd & 0xFFFF) != 0x0010) ;

  while(i < 20) i++;
  i = 0;

  // check status
  if (lctrl->stat != 0x00000000) fail(7);
  if (lirq->pir != 0x00000760) fail(8);

  // Set RX pointer to base memory start and read out the frame
  memoryrx = (int*)memoryrxbase;
  if (*memoryrx != 0x87CB4126) fail(9);
  memoryrx++;
  if (*memoryrx != 0x80000000) fail(10);
  memoryrx++;
  if (*memoryrx != 0xF1F2F3F4) fail(11);
  memoryrx++;
  if (*memoryrx != 0xF5F6F7F8) fail(12);
  memoryrx++;

  // End of the test

  // clear interrupt
  lirq->picr  = 0xFFFFFFFF;

  // reset core
  lctrl->ctrl = 0x00000002;

  return 0;
}
