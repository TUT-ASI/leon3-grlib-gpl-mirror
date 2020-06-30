/* Test for fault-tolerant ddr2spa combined with status register/scrubber */
#include <string.h>
#include "testmod.h"

static inline unsigned long rf(unsigned long addr)
{
  int tmp;
  asm volatile(" lda [%1] 1, %0 "
	       : "=r"(tmp)
	       : "r"(addr)
	       );
  return tmp;
}

static inline unsigned long long rfd(unsigned long addr)
{
  unsigned long long tmp;
  asm volatile(" ldda [%1] 1, %0 "
	       : "=r"(tmp)
	       : "r"(addr)
	       );
  return tmp;
}

static inline void wf(unsigned long addr, unsigned long data)
{
  asm volatile(" st %0, [%1]"
	       :
	       : "r"(data), "r"(addr));
}

static inline void wfd(unsigned long addr, unsigned long long data)
{
  asm volatile(" std %0, [%1]"
	       :
	       : "r"(data), "r"(addr));
}

#define XOR(x,y) (((x) && !(y)) || (!(x) && (y)))

static unsigned long cb_to_phys(unsigned long cb, int dwidth, int code)
{
  int a0,a1,b0,b1,c0,c1,d0,d1;
  unsigned long r;
  a0 = cb & 15;
  a1 = (cb >> 4) & 15;
  b0 = (cb >> 8) & 15;
  b1 = (cb >> 12) & 15;
  c0 = (cb >> 16) & 15;
  c1 = (cb >> 20) & 15;
  d0 = (cb >> 24) & 15;
  d1 = (cb >> 28) & 15;  
  r=0;
  if (dwidth==2) {
    r |= b0;
    r |= a0 << 4;
    r |= d0 << (code ? 16 : 8);
    r |= c0 << (code ? 20 : 12); 
    r |= b1 << (code ? 8 : 16); 
    r |= a1 << (code ? 12 : 20);
    r |= d1 << 24;
    r |= c1 << 28;
  } else if (dwidth == 1) {
    r |= c0 << (code ? 16 : 0);
    r |= b1 << 4;
    r |= d0 << (code ? 24 : 8);
    r |= a1 << 12;
    r |= a0 << (code ? 0 : 16);
    r |= d1 << 20;
    r |= b0 << (code ? 8 : 24);
    r |= c1 << 28;
  } else {
    r |= d0 << (code ? 28 : 0);
    r |= c1 << (code ? 24 : 4);
    r |= b0 << 8;
    r |= a1 << 12;
    r |= c0 << 16;
    r |= d1 << 20;
    r |= a0 << (code ? 4 : 24);
    r |= b1 << (code ? 0 : 28);
  }
  return r;
}

static unsigned long phys_to_cb(unsigned long phys, int dwidth, int code)
{
  int a0,a1,b0,b1,c0,c1,d0,d1;
  unsigned long r;
  if (dwidth == 2) {
    a0 = phys >> 4;
    a1 = phys >> (code ? 12 : 20);
    b0 = phys;
    b1 = phys >> (code ? 8 : 16);
    c0 = phys >> (code ? 20 : 12);
    c1 = phys >> 28;
    d0 = phys >> (code ? 16 : 8);
    d1 = phys >> 24;
  } else if (dwidth == 1) {
    a0 = phys >> (code ? 0 : 16);
    a1 = phys >> 12;
    b0 = phys >> (code ? 8 : 24);
    b1 = phys >> 4;
    c0 = phys >> (code ? 16 : 0);
    c1 = phys >> 28;
    d0 = phys >> (code ? 24 : 8);
    d1 = phys >> 20;
  } else {
    a0 = phys >> (code ? 4 : 24);
    a1 = phys >> 12;
    b0 = phys >> 8;
    b1 = phys >> (code ? 0 : 28);
    c0 = phys >> 16;
    c1 = phys >> (code ? 24 : 4);
    d0 = phys >> (code ? 28 : 0);
    d1 = phys >> 20;
  }
  a0 &= 15; a1 &= 15; b0 &= 15; b1 &= 15;
  c0 &= 15; c1 &= 15; d0 &= 15; d1 &= 15;
  r = ((d1 << 28) | (d0 << 24) | (c1 << 20) | (c0 << 16) |
       (b1 << 12) | (b0 << 8) | (a1 << 4) | a0);
  return r;  
}

static void data_to_phys(unsigned long data[2], unsigned long phys[2], int dwidth)
{
  unsigned long i,j,k,l;
  int c;
  if (dwidth==2) {
    phys[0] = data[0];
    phys[1] = data[1];
  } else {
    k=l=0;
    i=data[0]; j=data[1];
    if (dwidth==1) {
      for (c=0; c<2; c++) {
	k = l;
	l = (i & 0xF0000000) | ((j >> 4) & 0x0F000000) |
	  ((i >> 4) & 0x00F00000) | ((j >> 8) & 0x000F0000) |
	  ((i >> 8) & 0x0000F000) | ((j >> 12) & 0x00000F00) |
	  ((i >> 12) & 0x000000F0) | ((j >> 16) & 0x0000000F);
	i <<= 16;
	j <<= 16;
      }
      phys[0] = k;
      phys[1] = l;
    } else {
      for (c=0; c<2; c++) {
	k = l;
	l = (i & 0xF0000000) | ((i << 12) & 0x0F000000) |
	  ((j >> 8) & 0x00F00000) | ((j << 4) & 0x000F0000) |
	  ((i >> 12) & 0x0000F000) | (i & 0x00000F00) |
	  ((j >> 20) & 0x000000F0) | ((j >> 8) & 0x0000000F);
	i <<= 8;
	j <<= 8;      
      }
    }
    phys[0] = k;
    phys[1] = l;
  }
}

static void phys_to_data(unsigned long phys[2], unsigned long data[2], int dwidth)
{
  unsigned long i,j,k,l;
  int c;
  if (dwidth == 2) {
    data[0] = phys[0];
    data[1] = phys[1];
  } else {
    k=l=0;
    i=phys[0]; j=phys[1];
    if (dwidth == 1) {
      for (c=0; c<2; c++) {
	k = l;
	l = ((i & 0xF0000000) | ((i << 4) & 0x0F000000) |
	     ((i << 8) & 0x00F00000) | ((i << 12) & 0x000F0000) |
	     ((j >> 16) & 0x0000F000) | ((j >> 12) & 0x00000F00) | 
	     ((j >> 8) & 0x000000F0) | ((j >> 4) & 0x0000000F));
	i <<= 4;
	j <<= 4;
      }
    } else {
      for (c=0; c<2; c++) {
	k = l;
	l = ((i & 0xF0000000) | ((i << 12) & 0x0F000000) |
	     ((j >> 8) & 0x00F00000) | ((j << 4) & 0x000F0000) | 
	     ((i >> 12) & 0x0000F000) | (i & 0x00000F00) |
	     ((j >> 20) & 0x000000F0) | ((j >> 8) & 0x0000000F) );
	i <<= 8;
	j <<= 8;
      }
    }
    data[0] = k;
    data[1] = l;
  }
}

/* In some critical regions of the tests we can not have accesses to the
 * stack. To make sure of this, they are implemented in inline assembly. */

static unsigned long cstest_main(volatile long *databuf, volatile unsigned long *reg, unsigned long ftregval, unsigned long oldregval, volatile unsigned long *val2)
{
  unsigned long r1,r2;
  unsigned long v,tmp1;
  /* 1) write ftregval to FT config register, 
   * 2) write 0x01234567 to databuf[0],databuf[2]
   * 3) read out check bits for databuf[0-1] and databuf[2-3] through diag 
   *    access
   * 4) write oldregval to FT config register
   * 5) write 0x01234567 to databuf[0,2] to restore checkbits
   * 6) return checkbits for databuf[0-1] and store CB for databuf[2-3] in 
   *    *val2     **/
  v = 0x01234567;
  asm volatile(" st %3, [%4+0x20]\n"
               " st %5, [%6]\n"
               " st %5, [%6+8]\n"
               " st %6, [%4+0x24]\n"
               " ld [%4+0x28], %0\n"
               " add %6, 8, %2\n"
               " st %2, [%4+0x24]\n"
               " ld [%4+0x28], %1\n"
               " st %7, [%4+0x20]"
               : "=&r"(r1),"=&r"(r2),"=&r"(tmp1)
               : "r"(ftregval),"r"(reg),"r"(v),"r"(databuf),"r"(oldregval));
  /*  reg[8] = ftregval;
  databuf[0] = 0x01234567;
  databuf[2] = 0x01234567;
  reg[9] = (unsigned long)databuf;
  r1 = reg[10];
  reg[9] = (unsigned long)(databuf+2);
  r2 = reg[10];
  reg[8] = oldregval; */
  *val2 = r2;
  databuf[0] = 0x01234567;
  databuf[2] = 0x01234567;
  return r1;
}

static unsigned long wmuxtest_main(volatile long *databuf, volatile unsigned long *reg, 
                                   unsigned long long dataval, unsigned long ftregval,
                                   unsigned long oldregval, long long *dataout)
{
  unsigned long r1,r2[2],tmp;

  /* 1) write ftregval to FT config register
   * 2) write dword dataval to databuf
   * 3) diagnostic read checkbits and data
   * 4) restore FT config register
   * 5) re-write dataval
   * 6) Store data in dataout[0-1] and return checkbits
   */
  asm volatile (" st  %4,           [%5+0x20]\n"
                " std %6,           [%7]\n"
                " st  %7,           [%5+0x24]\n"
                " ld  [%5+0x28],    %0\n"
                " ld  [%5+0x2C],    %1\n"
                " add %7,        4, %3\n"
                " st  %3,           [%5+0x24]\n"
                " ld  [%5+0x2C],    %2\n"
                " st  %8,           [%5+0x20]\n"
                : "=&r"(r1), "=&r"(r2[0]), "=&r"(r2[1]), "=&r"(tmp)
                : "r"(ftregval),"r"(reg),"r"(dataval),"r"(databuf),"r"(oldregval));
  wfd((unsigned long)databuf,dataval);
  memcpy(dataout,&r2,8);
  return r1;
}

/* Core part of read mux test */
static void rmuxtest_main(volatile long *databuf, volatile unsigned long *reg,
                          unsigned long long dataval, unsigned long cbval,
                          unsigned long ftregval, unsigned long oldregval,
                          unsigned long long *dataout)
{
  unsigned long long r;
  wfd((unsigned long)databuf, dataval);
  asm volatile (" st   %1,         [%2+0x24]\n"
                " st   %3,         [%2+0x28]\n"
                " st   %4,         [%2+0x20]\n"
                " ldda [%1] 1,     %0\n"
                " st   %5,         [%2+0x20]\n"
                : "=&r"(r)
                : "r"(databuf),"r"(reg),"r"(cbval),"r"(ftregval),"r"(oldregval));
  /*  reg[9] = (unsigned long)databuf;
  reg[10] = cbval;
  reg[8] = ftregval;
  r = rfd((unsigned long)databuf);
  reg[8] = oldregval; */
  wfd((unsigned long)databuf, r);
  *dataout = r;
}

  
/* Test for the FT DDR2SPA front-end 
 * 
 * The test routine requires the full (simulated) checkbit memory width to be 
 * available. 
 *
 * Some parts of the test are run with EDAC enabled with code A. If the systest 
 * is being run from the same memory, it must have valid code A checkbits, 
 * otherwise code fetching during the test can cause EDAC errors and crash 
 * the test program. For the code boundary test to work, the memory must also 
 * have all systest code located below the test data buffer (databuf). */

void ftfe_test(long *databuf, volatile unsigned long *reg, volatile unsigned long *statusreg)
{
  long long x,y;
  unsigned long l,m;
  unsigned long ca,cb,q,q2;
  int i,j,k;
  unsigned long phys[2],data[2];
  volatile long *p;
  unsigned long ftcorig;
  int dwidth;
  /* Mapping from nibble error location in data/checkbits to bit position in errloc vector */
  static const int exp_errloc[3][24] = {
    /* 16-bit, 2-bit per nibble */
    { 0, 2, 4, 6, 1, 3, 5, 7, 
      0, 2, 4, 6, 1, 3, 5, 7, 
      10, 9, 8, 11, 10, 9, 8, 11 },
    /* 32-bit, 1-bit per nibble */
    { 0, 1, 2, 3, 4, 5, 6, 7, 
      0, 1, 2, 3, 4, 5, 6, 7, 
      10, 9, 11, 8, 8, 11, 9, 10 },
    /* 64-bit, 1-bit per byte */
    { 0, 0, 1, 1, 2, 2, 3, 3, 
      4, 4, 5, 5, 6, 6, 7, 7, 
      8, 10, 8, 10, 9, 11, 9, 11 }
  };
  /* Data to write as checkbits with code A enabled 
   * corresponding to topmost DDR2 lane */
  static const unsigned long topdata[3] = { 0x20014003, 0x30400201, 0x30401020 };

  /* puts("Hej"); */

  /* Make sure buffer is aligned to 64-bits */
  databuf = (long *)((((unsigned long)databuf) + 7) & (~7));

  /* ---------------------------------------------------
   * Nibble error test */

  report_subtest(1);

  /* Clear status register */
  *statusreg = 0;

  /* Disable EDAC */
  ftcorig = reg[8];                 /* Get orig value of FTC register */
  dwidth = ((ftcorig >> 16) & 3)-1; /* Extract width */
  ftcorig &= 0xFF;                  /* Mask reserved bits */

  reg[8] = 0x00000000;

  /* Init data buffer */
  wf((long)databuf,   0x01234567);
  wf((long)(databuf+1), 0x89ABCDEF);
  wf((long)(databuf+2),   0x01234567);
  wf((long)(databuf+3),   0x089ABCDEF);
  
  /* Confirm data using diagnostic access */
  l = (unsigned long)databuf;
  reg[9] = l;
  if (reg[11] != 0x01234567) 
    fail(1);
  reg[9] = l+4;
  if (reg[11] != 0x89ABCDEF) 
    fail(2);
  
  /* Read-out checkbits */
  ca = reg[10];

  report_subtest(2);
  /* For each nibble:
   * - inject error using diag registers
   * - check that error exists using memory read (if error in data bits)
   * - perform diag read and check the errloc status field
   * - check that status register has not triggered
   * - enable EDAC
   * - check that error is corrected on read
   * - check that status register has triggered
   * - disable EDAC and clear status reg */

  j = 11;
  for (i=0; i<24; i++) {
    /* inject error using diag registers */
    if (i==0) l+=4;
    if (i==8) l-=4;
    if (i==16)  { j--; l+=4; }
    reg[9] = l;
    q = reg[j];
    if (j == 10 && q != ca) fail(15);
    k = 6 << ((i&7)<<2);
    q ^= k;
    reg[j] = q;
    /* check that error exists using memory read (if error in data bits) */
    q = rf(l);
    if (i & 8) q ^= 0x01234567;
    else q ^= 0x89ABCDEF;
    if (i < 16 && q != k)
      fail(3);
    /* read from diag reg to update errloc */
    q = reg[11];
    /* Check errloc vector */
    q = reg[8];
    if ((q >> 20) != (1 << exp_errloc[dwidth][i]))
      fail(11);
    /* check that status register has not triggered */
    q = *statusreg;
    if ((q & 0x300) != 0) 
      fail(4);
    /* enable EDAC */
    reg[8] = 1;
    /* check that error is corrected on read */
    q = rf(l);
    if (i & 8) q ^= 0x01234567;
    else q ^= 0x89ABCDEF;
    if (q != 0) 
      fail(5);
    /* check that status register has triggered */
    q = *statusreg;
    if ((q & 0x300) != 0x300)
      fail(6);
    if ((statusreg[1] & 0xfffffff0) != (l & 0xfffffff0))
      fail(7);
    /* disable EDAC and clear status reg */
    *statusreg = 0;
    reg[8] = 0;
    /* Restore data */
    wf(l,(i&8) ? 0x01234567 : 0x89ABCDEF);
  }

  /* -------------------------------------------
   * Code switching and boundary reg test */
  report_subtest(3);

  /* See what the checkbits are in code B */
  cb = cstest_main(databuf, reg, 0x00000002, 0, &q2);
  /* printf("ca=%08x, cb=%08x\n",ca,cb); */
  if ((cb & 0xFFFF) == (ca & 0xFFFF)) fail(14);
  if ((cb >> 16 != ca >> 16)) fail(13);

  /* Test the code boundary feature */
  for (i=-2; i<4; i++) {
    /* Set boundary */
    l = (long)databuf;
    l += i*8;
    /* printf("Setting boundary reg to %08x, databuf=%08x, i=%d\n",l,(long)databuf,i); */
    reg[12] = l;
    for (j=0; j<2; j++) {
      /* Set code A/B, edac disabled, boundary enabled */
      /* Write data to databuf[0] and databuf[2] to regenerate checkbits */
      /* Read out checksum for databuf[0,1] and databuf[2,3] */
      q = cstest_main(databuf, reg, 4 | (j<<1), 0, &q2);
      l = XOR(i>0,j!=0) ? cb : ca;
      if (q != l) fail(16+j*2);
      l = XOR(i>1,j!=0) ? cb : ca;
      if (q2 != l) fail(17+j*2);
    }
    /* Check that boundary hasn't changed */
    q = reg[12];
    if (q != ((long)&databuf[i*2])) fail(20);
  }

  /* Test boundary shifting */
  report_subtest(4);
  for (i=0; i<5; i++) {
    reg[12] = ((long)databuf)-8+8*i;
    q = cstest_main(databuf, reg, 8|4, 0, &q2);
    l = (i > 0) ? cb : ca;
    if (q != l) fail(22);
    if (q2 != l) fail(23);
    q = reg[12];
    if (i < 1) l=(long)databuf-8; else if (i > 3) l = (long)databuf+24; else l = (long)databuf+16;
    if (q != l) fail(21);
  }

  /* ----------------------------------
   * Data mux test */

  report_subtest(5);

  if (dwidth==2) 
    x = 0x0123456789ABCDEFLL;
  else if (dwidth==1)
    x = 0x02468ACE13579BDFLL;
  else 
    x = 0x048C159D26AE37BFLL;

  /* Test write-direction mux */
  for (i=0; i<6; i++) {
    /* To avoid breaking code fetches while we're looping through the
     * mux settings, we need to enable EDAC and mask out correctable errors. */
    m = wmuxtest_main(databuf, reg, x, ((i<<5)|16|1), 0, &y);
    /* Data should be unchanged */
    if (x != y) fail(24);
    /* Look at checkbit */
    l = cb_to_phys(m,dwidth,0);
    if (i == 0) j=l; /* Store ref */
    k = j & 0xFFFF;
    switch (i) {
    case 0: k=j; break;
    case 1: k|=0xCDEF0000; break;
    case 2: k|=0x89AB0000; break;
    case 3: k|=0x45670000; break;
    case 4: k|=0x01230000; break;
    default: k|=k<<16; break;
    }
    if (l != k) fail(25);
  }

  /* Test read-direction mux */

  /* This is a bit tricky, since we must have EDAC code A enabled at the 
   * same time to avoid code fetching errors. Just simply looping through 
   * the settings and reading the buffer won't work since the EDAC will 
   * detect that the part has changed and correct the error. 
   *
   * The solution used is to damage each part in turn, place the correct
   * data for the part in the checkbit upper half, and then perform a 
   * read. If the mux is working, the EDAC will see correct data but with 
   * an error in the upper checkbit half (which contains a copy of the 
   * muxed-in data part). This error can be detected and corrected in 
   * code A. If the muxing is not working we will get incorrect data or, 
   * more likely, an error response.*/
  report_subtest(6);

  /* Figure out correct checkbits for value */
  wfd((long)databuf, x);
  reg[9] = (long)databuf;
  ca = reg[10];

  for (i=1; i<6; i++) {
    /* Calculate data to write to clear part (i-1) and place it's data
     * in top checkbits */
    /* Convert to physical {m, phys[0], phys[1]} */
    data_to_phys((unsigned long *)&x,phys,dwidth);
    /* Clear part (i-1) and place it's data in top half of m */
    m = cb_to_phys(ca,dwidth,0);
    switch (i) {
    case 1: l=phys[1]&0xFFFF; phys[1]&=0xFFFF0000; break;
    case 2: l=phys[1] >> 16;  phys[1]&=0x0000FFFF; break;
    case 3: l=phys[0]&0xFFFF; phys[0]&=0xFFFF0000; break;
    case 4: l=phys[0] >> 16;  phys[0]&=0x0000FFFF; break;
    default:
    case 5: l=m&0xFFFF;       m&=0xFFFF0000;       break;
    }
    m = (m & 0x0000FFFF) | (l << 16);
    /* Convert back to diag/logical bit order */
    phys_to_data(phys,(unsigned long *)&y,dwidth);
    q = phys_to_cb(m,dwidth,0);
    /* Perform test */
    rmuxtest_main(databuf,reg,y,q,((i<<5)|16|1),0,&y);
    /* Check that data was corrected */
    if (x != y) fail(26);
  }
  /* ----------------------------------------
   * Done */

  /* Restore EDAC setting and clear buffer */
  reg[8] = ftcorig;
  wfd((long)databuf, x);

}

void ftddr2spa_test(long *ddr2buf, volatile unsigned long *ddr2reg, volatile unsigned long *statusreg) {
  report_device(0x0102E000);
  ftfe_test(ddr2buf,ddr2reg,statusreg);
}

void ftfe_sdctrl_test(long *buf, volatile unsigned long *sdreg, volatile unsigned long *statusreg) 
{
  report_device(0x0104C000);
  ftfe_test(buf,sdreg,statusreg);
}
