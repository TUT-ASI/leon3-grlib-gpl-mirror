//    ---------------------------------------------------
//    -- Register Map
//    ---------------------------------------------------
//
//    -- Hart 0:
//    -- msip             @ 0000
//    -- mtimecmp lo      @ 4000
//    -- mtimecmp hi      @ 4004
//
//    -- Hart 1:
//    -- msip             @ 0004
//    -- mtimecmp lo      @ 4008
//    -- mtimecmp hi      @ 400c
//    
//    -- ...
//    
//    -- bff8 mtime lo
//    -- bffc mtime hi


#include <stdio.h>
#include "report.h"

//TODO: Check this
#ifdef NOELV_SYSTEST
#  include "bcc/bcc.h"
#else
#  include "irqmp.h"
#endif
 
//TODO: move to a more generic library
//Global interrupts control
#define MSTATUS_UIE         0x00000001
#define MSTATUS_SIE         0x00000002
#define MSTATUS_HIE         0x00000004
#define MSTATUS_MIE         0x00000008

#define IRQ_S_SOFT   1
#define IRQ_H_SOFT   2
#define IRQ_M_SOFT   3
#define IRQ_S_TIMER  5
#define IRQ_H_TIMER  6
#define IRQ_M_TIMER  7
#define IRQ_S_EXT    9
#define IRQ_H_EXT    10
#define IRQ_M_EXT    11
#define IRQ_COP      12
#define IRQ_HOST     13

#define MIP_SSIP            (1 << IRQ_S_SOFT)
#define MIP_HSIP            (1 << IRQ_H_SOFT)
#define MIP_MSIP            (1 << IRQ_M_SOFT)
#define MIP_STIP            (1 << IRQ_S_TIMER)
#define MIP_HTIP            (1 << IRQ_H_TIMER)
#define MIP_MTIP            (1 << IRQ_M_TIMER)
#define MIP_SEIP            (1 << IRQ_S_EXT)
#define MIP_HEIP            (1 << IRQ_H_EXT)
#define MIP_MEIP            (1 << IRQ_M_EXT)

#define MIE_SSIE            (1 << IRQ_S_SOFT)
#define MIE_HSIE            (1 << IRQ_H_SOFT)
#define MIE_MSIE            (1 << IRQ_M_SOFT)
#define MIE_STIE            (1 << IRQ_S_TIMER)
#define MIE_HTIE            (1 << IRQ_H_TIMER)
#define MIE_MTIE            (1 << IRQ_M_TIMER)
#define MIE_SEIE            (1 << IRQ_S_EXT)
#define MIE_HEIE            (1 << IRQ_H_EXT)
#define MIE_MEIE            (1 << IRQ_M_EXT)


#define read_csr(reg) ({ unsigned long __tmp; \
  asm volatile ("csrr %0, " #reg : "=r"(__tmp)); \
  __tmp; })

#define write_csr(reg, val) ({ \
  asm volatile ("csrw " #reg ", %0" :: "rK"(val)); })

#define swap_csr(reg, val) ({ unsigned long __tmp; \
  asm volatile ("csrrw %0, " #reg ", %1" : "=r"(__tmp) : "rK"(val)); \
  __tmp; })

#define set_csr(reg, bit) ({ unsigned long __tmp; \
  asm volatile ("csrrs %0, " #reg ", %1" : "=r"(__tmp) : "rK"(bit)); \
  __tmp; })

#define clear_csr(reg, bit) ({ unsigned long __tmp; \
  asm volatile ("csrrc %0, " #reg ", %1" : "=r"(__tmp) : "rK"(bit)); \
  __tmp; })


/* Interrupt Specific defines - used for mtvec.mode field, which is bit[0] for
 * designs with CLINT, or [1:0] for designs with a CLIC */
#define MTVEC_MODE_CLINT_DIRECT              0x00
#define MTVEC_MODE_CLINT_VECTORED            0x01

// CLINT
#define CLINT_BASE_ADDR                      0xe0000000
#define MSIP_BASE_OFF                        0x00000000
#define MSIP_PER_HART_OFF                    0x4
#define MTIMECMP_BASE_OFF                    0x00004000
#define MTIMECMP_PER_HART_OFF                0x8
#define MTIME_BASE_OFF                       0x0000bff8

#define MSIP_HART_OFF(hartid)                (MSIP_BASE_OFF + (hartid * MSIP_PER_HART_OFF))
#define MTIMECMP_HART_OFF(hartid)            (MTIMECMP_BASE_OFF + (hartid * MTIMECMP_PER_HART_OFF))

// TRAP HANDLER
#define MCAUSE_INT_MASK  0x8000000000000000
#define MCAUSE_CODE_MASK 0x7FFFFFFFFFFFFFFF
#define M_SOFTWARE_INT   3
#define M_TIMER_INT      7

/* Setup prototypes */
void interrupt_global_enable_a (void);
void interrupt_global_disable_a (void);
void interrupt_software_enable (void);
void interrupt_software_disable (void);
void interrupt_timer_enable (void);
void interrupt_timer_disable (void);

//void software_interrupt_handler(void *arg, int source);
void __attribute__((weak, interrupt)) trap_handler();
void software_interrupt_handler(void);
void timer_interrupt_handler(void);


int interrupt_test_fail = 0;

int aclint_test(addr_t addr) {

  volatile uint32_t *msip_hart0 = (uint32_t *) (addr + MSIP_HART_OFF(0));
  volatile uint64_t *mtimercmp_hart0 = (uint64_t *) (addr + MTIMECMP_HART_OFF(0));
  volatile uint64_t *mtimer = (uint64_t *) (addr + MTIME_BASE_OFF);
  volatile uint64_t current_time;

  uint32_t mode = 0; //direct mode
  uintptr_t mtvec_base;
 

  /* Write mstatus.mie = 0 to disable all machine interrupts prior to setup */
  interrupt_global_disable_a();

  // Set mtvec to handle the trap
  //for (i=1 ; i++ ; i<10){
  //  if (bcc_isr_register(3, software_interrupt_handler, arg) == NULL) 
  //    printf("Failed to install software interrupt handler\n");
  //}
  mtvec_base = (uintptr_t) &trap_handler;
  write_csr(mtvec, (mtvec_base | mode));

  
  // Enable software interrupts
  interrupt_software_enable();

  // Enable and configure timer interrupts
  current_time = *mtimer;
  *mtimercmp_hart0 = current_time + 2000;
  interrupt_timer_enable();

  // Enable global interrupts
  interrupt_global_enable_a();

  // Trigger software interrupt
  *msip_hart0 = 1;

  // Trigger timer interrupt
  while(current_time + 2500 > *mtimer){
    //printf("threshold: %lu\n", current_time+2500);
    //printf("time: %lu\n", *mtimer);
  }

  return 0;
}


// [31]=1 interrupt, else exception
// low bits show code
void __attribute__((weak, interrupt)) trap_handler() {
  uint64_t mcause_value = read_csr(mcause);
  if (mcause_value & MCAUSE_INT_MASK) {
    // Branch to interrupt handler here
    switch(mcause_value & MCAUSE_CODE_MASK) {
      case M_SOFTWARE_INT:
        software_interrupt_handler();
        break;
      case M_TIMER_INT:
        timer_interrupt_handler();
        break;
      default:
        interrupt_test_fail=1;
        break;
    }
  } else {
    // Branch to exception handler
    printf("Exception: macause=%u\n", mcause_value);
  }
}

//void software_interrupt_handler(void *arg, int source) {
//  printf("Congratulations\n");
//}
void software_interrupt_handler(void) {
  uint32_t *msip_hart0 = (uint32_t *) (CLINT_BASE_ADDR + MSIP_HART_OFF(0));
  printf("Software interrupt!\n");
  *msip_hart0 = 0;
}

void timer_interrupt_handler(void) {
  printf("Timer interrupt!\n");
  interrupt_timer_disable();
}

void interrupt_global_enable_a (void) {
  set_csr(mstatus, MSTATUS_MIE); 
  set_csr(mstatus, MSTATUS_SIE); 
}

void interrupt_global_disable_a (void) {
  clear_csr(mstatus, MSTATUS_MIE); 
  clear_csr(mstatus, MSTATUS_SIE); 
}

void interrupt_software_enable (void) {
  set_csr(mie, MIE_MSIE); 
}

void interrupt_software_disable (void) {
  clear_csr(mie, MIE_MSIE); 
}

void interrupt_timer_enable (void) {
  set_csr(mie, MIE_MTIE); 
}

void interrupt_timer_disable (void) {
  clear_csr(mie, MIE_MTIE); 
}
