#include "leon3.h"
#include "testmod.h" 
#include "mmu.h" 

#ifndef RAMSTART
#define RAMSTART 0x40000000
#endif

void mmu_so_check(void){

  int i,twrite;
  int *iptr;
  volatile int *check;

  check = 0x400F0000;
  *check = 0x0;
  //all pages are 1-1 mapped on 16MB
  //granularity apart from the one starts
  //at RAMSTART
  //iptr=0x40040000;
  iptr = RAMSTART + 0x40000;
  for (i=0;i<256;i++){
    if (i != 64){
      //*iptr = 0x040000EE;
      *iptr = (RAMSTART>>4)+0xEE;
    } 
    else{
      //*iptr = 0x04004801;
      *iptr = (RAMSTART>>4)+0x04801;
    }
         
    iptr++;
  }

  //256KB mappings
  //iptr=0x40048000;
  iptr = RAMSTART+0x048000;
  //twrite = 0x04004821;
  twrite = (RAMSTART>>4)+0x04821;
  for (i=0;i<64;i++){
    *iptr = twrite + i*16;
    iptr++;
  }

  //KB mappings
  //iptr=0x40048200;
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

  //iptr=0x40050000;
  //*iptr=0x04004001;
  iptr=RAMSTART+0x50000;
  *iptr=(RAMSTART>>4)+0x4001;

  srmmu_set_ctable_ptr((unsigned long)(RAMSTART+0x50000));
  srmmu_set_context(0);

  asm volatile ("sta %g0, [%g0] 0x18\n\t");
  srmmu_set_mmureg(0x00000001);
  
  for (i=0;i<1000;i++){
    asm volatile("nop\n\t");
  }

  asm volatile ("add %g0,0x40,%g1\n\t");
  asm volatile ("sll %g1,0x18,%g1\n\t");
  asm volatile ("add %g0,0xF,%g2\n\t");
  asm volatile ("sll %g2,0x10,%g2\n\t");
  asm volatile ("add %g1,%g2,%g1\n\t");
  //first load
  asm volatile ("ld [%g1],%g0");
  for (i=0;i<10;i++){
    asm volatile("nop\n\t");
  }
  //load in s=1  
  asm volatile ("ld [%g1],%g0");
  for (i=0;i<10;i++){
    asm volatile("nop\n\t");
  }
  asm volatile ("rd %psr,%g1\n\t"); 
  asm volatile ("andn %g1,0x80,%g1\n\t");
  asm volatile ("wr %g1,%psr\n\t"); 
  for (i=0;i<10;i++){
    asm volatile("nop\n\t");
  }
  asm volatile ("add %g0,0x40,%g1\n\t");
  asm volatile ("sll %g1,0x18,%g1\n\t");
  asm volatile ("add %g0,0xF,%g2\n\t");
  asm volatile ("sll %g2,0x10,%g2\n\t");
  asm volatile ("add %g1,%g2,%g1\n\t");
  //load in s=0 must cause an exception 
  //addr 0x40F00000
  asm volatile ("ld [%g1],%g0");
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
  asm volatile ("add %g0,0x40,%g1\n\t");
  asm volatile ("sll %g1,0x18,%g1\n\t");
  asm volatile ("add %g0,0xF,%g2\n\t");
  asm volatile ("sll %g2,0x10,%g2\n\t");
  asm volatile ("add %g1,%g2,%g1\n\t");
  asm volatile ("ld [%g1],%g0");
  for (i=0;i<10;i++){
    asm volatile("nop\n\t");
  }
  asm volatile ("lda [%g1] 0x0A,%g0");
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




