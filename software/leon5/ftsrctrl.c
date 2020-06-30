/*******************************************************************************
 *Testsequence for the Fault tolerant version of the PROM/SRAM controller
 *******************************************************************************/
#include "ftlib.h"
#include "testmod.h"
#include "ftmctrl.h"

#define DISABLE    0
#define CBSE       0x21          
#define SRAMEN     0x200
#define PROMEN     0x100
#define RB         0x400
#define WB         0x800
#define CLEAR      0xFF000

ldnc(addr) int addr; { asm(" lda	[%o0] 0x1, %o0 "); }

int ftsrctrl_test(int sramaddr, int apbaddr, int ahbstataddr, int edacen, int ahbstaten) {
  int temp[2];
  int i, mcfg3;
  int cachectrl;
  
  volatile int psram[2], tmp;
  volatile int *pconf = (int *) (apbaddr + 8);
  volatile int *ahbstat = (int *) ahbstataddr;

  
  if (edacen == 1) {
    report_device(0x01051000);
    //Enable sram edac and wb
    //single error on SRAM
    mcfg3 = pconf[0];
    tmp = mcfg3 | WB | cbgen(0x12345678); 
    pconf[0] = tmp;
    psram[0] = 0x02345678;
    pconf[0] = mcfg3;
    //asm("flush");
    if( ldnc((int)&psram[0]) != 0x12345678 ) {
      //edac or write diagnostics error
      fail(1);
    }
    
    if (ahbstaten == 1) {
      if( (ahbstat[0] & 0x3FF) != 0x302) fail(3);
      if( ahbstat[1] != (int)(&psram[0])) fail(4);
      ahbstat[0] = 0;
      if (((ahbstat[0] >> 8) & 0x3) != 0) fail(5);
    }
    
  }
  asm ("flush;");
  return 0;
}



