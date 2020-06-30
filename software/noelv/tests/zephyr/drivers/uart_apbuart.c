/** @file
 * @brief Generic UART driver for APBUART.
 *
 * Note:
 * - Error handling is not implemented.
 * - The driver works only in polling mode, interrupt mode is not implemented.
 */

#include <errno.h>
#include <misc/__assert.h>
#include <device.h>
#include <init.h>
#include <soc.h>
#include <uart.h>
#include <stdint.h>

/* APBUART registers
 *
 * Offset | Name   | Description
 * ------ | ------ | ----------------------------------------
 * 0x0000 | data   | UART data register
 * 0x0004 | status | UART status register
 * 0x0008 | ctrl   | UART control register
 * 0x000c | scaler | UART scaler register
 * 0x0010 | debug  | UART FIFO debug register
 */

struct apbuart_regs {
  /** @brief UART data register
   *
   * Bit    | Name   | Description
   * ------ | ------ | ----------------------------------------
   * 7-0    | data   | Holding register or FIFO
   */
        uint32_t data;          /* 0x0000 */

  /** @brief UART status register
   *
   * Bit    | Name   | Description
   * ------ | ------ | ----------------------------------------
   * 31-26  | RCNT   | Receiver FIFO count
   * 25-20  | TCNT   | Transmitter FIFO count
   * 10     | RF     | Receiver FIFO full
   * 9      | TF     | Transmitter FIFO full
   * 8      | RH     | Receiver FIFO half-full
   * 7      | TH     | Transmitter FIFO half-full
   * 6      | FE     | Framing error
   * 5      | PE     | Parity error
   * 4      | OV     | Overrun
   * 3      | BR     | Break received
   * 2      | TE     | Transmitter FIFO empty
   * 1      | TS     | Transmitter shift register empty
   * 0      | DR     | Data ready
   */
        uint32_t status;        /* 0x0004 */

  /** @brief UART control register
   *
   * Bit    | Name   | Description
   * ------ | ------ | ----------------------------------------
   * 31     | FA     | FIFOs available
   * 14     | SI     | Transmitter shift register empty interrupt enable
   * 13     | DI     | Delayed interrupt enable
   * 12     | BI     | Break interrupt enable
   * 11     | DB     | FIFO debug mode enable
   * 10     | RF     | Receiver FIFO interrupt enable
   * 9      | TF     | Transmitter FIFO interrupt enable
   * 8      | EC     | External clock
   * 7      | LB     | Loop back
   * 6      | FL     | Flow control
   * 5      | PE     | Parity enable
   * 4      | PS     | Parity select
   * 3      | TI     | Transmitter interrupt enable
   * 2      | RI     | Receiver interrupt enable
   * 1      | TE     | Transmitter enable
   * 0      | RE     | Receiver enable
   */
        uint32_t ctrl;          /* 0x0008 */

  /** @brief UART scaler register
   *
   * Bit    | Name   | Description
   * ------ | ------ | ----------------------------------------
   * 11-0   | RELOAD | Scaler reload value
   */
        uint32_t scaler;        /* 0x000c */

  /** @brief UART FIFO debug register
   *
   * Bit    | Name   | Description
   * ------ | ------ | ----------------------------------------
   * 7-0    | data   | Holding register or FIFO
   */
        uint32_t debug;         /* 0x0010 */

};

/* APBUART register bits. */

/* Control register */
#define APBUART_CTRL_FA         (1 << 31)
#define APBUART_CTRL_DB         (1 << 11)
#define APBUART_CTRL_RF         (1 << 10)
#define APBUART_CTRL_TF         (1 << 9)
#define APBUART_CTRL_LB         (1 << 7)
#define APBUART_CTRL_FL         (1 << 6)
#define APBUART_CTRL_PE         (1 << 5)
#define APBUART_CTRL_PS         (1 << 4)
#define APBUART_CTRL_TI         (1 << 3)
#define APBUART_CTRL_RI         (1 << 2)
#define APBUART_CTRL_TE         (1 << 1)
#define APBUART_CTRL_RE         (1 << 0)

/* Status register */
#define APBUART_STATUS_RF       (1 << 10)
#define APBUART_STATUS_TF       (1 << 9)
#define APBUART_STATUS_RH       (1 << 8)
#define APBUART_STATUS_TH       (1 << 7)
#define APBUART_STATUS_FE       (1 << 6)
#define APBUART_STATUS_PE       (1 << 5)
#define APBUART_STATUS_OV       (1 << 4)
#define APBUART_STATUS_BR       (1 << 3)
#define APBUART_STATUS_TE       (1 << 2)
#define APBUART_STATUS_TS       (1 << 1)
#define APBUART_STATUS_DR       (1 << 0)

/* For APBUART implemented without FIFO */
#define APBUART_STATUS_HOLD_REGISTER_EMPTY (1 << 2)

/* Device constant configuration parameters */
struct apbuart_dev_cfg {
	struct apbuart_regs *regs;
};

enum {
        FIFO_UNKNOWN,
        FIFO_YES,
        FIFO_NO,
};

/* Device run time data */
struct apbuart_dev_data {
	int fifoinfo;
};


#define DEV_CFG(dev) \
	((const struct apbuart_dev_cfg *const)(dev)->config->config_info)
#define DEV_DATA(dev) \
	((struct apbuart_dev_data *const)(dev)->driver_data)


int apbuart_init(struct device *dev)
{
	/* nothing to do here */
	return 0;
}

static void apbuart_poll_out(struct device *dev, unsigned char x)
{
        volatile struct apbuart_regs *regs = (void *) DEV_CFG(dev)->regs;
        int fi;

        /* Use transmitter FIFO if available */
again:
        fi = DEV_DATA(dev)->fifoinfo;
        if (FIFO_YES == fi) {
                /* Transmitter FIFO full flag is available */
                while (regs->status & APBUART_STATUS_TF);
        } else if (FIFO_NO == fi) {
                /*
                 * Transmitter "hold register empty" AKA "FIFO empty" flag is
                 * available
                 */
                while (!(regs->status & APBUART_STATUS_HOLD_REGISTER_EMPTY));
        } else {
                /* First time: probe */
                if (regs->ctrl & APBUART_CTRL_FA) {
                	DEV_DATA(dev)->fifoinfo = FIFO_YES;
                } else {
                	DEV_DATA(dev)->fifoinfo = FIFO_NO;
                }
                goto again;
        }

        regs->data = x & 0xff;
}

static int apbuart_poll_in(struct device *dev, unsigned char *c)
{
        volatile struct apbuart_regs *regs = (void *) DEV_CFG(dev)->regs;

        while (0 == (regs->status & APBUART_STATUS_DR));

        *c = regs->data & 0xff;

        return 0;
}

/* Driver API defined in uart.h */
static struct uart_driver_api apbuart_driver_api = {
	.poll_in = &apbuart_poll_in,
	.poll_out = &apbuart_poll_out,
	.err_check = NULL,
};

#ifdef CONFIG_APBUART0

static const struct apbuart_dev_cfg apbuart0_config = {
		.regs = (struct apbuart_regs*) __BSP_CON_HANDLE,
};

static struct apbuart_dev_data apbuart0_data = {
		.fifoinfo = FIFO_UNKNOWN,
};

DEVICE_AND_API_INIT(
		APBUART0,
		"APBUART0",
		&apbuart_init,
		&apbuart0_data,
		&apbuart0_config,
		PRE_KERNEL_1,
		CONFIG_KERNEL_INIT_PRIORITY_DEVICE,
		&apbuart_driver_api
);

#endif
