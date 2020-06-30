#include "ftlib.h"

int *lreg = (int *) IRQMPADR;

int pow2(int exp) {
  int temp = 0;
  if (exp < 0) {
    return 0;
  } else if(exp == 0) {
    return 1;  
  } else {
    return 2*pow2(exp - 1);
  }
}

int encode(int data) {
        int cbits;
        int tmp;
        tmp = (data & 1) ^ ((data >> 4) & 1) ^ ((data >> 6) & 1) ^ 
                ((data >> 7) & 1) ^ ((data >> 8) & 1) ^ ((data >> 9) & 1) ^
                ((data >> 11) & 1) ^ ((data >> 14) & 1) ^ ((data >> 17) & 1) ^
                ((data >> 18) & 1) ^ ((data >> 19) & 1) ^ ((data >> 21) & 1) ^
                ((data >> 26) & 1) ^ ((data >> 28) & 1) ^ ((data >> 29) & 1) ^
                ((data >> 31) & 1);
        cbits = tmp;
        tmp = (data & 1) ^ ((data >> 1) & 1) ^ ((data >> 2) & 1) ^ 
                ((data >> 4) & 1) ^ ((data >> 6) & 1) ^ ((data >> 8) & 1) ^
                ((data >> 10) & 1) ^ ((data >> 12) & 1) ^ ((data >> 16) & 1) ^
                ((data >> 17) & 1) ^ ((data >> 18) & 1) ^ ((data >> 20) & 1) ^
                ((data >> 22) & 1) ^ ((data >> 24) & 1) ^ ((data >> 26) & 1) ^ 
                ((data >> 28) & 1);
        cbits = cbits | (tmp << 1);
        tmp = (data & 1) ^ ((data >> 3) & 1) ^ ((data >> 4) & 1) ^ 
                ((data >> 7) & 1) ^ ((data >> 9) & 1) ^ ((data >> 10) & 1) ^
                ((data >> 13) & 1) ^ ((data >> 15) & 1) ^ ((data >> 16) & 1) ^
                ((data >> 19) & 1) ^ ((data >> 20) & 1) ^ ((data >> 23) & 1) ^
                ((data >> 25) & 1) ^ ((data >> 26) & 1) ^ ((data >> 29) & 1) ^ 
                ((data >> 31) & 1);
        tmp = (~tmp) & 1;
        cbits = cbits | (tmp << 2);
        tmp = (data & 1) ^ ((data >> 1) & 1) ^ ((data >> 5) & 1) ^ 
                ((data >> 6) & 1) ^ ((data >> 7) & 1) ^ ((data >> 11) & 1) ^
                ((data >> 12) & 1) ^ ((data >> 13) & 1) ^ ((data >> 16) & 1) ^
                ((data >> 17) & 1) ^ ((data >> 21) & 1) ^ ((data >> 22) & 1) ^
                ((data >> 23) & 1) ^ ((data >> 27) & 1) ^ ((data >> 28) & 1) ^ 
                ((data >> 29) & 1);
        tmp = (~tmp) & 1;
        cbits = cbits | (tmp << 3);
        tmp = ((data >> 2) & 1) ^ ((data >> 3) & 1) ^ ((data >> 4) & 1) ^ 
                ((data >> 5) & 1) ^ ((data >> 6) & 1) ^ ((data >> 7) & 1) ^
                ((data >> 14) & 1) ^ ((data >> 15) & 1) ^ ((data >> 18) & 1) ^
                ((data >> 19) & 1) ^ ((data >> 20) & 1) ^ ((data >> 21) & 1) ^
                ((data >> 22) & 1) ^ ((data >> 23) & 1) ^ ((data >> 30) & 1) ^ 
                ((data >> 31) & 1);
        cbits = cbits | (tmp << 4);
        tmp = ((data >> 8) & 1) ^ ((data >> 9) & 1) ^ ((data >> 10) & 1) ^ 
                ((data >> 11) & 1) ^ ((data >> 12) & 1) ^ ((data >> 13) & 1) ^
                ((data >> 14) & 1) ^ ((data >> 15) & 1) ^ ((data >> 24) & 1) ^
                ((data >> 25) & 1) ^ ((data >> 26) & 1) ^ ((data >> 27) & 1) ^
                ((data >> 28) & 1) ^ ((data >> 29) & 1) ^ ((data >> 30) & 1) ^ 
                ((data >> 31) & 1);
        cbits = cbits | (tmp << 5);
        tmp = (data & 1) ^ ((data >> 1) & 1) ^ ((data >> 2) & 1) ^ 
                ((data >> 3) & 1) ^ ((data >> 4) & 1) ^ ((data >> 5) & 1) ^
                ((data >> 6) & 1) ^ ((data >> 7) & 1) ^ ((data >> 24) & 1) ^
                ((data >> 25) & 1) ^ ((data >> 26) & 1) ^ ((data >> 27) & 1) ^
                ((data >> 28) & 1) ^ ((data >> 29) & 1) ^ ((data >> 30) & 1) ^ 
                ((data >> 31) & 1);
        cbits = cbits | (tmp << 6);
        
        return cbits;
}


int scramble(int cbits, int bit, int mode) {
  int temp;
  if(mode == 1 ) {
    //multiple error
    switch(bit) {
    case 0 : temp = cbits ^ 3; break;
    case 1 : temp = cbits ^ 5; break;
    case 2 : temp = cbits ^ 6; break;
    case 3 : temp = cbits ^ 7; break;
    case 4 : temp = cbits ^ 9; break;
    case 5 : temp = cbits ^ 10; break; 
    case 6 : temp = cbits ^ 12; break;
    case 7 : temp = cbits ^ 13; break;
    case 8 : temp = cbits ^ 15; break;
    case 9 : temp = cbits ^ 17; break;
    case 10 : temp = cbits ^ 18; break;
    case 11 : temp = cbits ^ 20; break;
    case 12 : temp = cbits ^ 23; break;
    case 13 : temp = cbits ^ 24; break;
    case 14 : temp = cbits ^ 27; break;
    case 15 : temp = cbits ^ 29; break;
    case 16 : temp = cbits ^ 30; break;
    case 17 : temp = cbits ^ 31; break;
    case 18 : temp = cbits ^ 33; break;
    case 19 : temp = cbits ^ 34; break;
    case 20 : temp = cbits ^ 36; break;
    case 21 : temp = cbits ^ 39; break;
    case 22 : temp = cbits ^ 40; break;
    case 23 : temp = cbits ^ 43; break;
    case 24 : temp = cbits ^ 45; break;
    case 25 : temp = cbits ^ 46; break;
    case 26 : temp = cbits ^ 47; break;
    case 27 : temp = cbits ^ 48; break;
    case 28 : temp = cbits ^ 50; break;
    case 29 : temp = cbits ^ 51; break;
    case 30 : temp = cbits ^ 53; break;
    case 31 : temp = cbits ^ 54; break;
    case 32 : temp = cbits ^ 55; break;
    case 33 : temp = cbits ^ 56; break;
    case 34 : temp = cbits ^ 57; break;
    case 35 : temp = cbits ^ 58; break;
    case 36 : temp = cbits ^ 59; break;
    case 37 : temp = cbits ^ 60; break;
    case 38 : temp = cbits ^ 61; break;
    case 39 : temp = cbits ^ 62; break;
    case 40 : temp = cbits ^ 63; break;
    case 41 : temp = cbits ^ 65; break;
    case 42 : temp = cbits ^ 66; break;
    case 43 : temp = cbits ^ 67; break;
    case 44 : temp = cbits ^ 68; break;
    case 45 : temp = cbits ^ 69; break;
    case 46 : temp = cbits ^ 70; break;
    case 47 : temp = cbits ^ 71; break;
    case 48 : temp = cbits ^ 72; break;
    case 49 : temp = cbits ^ 73; break;
    case 50 : temp = cbits ^ 75; break;
    case 51 : temp = cbits ^ 76; break;
    case 52 : temp = cbits ^ 77; break;
    case 53 : temp = cbits ^ 78; break;
    case 54 : temp = cbits ^ 80; break;
    case 55 : temp = cbits ^ 81; break;
    case 56 : temp = cbits ^ 83; break;
    case 57 : temp = cbits ^ 85; break;
    case 58 : temp = cbits ^ 86; break;
    case 59 : temp = cbits ^ 89; break;
    case 60 : temp = cbits ^ 90; break;
    case 61 : temp = cbits ^ 92; break;
    case 62 : temp = cbits ^ 94; break;
    case 63 : temp = cbits ^ 95; break;
    case 64 : temp = cbits ^ 96; break;
    case 65 : temp = cbits ^ 97; break;
    case 66 : temp = cbits ^ 99; break;
    case 67 : temp = cbits ^ 101; break; 
    case 68 : temp = cbits ^ 102; break; 
    case 69 : temp = cbits ^ 105; break;
    case 70 : temp = cbits ^ 106; break;
    case 71 : temp = cbits ^ 108; break;
    case 72 : temp = cbits ^ 110; break;
    case 73 : temp = cbits ^ 111; break;
    case 74 : temp = cbits ^ 113; break;
    case 75 : temp = cbits ^ 114; break;
    case 76 : temp = cbits ^ 115; break;
    case 77 : temp = cbits ^ 116; break;
    case 78 : temp = cbits ^ 118; break;
    case 79 : temp = cbits ^ 119; break;
    case 80 : temp = cbits ^ 120; break;
    case 81 : temp = cbits ^ 121; break;
    case 82 : temp = cbits ^ 122; break;
    case 83 : temp = cbits ^ 123; break;
    case 84 : temp = cbits ^ 124; break;
    case 85 : temp = cbits ^ 125; break;
    case 86 : temp = cbits ^ 126; break;
    case 87 : temp = cbits ^ 127; break;
    default : break;
    }
  } else {
    //single error
    switch(bit) {
    case 0 : temp = cbits ^ 0x4F; break;
    case 1 : temp = cbits ^ 0x4A; break;
    case 2 : temp = cbits ^ 0x52; break;
    case 3 : temp = cbits ^ 0x54; break;
    case 4 : temp = cbits ^ 0x57; break;
    case 5 : temp = cbits ^ 0x58; break;
    case 6 : temp = cbits ^ 0x5B; break;
    case 7 : temp = cbits ^ 0x5D; break;
    case 8 : temp = cbits ^ 0x23; break;
    case 9 : temp = cbits ^ 0x25; break;
    case 10 : temp = cbits ^ 0x26; break; 
    case 11 : temp = cbits ^ 0x29; break;
    case 12 : temp = cbits ^ 0x2A; break;
    case 13 : temp = cbits ^ 0x2C; break;
    case 14 : temp = cbits ^ 0x31; break;
    case 15 : temp = cbits ^ 0x34; break;
    case 16 : temp = cbits ^ 0x0E; break;
    case 17 : temp = cbits ^ 0x0B; break; 
    case 18 : temp = cbits ^ 0x13; break;
    case 19 : temp = cbits ^ 0x15; break;
    case 20 : temp = cbits ^ 0x16; break;
    case 21 : temp = cbits ^ 0x19; break;
    case 22 : temp = cbits ^ 0x1A; break;
    case 23 : temp = cbits ^ 0x1C; break;
    case 24 : temp = cbits ^ 0x62; break;
    case 25 : temp = cbits ^ 0x64; break;
    case 26 : temp = cbits ^ 0x67; break;
    case 27 : temp = cbits ^ 0x68; break;
    case 28 : temp = cbits ^ 0x6B; break;
    case 29 : temp = cbits ^ 0x6D; break;
    case 30 : temp = cbits ^ 0x70; break;
    case 31 : temp = cbits ^ 0x75; break;
    //Error in checkbits
    case 32 : temp = cbits ^ 0x01; break;
    case 33 : temp = cbits ^ 0x02; break; 
    case 34 : temp = cbits ^ 0x04; break;
    case 35 : temp = cbits ^ 0x08; break;
    case 36 : temp = cbits ^ 0x10; break;
    case 37 : temp = cbits ^ 0x20; break;
    case 38 : temp = cbits ^ 0x40; break;  
    default : break;
    }
  }
  return temp;
}

/*
int cache_disable(void) {
  volatile int temp;
  volatile int temp2;
  volatile int temp3;
  temp2 = 0;
  asm("lda [%1]2, %0"
      : "=r"(temp)
      : "r"(temp2)
     );
    
  temp3 = 0xa;
  asm("sta %0, [%1]2 "
      : "=r"(temp3) 
      : "r"(temp2)
     );
  return temp;
}

*/
void cache_reset(int cctrl) {
  volatile int temp = 0;
  asm(" sta %0, [%1]2 "
      : "=r"(cctrl)
      : "r"(temp)
       
     );
}

void enable_irq (int irq) 
{
  lreg[0x8/4] = ~(1 << irq);    // clear bit in force reqister
  lreg[0xC/4] = (1 << irq);	// clear any pending irq
  lreg[0x40/4] |= (1 << irq);	// unmasks irq
}

void disable_irq (int irq) { lreg[0x40/4] &= ~(1 << irq); }	// mask irq

void clear_irq (int irq) { lreg[0xC/4] = (1 << irq); }

void force_irq (int irq) { lreg[0x8/4] = (1 << irq); } //force irq

int pend_irq (int irq) { return (lreg[0x4/4] & (1 << irq)); }

void clear_all_irq () { 
	lreg[0x0/4] = 0; lreg[0x4/4] = 0;
	lreg[0x8/4] = 0; lreg[0xC/4] = 0;
}

void restore_trap(ex_num, tbr, old)
unsigned char	ex_num;
unsigned int	tbr, *old;
{
	unsigned int *t_add, i;
		
	t_add = (unsigned int *) ((tbr & ~0x0fff) | ((unsigned int) ex_num << 4));
	for (i=0; i<4; i++) { t_add[i] = old[i];}
	asm("flush");
}

void exceptionHandler(
	unsigned char ex_num,
	void (*ex_add)(void),
	unsigned int tbr,
	unsigned int *old
)
{
	unsigned int *t_add, i, *addr;
	
	addr = (int *) ex_add;
	t_add = (unsigned int *) ((tbr & ~0x0fff) | ((unsigned int) ex_num << 4));
	for (i=0; i<4; i++) { old[i] = t_add[i];}
	*t_add = 0xA010000F;	/* or %o7,%g0,%l0 */
	t_add++;
	*t_add = (0x40000000 | (((unsigned int) (addr-t_add))&0x3fffffff ));	/* call _ex_add */
	t_add++;
	*t_add = 0x9E100010;	/* or %l0,%g0,%o7 */
	asm("flush");
}

asm (
"	.globl rdtbr;"
"rdtbr:  retl;"
"	mov %tbr, %o0;"
"	.globl wrtbr;"
"wrtbr:  mov %o0, %tbr;"
"	nop;"
"	retl;"
"	nop;"
);
