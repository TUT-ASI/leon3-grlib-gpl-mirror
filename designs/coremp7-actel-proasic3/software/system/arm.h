#ifndef ARM_PROCESSOR_HEADER
#define ARM_PROCESSOR_HEADER

/*******************************************************************************
 * Functions for enabling/disabling IRQ and FIQ in the ARM core by changing
 * the I and F bits of the CPSR.
 */
void EnableIRQ(void);
void DisableIRQ(void);

void EnableFIQ(void);
void DisableFIQ(void);

/*******************************************************************************
 * Functions for setting the location of the stack for FIQ and IRQ modes of the
 * ARM core.
 *
 * Note:
 *  You may need to modify the values for TOP_OF_MEMORY and the stack sizes in
 *  file int_stack.s to suit your design/software requirements.
 */
void SetupFIQStack(void);
void SetupIRQStack(void);

/*******************************************************************************
 * Functions for setting the IRQ/FIQ vectors.
 * These function take the address of the handler as argument.
 */
void SetIRQHandler(unsigned int routine);
void SetFIQHandler(unsigned int routine);

#endif
