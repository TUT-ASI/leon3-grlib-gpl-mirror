#include "leon3.h"
#include "testmod.h" 
#include "mmu.h" 

#ifndef RAMSTART
#define RAMSTART 0x40000000
#endif

/* Trap handlers defined in mmu_asm.S */
extern void systest_instruction_access_exception(void);
extern void systest_data_access_exception(void);

/* SPARC V8 TT value for MMU Instruction access Exception */
#define MYTT_INSTRUCTION_ACCESS_EXCEPTION 1
#define MYTT_DATA_ACCESS_EXCEPTION 9

void mmu_so_check(void){

  int i,twrite;
  int *iptr;
  volatile int *check;

  int addr = RAMSTART + 0xF0000;
  int tmp;

  check = RAMSTART + 0xF0000;
  *check = 0x0;
  //all pages are 1-1 mapped on 16MB
  //granularity apart from the one starts
  //at RAMSTART
  iptr = RAMSTART + 0x40000;

  for (i=0;i<256;i++){
    if (i != 64){
      //*iptr = 0x040000EE;
      *iptr = (RAMSTART>>4)+0xEE;
    } 
    else{
      //*iptr = RAMSTART + 0x48000
      *iptr = (RAMSTART>>4)+0x04801;
    }
         
    iptr++;
  }

  //256KB mappings
  //iptr= RAMSTART + 0x48000
  iptr = RAMSTART+0x048000;
  //twrite = 0x04004821;
  twrite = (RAMSTART>>4)+0x04821;
  for (i=0;i<64;i++){
    *iptr = twrite + i*16;
    iptr++;
  }

  //KB mappings
  //iptr=RAMSTART+0x48200;
  iptr = RAMSTART+0x048200;
  //twrite = 0x040000EE;
  twrite = (RAMSTART>>4)+0xEE;
  for (i=0;i<64*4;i++){
    *iptr = twrite;
    twrite = twrite + 256;
    iptr++;
    if (i == 2*64){
      twrite = twrite + 16; //supervisor only 
    }
  }

  //iptr=RAMSTART+ 0x50000;
  //*iptr=0x04004001;
  iptr=RAMSTART+0x50000;
  *iptr=(RAMSTART>>4)+0x4001;

  srmmu_set_ctable_ptr((unsigned long)(RAMSTART+0x50000));
  srmmu_set_context(0);

  asm volatile ("sta %g0, [%g0] 0x18\n\t");

  unsigned long mmu_reg_val;
  mmu_reg_val = srmmu_get_mmureg();
  srmmu_set_mmureg(0x00000001);
 
  for (i=0;i<1000;i++){
    asm volatile("nop\n\t");
  }

  //first load
  asm volatile("ld [%1], %0"
        : "=r"(tmp)
        : "r"(addr)
        ); 
 
  asm volatile("nop\n\t");
  asm volatile("nop\n\t");
  asm volatile("nop\n\t");
  asm volatile("nop\n\t");
  asm volatile("nop\n\t");
  asm volatile("nop\n\t");
  asm volatile("nop\n\t");
  asm volatile("nop\n\t");
  asm volatile("nop\n\t");
  asm volatile("nop\n\t");
  
  //load in s=1  
  // asm volatile ("ld [%g1],%g0");
  asm volatile("ld [%1], %0"
        : "=r"(tmp)
        : "r"(addr)
        ); 

  for (i=0;i<10;i++){
    asm volatile("nop\n\t");
  }

  bcc_set_trap(MYTT_INSTRUCTION_ACCESS_EXCEPTION, systest_instruction_access_exception);
  bcc_set_trap(MYTT_DATA_ACCESS_EXCEPTION, systest_data_access_exception);

  //s=0
  setpsr(xgetpsr() & (~0x80));

  for (i=0;i<10;i++){
    asm volatile("nop\n\t");
  }
  //load in s=0 must cause an exception 
  //addr 0x400F0000
  //asm volatile ("ld [%g1],%g0");
  
    asm volatile("ld [%1], %0"
  	       : "=r"(tmp)
  	       : "r"(addr)
  	       ); 


   for (i=0;i<10;i++){
    asm volatile("nop\n\t");
  }

  //mmu off
  srmmu_set_mmureg_aligned(0x00000000);
  for (i=0;i<10;i++){
    asm volatile("nop\n\t");
  }

  if (*check != 0x123) 
    fail(1);
  
  *check = 0;

  asm("flush");
  for (i=0;i<1000;i++){
    asm volatile("nop\n\t");
  }

  //mmu on
  srmmu_set_mmureg(0x00000001);
  for (i=0;i<10;i++){
    asm volatile("nop\n\t");
  }
  //load in user asi must cause an exception 
  //addr 0x400F0000
  asm volatile("ld [%1], %0"
  	       : "=r"(tmp)
  	       : "r"(addr)
  	       ); 

  asm volatile("nop\n\t");
  asm volatile("nop\n\t");
  asm volatile("nop\n\t");
  asm volatile("nop\n\t");
  asm volatile("nop\n\t");
  asm volatile("nop\n\t");
  asm volatile("nop\n\t");
  asm volatile("nop\n\t");
  asm volatile("nop\n\t");
  asm volatile("nop\n\t");

  asm volatile("lda [%1] 0x0A, %0"
  	       : "=r"(tmp)
  	       : "r"(addr)
  	       ); 

  for (i=0;i<10;i++){
    asm volatile("nop\n\t");
  }

  //mmu off
  srmmu_set_mmureg_aligned(0x00000000);
  asm("flush");
  for (i=0;i<10;i++){
    asm volatile("nop\n\t");
  }

  if (*check != 0x123) 
    fail(2);
}




