#;-------------------------------------------------------------------------------
#; Copyright Actel Corporation.
#;
#; This file contains ARM7 assembly code for enabling/disabling interrupts in
#; the ARM processor core and setting the stacks for the different ARM modes.
#;
#    EXPORT EnableIRQ
#    EXPORT DisableIRQ
#    EXPORT SetupIRQStack

#    EXPORT EnableFIQ
#    EXPORT DisableFIQ
#    EXPORT SetupFIQStack

#    EXPORT __user_initial_stackheap    
    
#    AREA irq,CODE,READONLY
	.text
	
#;-------------------------------------------------------------------------------
#; System's top of memory.
#;
#; You need to change this value if you change the address or size of the RAM in
#; your system. This value is used to specify the location of the stacks for the
#; different modes of the ARM processor.
#;
#;
.equ TOP_OF_MEMORY,	0x00200000

#;-------------------------------------------------------------------------------
#; Stacks sizes.
#;
#; You need to evaluate the stack size requirements of your application and 
#; change the values below accordingly.
#;
.equ FIQ_STACK_SIZE,	4096
.equ IRQ_STACK_SIZE,	4096
.equ SVC_STACK_SIZE,	4096
.equ USR_STACK_SIZE,	4096

#;-------------------------------------------------------------------------------
#; Heap size.
#;
.equ HEAP_SIZE,	0x00100000

#;-------------------------------------------------------------------------------
#; Stacks and heap organisation.
#;
.equ FIQ_STACK_ADDR,	TOP_OF_MEMORY
.equ IRQ_STACK_ADDR,	FIQ_STACK_ADDR-FIQ_STACK_SIZE
.equ SVC_STACK_ADDR,	IRQ_STACK_ADDR-IRQ_STACK_SIZE
.equ USR_STACK_ADDR,	SVC_STACK_ADDR-SVC_STACK_SIZE
.equ HEAP_START_ADDR,	USR_STACK_ADDR-HEAP_SIZE

#;-------------------------------------------------------------------------------
#; CPSR values for the ARM modes.
#;
.equ	MODE_FIQ,	0x0011
.equ	MODE_IRQ,	0x0012
.equ	MODE_SVC,	0x0013
#;-------------------------------------------------------------------------------
#; Enable IRQ by clearing the IRQ bit in the CPSR.
#;
EnableIRQ:	.global	EnableIRQ
        stmfd sp!, {r0}
        mrs r0, cpsr
        bic r0, r0, #0x80
        msr cpsr_c, r0
        ldmfd sp!, {r0}
        bx lr

#;-------------------------------------------------------------------------------
#; Enable IRQ by setting the IRQ bit in the CPSR.
#;
DisableIRQ:	.global	DisableIRQ
        stmfd sp!, {r0}
        mrs r0, cpsr
        orr r0, r0, #0x80
        msr cpsr_c, r0
        ldmfd sp!, {r0}
        bx lr

#;-------------------------------------------------------------------------------
#; Enable FIQ by clearing the FIQ bit in the CPSR.
#;
EnableFIQ:	.global EnableFIQ
        stmfd sp!, {r0}
        mrs r0, cpsr
        bic r0, r0, #0x40
        msr cpsr_c, r0
        ldmfd sp!, {r0}
        bx lr


#;-------------------------------------------------------------------------------
#; Disable FIQ by setting the FIQ bit in the CPSR.
#;
DisableFIQ:	.global DisableFIQ
        stmfd sp!, {r0}
        mrs r0, cpsr
        orr r0, r0, #0x40
        msr cpsr_c, r0
        ldmfd sp!, {r0}
        bx lr

#;-------------------------------------------------------------------------------
#; Set the stack location for IRQ mode.
#;
SetupIRQStack:	.global SetupIRQStack
         mrs     r1, cpsr
         bic     r1, r1, #0x1f
         orr     r1, r1, #MODE_IRQ
         msr     cpsr_c, r1
         ldr     r13, =IRQ_STACK_ADDR
         bic     r1, r1, #0x1f
         orr     r1, r1, #MODE_SVC
         msr     cpsr_c, r1
         bx lr


#;-------------------------------------------------------------------------------
#; Set the stack location for FIQ mode.
#;
SetupFIQStack:	.global SetupFIQStack
         mrs     r1, cpsr                /* read CPSR into r1. */
         bic     r1, r1, #0x1f           /* clear current mode */
         orr     r1, r1, #MODE_FIQ       /* set IRQ mode */
         msr     cpsr_c, r1              /* now we should be in FIQ mode */
         ldr     r13, =FIQ_STACK_ADDR    /* set up FIQ stack pointer. */
         bic     r1, r1, #0x1f           /* clear current mode */
         orr     r1, r1, #MODE_SVC       /* set SVC mode */
         msr     cpsr_c, r1              /* now we should be in SVC mode */
         bx lr

#;-------------------------------------------------------------------------------
#; Set the values for the C stack and heap locations.
#;
#; This routine is called by the C runtime libraries. See section 5.10 of the 
#; RealView Compilation Tools version2.2, Compiler and Libraries Guide.
#;
#__user_initial_stackheap:	/* FUNCTION */
#    ldr   r0,=HEAP_START_ADDR   /* Heap limit is returned in r0 */
#    ldr   r1,=SVC_STACK_ADDR    /* Stack base is returned in r1 */
#    mov   pc,lr
#    ENDFUNC

.end
