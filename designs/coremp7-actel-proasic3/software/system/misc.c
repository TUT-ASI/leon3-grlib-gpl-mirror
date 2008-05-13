/* This file contains miscellaneous functions used to initialize the
 * system as well as functions for handling the system timer, interrupts
 * and print-outs via UART.
 */

#include <stdarg.h>
#include <stdio.h>
#include "coremp7.h"

/* Global tick count. Incremented by periodic timer triggered FIQ */
volatile unsigned long int tick;
/* Dummy variable incremented by a dummy function. See dummy funtion
 * description further down. */
volatile unsigned long int crap;

_ssize_t _write (struct _reent *r, int file, const void *ptr, size_t len);
void FIQHandler(void) __attribute__ ((interrupt ("FIQ")));
void SetupTimer(void);

/* This is a dummy function that increments a dummy value. Calls to this
 * function are made to prevent gcc optimizations from reordering register
 * writes. For example, optimizing with -O2 reorders the IntCtrlInit()
 * register writes to first enable FIQ source 0 and then disable FIQ all together.
 * This is obviously not correct and will cause interrupts to never occur.
 * Placing calls to this dummy function inbetween the register writes
 * stops this optimization and correct behaviour is achieved.*/
void dummy(void){
	crap++;
}

/* Returns the current timer 'tick' value */
unsigned long int GetTick()
{
	return(tick);
}

/* Fast interrupt request (FIQ) handler, which handles the timer */
void FIQHandler(void)
{
    /* Clear timer interrupt */
    WRITE_REGISTER(TIMER_T1_CONTROL_REG, 0xF);
    dummy();
    
    /* Acknowledge interrupt to wrapper */
    WRITE_REGISTER(CMP7WRAPPER_INTACK_REG, 0x1);
    dummy();

    /* Increment tick counter. */
    tick++;
}

/* Prepares the processor for handling interrupts.
 * These functions are located in int_stacks.s and arm.c. */
void InterruptInit(void)
{
    DisableIRQ();
    DisableFIQ();
    SetupIRQStack();
    SetupFIQStack();
    SetFIQHandler((unsigned int)FIQHandler);
}

void WrapperInit(void)
{
	/* Set FIQ mask to forward interrupt 8 (GPTIMER) as a fast interrupt */
	WRITE_REGISTER(CMP7WRAPPER_FIQMASK_REG, 0x100);
}

void IntCtrlInit(void)
{
    /* Set all interrupts to level 1 */
    WRITE_REGISTER(INT_CNTL_IRQ_LEVEL_REG, 0xFFFFFFFF);
	dummy();
    /* Reset all interrupts */
    WRITE_REGISTER(INT_CNTL_IRQ_PENDING_REG, 0x00000000);
    dummy();
    /* Set the force register to all zeroes */
    WRITE_REGISTER(INT_CNTL_IRQ_FORCE_REG, 0x00000000);
    dummy();
    /* Set the IRQ mask register to activate IRQ 8 (GPTIMER) */
    WRITE_REGISTER(INT_CNTL_PROCESSOR_IRQ_MASK_REG, 0x00000100);
    
}

void SetupTimer(void)
{
    /* Disable timer 1 and set all the other config options */
    WRITE_REGISTER(TIMER_T1_CONTROL_REG, 0xE);
    dummy();
    /* Set scaler value to 9 (generates a tick every µs at 10 MHz) */
    WRITE_REGISTER(TIMER_SCALER_VAL, 0x9);
    /* Set scaler reload value to 9 (generates a tick every µs at 10 MHz) */
    WRITE_REGISTER(TIMER_SCALER_RELOAD_VAL, 0x9);
    /* Set timer counter value to 991. For some reason this seemed to make the interrupts
       occur closer to 1ms apart than if we set the counter value to 1000... */
    WRITE_REGISTER(TIMER_T1_COUNTER_VAL_REG, 0x3DF);
    /* Set timer reload value to 991. */
    WRITE_REGISTER(TIMER_T1_RELOAD_VAL_REG, 0x3DF);
    dummy();
    /* Enable timer 1 and set all the other config options */
    WRITE_REGISTER(TIMER_T1_CONTROL_REG, 0xF);
}

void UARTInit(void)
{
    // Set scaler to 130 (0x82) (to divide the 10 MHz clock to 76800, which is 8 times
    // the desired baud rate of 9600)
    WRITE_REGISTER(UART_SCALER_REG, 0x82);
    dummy();
    // Configures the UART
    WRITE_REGISTER(UART_CTRL_REG, 0x62);       
}

void uart0_putc(int ch)
{
	int status;
	
	// Wait for UART TX register to empty
	status = READ_REGISTER(UART_STATUS_REG);
	while ((status & 0x4) == 0) {
           status = READ_REGISTER(UART_STATUS_REG);
	}
	
	// Write data to UART TX register
	WRITE_REGISTER(UART_DATA_REG, ch);	
}

/* Write a string and end it with LF and CR */
int puts(const char *astring)
{
	
	printf(astring);
	
	uart0_putc('\r');
	uart0_putc('\n');
	
    return(1);
  	
}

/* printf implementation using the custom _write sycall which outputs to UART */
int printf(const char *fmt, ... )
{
   va_list args;
   int i, tmp, length;
   char buffer[1000]; 

   va_start(args,fmt);
   tmp=vsprintf(buffer, fmt, args);
   va_end(args); 

   /* Find string length */
   length = 0;
   for (i = 0; buffer[i] != '\0'; i++)
   {
      length++;
   }

   /* Print string using _write syscall (which in this case
    * prints to UART) */
   _write(0, 1, &buffer, length);

   return tmp;
}

/* Setup function that performs all the necessary initialization of the system. 
 * A call to this function should be placed first in the main function of the program. */
void SetupTimerAndUART(void) {
    
    tick = 0;
    crap = 0;

    /*
     * Wrapper initialization routine
     */
    WrapperInit();

    /*
     * Set the IRQ and FIQ stacks and install interrupt handlers.
     */
    InterruptInit();

    /*
     * Configure the interrupt controller
     */
    IntCtrlInit();

    /*
     * Configure the UART
     */
    UARTInit();
    
    /*
     * Allow the ARM core to process FIQ interrupts.
     */
    EnableFIQ();
    
    /*
     * Set up and start timer. It will produce an interrupt every millisecond.
     */
    SetupTimer();

}
