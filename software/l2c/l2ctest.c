/* *******************************************************************************
 * L2-Cache test 
 *
 * ******************************************************************************* */
#include <stdlib.h>
#include "l2capi.h"
#include "l2cextra.h"
  
struct irqmp {
        volatile unsigned int irqlevel;    /* 0x00 */
        volatile unsigned int irqpend;	   /* 0x04 */
        volatile unsigned int irqforce;	   /* 0x08 */
        volatile unsigned int irqclear;	   /* 0x0C */
        volatile unsigned int mpstatus;	   /* 0x10 */
        volatile unsigned int broadcast;   /* 0x14 */
        volatile unsigned int dummy0;      /* 0x18 */
        volatile unsigned int wdogctrl;    /* 0x1C (IRQ(A)MP) */
        volatile unsigned int asmpctrl;    /* 0x20 (IRQ(A)MP) */
        volatile unsigned int icsel0;	   /* 0x24 (IRQ(A)MP) */
        volatile unsigned int icsel1; 	   /* 0x28 */
        volatile unsigned int dummy1[5];   /* 0x2c - 0x3C */
        volatile unsigned int irqmask;     /* 0x40 */
};


/* ******************************************************************************* */
/* ******************************************************************************* */


/* IRQ EDAC Test ***************************************************************** */
  struct l2cregs *l2c_global;
  volatile unsigned int *mem;
  volatile unsigned int scrub, ahb, cor, ucor, loop;
  int mem_size = 32*1024; //10*1024*1024;
  
  static inline int loadmem(int addr)
  {
    int tmp;        
    asm volatile (" lda [%1]1, %0 "
      : "=r"(tmp)
      : "r"(addr)
    );
    return tmp;
  };

  l2c_irqhandler(int irq){
    /*int offset = (rand() * RAND_MAX + rand()) % (10*1024*1024/4);*/
    int offset = rand() % (mem_size/4);
    int i;
    unsigned int tmp;
    unsigned int err = l2c_global->error;
    //printf("\nL2C: %d, 0x%08X, 0x%08X\n", irq, mem, offset);
    //l2c_error_show(l2c_global);
    
    if (err & L2C_ERR_VALID) {
      if (err & L2C_ERR_COR_UCOR != 0) {
        ucor++;
      } else {
        cor+=((err & L2C_ERR_COR_COUNT_MASK) >> L2C_ERR_COR_COUNT);
      };
      if (err & L2C_ERR_SCRUB) {
        scrub++;
      } else {
        ahb++;
      };
      printf("\rscrub: %d, ahb: %d, cor: %d, ucor: %d, loop: %d, |     \r", scrub, ahb, cor, ucor, loop);
    } else {
      printf("\rNo error found\r");
    };
    
    l2c_error_reset(l2c_global);
    for (i= (offset&7)+1; i > 0; i--) {
      //l2c_error_inject_data_write(1+2*(offset&1), l2c_global);
      //mem[offset] = 0x12345678;
      tmp = mem[offset];
      mem[offset] = tmp;
      l2c_error_inject_data((int)&mem[offset], 1, l2c_global);
      //printf("mem[0x%08X]\n", &mem[offset]);
      offset = rand() % (mem_size/4);
    };
  };
  
  l2c_irq_edac_test(int l2c_irq, unsigned int irqmp_base, struct l2cregs *l2c){
    l2c_global = l2c;
    //mem = malloc(mem_size);
    mem = (unsigned int*) 0x10000000;
    struct irqmp *ir = (struct irqmp*) irqmp_base;
    //int offset = (rand() * RAND_MAX + rand()) % (mem_size/4);
    int offset = rand() % (mem_size/4);
    unsigned int tmp;
    int i;
    
    volatile unsigned int *p = (unsigned int*) 0x10000000;

    printf("mem: %p, 0x%08X, offset: %d, &mem[offset]: 0x%08X\n", mem, mem[0], offset, &mem[offset]);
    printf("&loop: 0x%08X\n", &loop);
    
    for (i=0; i<mem_size/4;i++){
      mem[i] = (int)&mem[i];
    }

    scrub = 0; ahb = 0; cor = 0; ucor = 0; loop = 0;

    ir->irqmask = (ir->irqmask & ~(1 << l2c_irq));
    ir->irqpend = (ir->irqpend & ~(1 << l2c_irq));
  
    catch_interrupt(l2c_irqhandler, l2c_irq);
  
    ir->irqmask = (ir->irqmask | (1 << l2c_irq));
  
    l2c_error_reset(l2c);
    l2c_error_show(l2c);
    l2c_error_irq_enable(0xf, l2c);
    //l2c_error_irq_disable(0xf, l2c);
    l2c_error_inject_clear(l2c);
    l2c_scrub_start(0x1FF, l2c);
    
    //l2c_error_inject_data_write(1, l2c_global);
    mem[offset] = (int)&mem[offset];
    l2c_error_inject_data((int)&mem[offset], 1, l2c_global);
    //printf("mem[0x%08X]\n", &mem[offset]);

    printf("\n");
      
    while(1){
      for (i=0; i<mem_size/4;i++){
        if (loadmem((int)&mem[i]) != (int)&mem[i]) {
          //printf("\n\n\n*** Incorrect data ***!\n\n\n");
          *((volatile unsigned int*)(0xFFFFFFFF)) = 1;
        };
        //printf("i %d, 0x%X, mem[i]: 0x%08X\n", i, i*4, &mem[i]);
      };
      loop++;
    };
  
  };
/* ******************************************************************************* */


/* Main test ********************************************************************* */
  int main(){
    struct l2cregs *l2c = (struct l2cregs*) 0xff400000;

    int i,j;

    struct lookup_res res;
    unsigned int lookup_addr = 0x20;

    l2c_enable(l2c);
    l2c_edac_enable(l2c);
    l2c_scrub_stop(l2c);

    /* MTRR
    l2c_mtrr_add_uncached(0x30000000, 0xffff, l2c);
    l2c_mtrr_add_writethrough(0x30000000, 0xffff, l2c);
    l2c_mtrr_add_writeprotect(0x30000000, 0xffff, l2c);
    l2c_mtrr_show(l2c);
    l2c_mtrr_del(0x20000000, 0xffff, l2c);
    l2c_mtrr_del(0x30000000, 0xffff, l2c);  /* */

    /* Scrubber 
    l2c_scrub_show(l2c);
    l2c_scrub_start(255, l2c);
    l2c_scrub_show(l2c);
    l2c_scrub_stop(l2c);
    l2c_scrub_show(l2c); /* */

    /* Error/Scrub test */
    l2c_irq_edac_test(2, 0x80000300, l2c);

    /* Diagnostic interface 
    l2c_diag_show_data_line((unsigned int)(l2c) + 0x200000, 0, 0, 64);
    l2c_diag_show_tag((unsigned int)(l2c) + 0x80000, 0, 32, 32, 1);
    res = l2c_lookup(lookup_addr, 32, 32, l2c);
    if (res.valid) {
      printf("Hit on address: 0x%08X, valid: %d, dirty: %d, way: %d, lru: %d\n   tag_addr: 0x%08X, data_addr: 0x%08X", 
             lookup_addr, res.valid, res.dirty, res.way+1, res.lru, res.tag_addr, res.data_addr);
    } else {
      printf("No hit on address: 0x%08X\n", lookup_addr);
    }; /* */
    
    return 0;
  };
/* ******************************************************************************* */
