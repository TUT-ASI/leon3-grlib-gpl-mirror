#ifndef UART_REGISTERS_HEADER
#define UART_REGISTERS_HEADER

/*
 * Registers offsets
 */ 
#define UART_DATA_REG_OFFSET        0x00
#define UART_STATUS_REG_OFFSET      0x04
#define UART_CTRL_REG_OFFSET        0x08
#define UART_SCALER_REG_OFFSET      0x0C
#define UART_FIFO_DBG_REG_OFFSET    0x10

/*
 * UART register addresses
 */
#define UART_DATA_REG               (UART_BASE_ADDR + UART_DATA_REG_OFFSET)
#define UART_STATUS_REG             (UART_BASE_ADDR + UART_STATUS_REG_OFFSET)
#define UART_CTRL_REG               (UART_BASE_ADDR + UART_CTRL_REG_OFFSET)
#define UART_SCALER_REG             (UART_BASE_ADDR + UART_SCALER_REG_OFFSET)
#define UART_FIFO_DBG_REG           (UART_BASE_ADDR + UART_FIFO_DBG_REG_OFFSET)

#endif
