/**********************************************************************/
/*  This file is a part of the GRFPU IP core testbench                */
/*  Copyright (C) 2004-2008  Gaisler Research AB                      */
/*  Copyright (C) 2008-2009  Aeroflex Gaisler AB                      */
/*  ALL RIGHTS RESERVED                                               */
/*                                                                    */
/**********************************************************************/


#include "testmod.h" 

#define FTT_CEXC 0x1c01f
#define FTT 0x1c000
#define IEEE754EXC (1 << 14)
#define UNFINEXC   (1 << 15)
#define NX 1
#define DZ 2
#define UF 4
#define OF 8
#define NV 16
#define EQ 0
#define LT 1
#define GT 2
#define UN 3

typedef unsigned long long uint64;
extern void grfpu_fdivd(uint64 *a, uint64 *b, uint64 *c);
extern unsigned int grfpu_fdivs(unsigned int a, unsigned int b, uint64 *scratch);
extern void grfpu_ttrap();
extern void divident(uint64 *a);
extern void divromtst(uint64 *a, uint64 *b);
extern volatile unsigned int fsr1[16], tfsr[16], grfpufq[16*4];
extern unsigned int grfpu_fitos(int a, uint64 *scratch);
extern uint64 grfpu_fitod(int a, uint64 *scratch);
extern unsigned int grfpu_fdtoi(uint64 a, uint64 *scratch);
extern unsigned int grfpu_fstoi(unsigned int a, uint64 *scratch);
extern unsigned int grfpu_fdtos(uint64 a, uint64 *scratch);
extern uint64 grfpu_fstod(unsigned int a, uint64 *scratch);
extern int grfpu_fcmpd(uint64 a, uint64 b, uint64 *scratch);
extern int grfpu_fcmped(uint64 a, uint64 b, uint64 *scratch);
extern uint64 grfpu_fsubd(uint64 a, uint64 b, uint64 *scratch);
extern void grfpc_dpdep_tst(uint64 *a);
extern void grfpc_spdep_tst(unsigned int *a);
extern void grfpc_spdpdep_tst(uint64 *a);
extern void grfpc_spdpdep_tst2(uint64 *a);
extern void initfpreg();
extern int grfpc_edac_test();
extern int test_pl1(uint64 *scratch);

struct dp3_type {
  uint64 op1;
  uint64 op2;
  uint64 res;
};


struct sp3_type {
  float op1;
  float op2;
  float res;
};

extern unsigned int fptrap;

/* declared in grfpu_test.c */
extern struct dp3_type faddd_tv[16];
extern struct dp3_type fmuld_tv[11];
extern unsigned int divisor[256];
extern unsigned int divres[512];
extern unsigned int sqrtres[256];



int grfpu_test5(int densupp)
{
        uint64 denorm = 0x0000000000010000LL;
        uint64 nzero = 0x8000000000000000LL;
        uint64 inf =  0xfff0000000000000LL;
        uint64 ninf = 0xfff0000000000000LL;
        uint64 pinf = 0x7ff0000000000000LL;
        uint64 qnan = 0x7ff8000000000000LL;
        unsigned int qnan_sp = 0x7fc00000;
        uint64 snan = 0x7ff4000000000000LL;
        uint64 qsnan = 0x7fffe00000000000LL;
        unsigned long int qsnan_sp = 0x7fff0000;
        unsigned int fsr = 0;
        uint64 z = 0;
        unsigned int fl = 0;
        double dbl = 0;
        uint64 dpres = 0xbff8000000000000LL;
        uint64 spdpres = 0x3fefdff00ffc484aLL; 

  int i;
  uint64 x, y;
  int cpu;

  uint64 a, b, c;
  uint64 zero, pzero;

  uint64 scratch[2];

  unsigned int *unfaddr, unfinst, tmp;
  unsigned int *t_add;

  cpu = get_pid();

  x = 0x3100a4068f346c9bLL;
  y = 0; zero = 0; pzero = 0;

  /* install FP trap handler */
  t_add = (unsigned int *) ((get_tbr() & ~0x0fff) | 0x80);
  *t_add = 0xA010000F;	/* or %o7,%g0,%l0 */
  t_add++;
  *t_add = (0x40000000 | (((unsigned int) (&fptrap-t_add)) ));	/* call fptrap */
  t_add++;
  *t_add = 0x9E100010;	/* or %l0,%g0,%o7 */  


  initfpreg();

  /* FITOS, FITOD */
  set_fsr(0x0f800000); tfsr[cpu] = 0;
  if ((grfpu_fitod(0,&scratch) != 0x0) || (tfsr[cpu] != 0))  fail((densupp<<6)+11);
  if ((grfpu_fitod(-6,&scratch) != 0xc018000000000000LL) || (tfsr[cpu] != 0)) fail((densupp<<6)+11);
  if ((grfpu_fitod(20,&scratch) != 0x4034000000000000LL) || (tfsr[cpu] != 0)) fail((densupp<<6)+11);
  if ((grfpu_fitod(98,&scratch) != 0x4058800000000000LL) || (tfsr[cpu] != 0)) fail((densupp<<6)+11);
  if ((grfpu_fitos(5,&scratch) != 0x40a00000) || (tfsr[cpu] != 0)) fail((densupp<<6)+11);
  
  /* FSTOI, FDTOI */
  set_fsr(0x0f000000);
  if ((grfpu_fdtoi(0x7000000000000000LL,&scratch) != 0x7fffffff) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+12);
  if ((grfpu_fdtoi(0xf000000000000000LL,&scratch) != 0x80000000) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+12);
  tfsr[cpu] = 0;
  if ((grfpu_fdtoi(0x0000000000000000LL,&scratch) != 0) || (tfsr[cpu] != 0)) fail((densupp<<6)+12);
  if ((grfpu_fdtoi(0x05100302a1000001LL,&scratch) != 0) || (tfsr[cpu] != 0)) fail((densupp<<6)+12);
  if ((grfpu_fstoi(0x47ffffff,&scratch) != 0x0001ffff) || (tfsr[cpu] != 0)) fail((densupp<<6)+12);
  if ((grfpu_fdtoi(qnan,&scratch) != 0x7fffffff) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+12);
  tfsr[cpu] = 0;
  if ((grfpu_fdtoi(ninf,&scratch) != 0x80000000) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+12);
  tfsr[cpu] = 0;
  if ((grfpu_fdtoi(snan,&scratch) != 0x7fffffff) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+12);
  tfsr[cpu] = 0;
  grfpu_fdtoi(denorm,&scratch);
  if (!densupp) {
    if (((tfsr[cpu] >> 14) & 3) != 2) fail((densupp<<6)+12);
  } else {
    if (tfsr[cpu] != 0) fail((densupp<<6)+12);
  }

  /* FSTOD, FDTOS */
  set_fsr(0x0f000000); tfsr[cpu] = 0;
  if ((grfpu_fstod(0x45601234,&scratch) != 0x40ac024680000000LL) || (tfsr[cpu] != 0)) fail((densupp<<6)+13);
  if ((grfpu_fstod(0xf00abcd1,&scratch) != 0xc601579a20000000LL) || (tfsr[cpu] != 0)) fail((densupp<<6)+13);
  if ((grfpu_fdtos(0x47f0000000000000LL,&scratch) != 0x7f800000) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | OF))) fail((densupp<<6)+13);
  tfsr[cpu] = 0;
  if ((grfpu_fdtos(0x81f0043000040000LL,&scratch) != 0x80000000) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | UF))) fail((densupp<<6)+13);
  tfsr[cpu] = 0;
  if ((grfpu_fdtos(0x0,&scratch) != 0) || (tfsr[cpu] != 0)) fail((densupp<<6)+13);
  if ((grfpu_fdtos(qnan,&scratch) != qnan_sp) || (tfsr[cpu] != 0)) fail((densupp<<6)+13);
  if ((grfpu_fdtos(pinf,&scratch) != 0x7f800000) || (tfsr[cpu] != 0)) fail((densupp<<6)+13);
  if ((grfpu_fdtos(snan,&scratch) != qsnan_sp) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+13);  
  tfsr[cpu] = 0;
  grfpu_fdtos(denorm,&scratch);
  if (!densupp) {
    if (((tfsr[cpu] >> 14) & 3) != 2) fail((densupp<<6)+13);
  } else  {
    if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | UF)) fail((densupp<<6)+13);
  }
  
  /* FMOVS, FABSS, FNEGS */
  set_fsr(0x0f800000); tfsr[cpu] = 0;
  if ((grfpu_fmovs(0x231abcde,&scratch) != 0x231abcde) || (tfsr[cpu] != 0)) fail((densupp<<6)+14);
  if ((grfpu_fabss(0x231abcde,&scratch) != 0x231abcde) || (tfsr[cpu] != 0)) fail((densupp<<6)+14);
  if ((grfpu_fabss(0xa31abcde,&scratch) != 0x231abcde) || (tfsr[cpu] != 0)) fail((densupp<<6)+14);
  if ((grfpu_fnegs(0x231abcde,&scratch) != 0xa31abcde) || (tfsr[cpu] != 0)) fail((densupp<<6)+14);
  if ((grfpu_fnegs(0xa31abcde,&scratch) != 0x231abcde) || (tfsr[cpu] != 0)) fail((densupp<<6)+14);

  /* FCMPxx */
  set_fsr(0x0f800000);
  if ((grfpu_fcmpd(0x546f010343208541LL, 0xd46f010343208541LL,&scratch) != GT) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);
  if ((grfpu_fcmpd(0xd46f010343208541LL, 0x546f010343208541LL,&scratch) != LT) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);
  if ((grfpu_fcmpd(0x0, 0x8000000000000000LL,&scratch) != EQ) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);
  if ((grfpu_fcmpd(pinf, ninf,&scratch) != GT) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);
  if ((grfpu_fcmpd(0x546f010343208541LL, 0x546fa10343208541LL,&scratch) != LT) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);
  if ((grfpu_fcmpd(0x546fa10343208541LL, 0x546f010343208541LL,&scratch) != GT) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);
  if ((grfpu_fcmpd(0x546fa10343208541LL, qnan,&scratch) != UN) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);
  if ((grfpu_fcmpd(0x546fa10343208541LL, snan,&scratch) != UN) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+15);
  tfsr[cpu] = 0;
  if ((grfpu_fcmpd(0x546fa10343208541LL, denorm,&scratch) != GT) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);   
  if ((grfpu_fcmpd(denorm, 0x546fa10343208541LL,&scratch) != LT) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);    
  if ((grfpu_fcmpd(qnan, 0x546fa10343208541LL,&scratch) != UN) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);  
  if ((grfpu_fcmpd(snan, 0x546fa10343208541LL,&scratch) != UN) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+15);

  tfsr[cpu] = 0;
  if ((grfpu_fcmped(0x546f010343208541LL, 0xd46f010343208541LL,&scratch) != GT) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);
  if ((grfpu_fcmped(0xd46f010343208541LL, 0x546f010343208541LL,&scratch) != LT) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);
  if ((grfpu_fcmped(0x0, 0x8000000000000000LL,&scratch) != EQ) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);
  if ((grfpu_fcmped(pinf, ninf,&scratch) != GT) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);
  if ((grfpu_fcmped(0x546f010343208541LL, 0x546fa10343208541LL,&scratch) != LT) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);
  if ((grfpu_fcmped(0x546fa10343208541LL, 0x546f010343208541LL,&scratch) != GT) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);
  if ((grfpu_fcmped(0x546fa10343208541LL, qnan,&scratch) != UN) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+15);
  if ((grfpu_fcmped(0x546fa10343208541LL, snan,&scratch) != UN) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+15);
  tfsr[cpu] = 0;
  if ((grfpu_fcmped(0x546fa10343208541LL, denorm,&scratch) != GT) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);    
  if ((grfpu_fcmped(denorm, 0x546fa10343208541LL,&scratch) != LT) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);   
  if ((grfpu_fcmped(qnan, 0x546fa10343208541LL,&scratch) != UN) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+15);
  if ((grfpu_fcmped(snan, 0x546fa10343208541LL,&scratch) != UN) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+15);
  tfsr[cpu] = 0;
  if ((grfpu_fcmps(0x0123abcd, 0x12345678,&scratch) != LT) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);
  if ((grfpu_fcmpes(0x0123abcd, 0x12345678,&scratch) != LT) || (tfsr[cpu] != 0)) fail((densupp<<6)+15);



  /* FADDx, FSUBx check */
  tfsr[cpu] = 0;
  set_fsr(0x0f000000);  
  grfpu_faddd(&x, &zero, &z); if ((x != z) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);
  grfpu_faddd(&x, &inf, &z);  if ((z != inf) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);
  grfpu_faddd(&x, &qnan, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);
  grfpu_faddd(&x, &snan, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+16);
  tfsr[cpu] = 0;  set_fsr(0x0);
  grfpu_faddd(&x, &snan, &z); if (z != qsnan) fail((densupp<<6)+16); 
  set_fsr(0x0f000000);
  grfpu_faddd(&x, &denorm, &z);
  if (!densupp) {
    if (((tfsr[cpu] >> 14) & 3) != 2) fail((densupp<<6)+16);
  } else {
    if (tfsr[cpu] != 0) fail((densupp<<6)+16);
  }
  tfsr[cpu] = 0;
  grfpu_faddd(&zero, &x, &z); if ((z != x) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);
  grfpu_faddd(&zero, &inf, &z); if ((z != inf) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);
  grfpu_faddd(&zero, &qnan, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);
  grfpu_faddd(&zero, &snan, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+16);
  tfsr[cpu] = 0; set_fsr(0x0);
  grfpu_faddd(&zero, &snan, &z); if (z != qsnan) fail((densupp<<6)+16);
  set_fsr(0x0f000000);
  grfpu_faddd(&zero, &denorm, &z);
  if (!densupp) {
    if (((tfsr[cpu] >> 14) & 3) != 2) fail((densupp<<6)+16);
  } else  {
    if (((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | UF))) fail((densupp<<6)+16);
  }
  tfsr[cpu] = 0;
  grfpu_faddd(&inf, &x, &z); if ((z != inf) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);
  grfpu_faddd(&inf, &zero, &z); if ((z != inf) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);  
  grfpu_faddd(&pinf, &pinf, &z); if ((z != pinf) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);    
  grfpu_faddd(&ninf, &ninf, &z); if ((z != ninf) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);    
  grfpu_faddd(&ninf, &pinf, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+16);
  set_fsr(0x0);
  grfpu_faddd(&ninf, &pinf, &z); if (z != qsnan) fail((densupp<<6)+16);
  set_fsr(0x0f000000); tfsr[cpu] = 0;
  grfpu_faddd(&pinf, &ninf, &z); if ((z != qsnan) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+16);
  tfsr[cpu] = 0;
  grfpu_faddd(&inf, &denorm, &z);
  if (!densupp) {
    if (((tfsr[cpu] >> 14) & 3) != 2) fail((densupp<<6)+16);
  } else {
    if (tfsr[cpu] != 0) fail((densupp<<6)+16);
  }
  tfsr[cpu] = 0;
  grfpu_faddd(&qnan, &x, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);
  grfpu_faddd(&qnan, &zero, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);
  grfpu_faddd(&qnan, &inf, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);
  grfpu_faddd(&qnan, &qnan, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);
  grfpu_faddd(&qnan, &snan, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+16);  
  tfsr[cpu] = 0;
  grfpu_faddd(&snan, &x, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+16);  
  tfsr[cpu] = 0;
  grfpu_faddd(&snan, &zero, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+16);  
  tfsr[cpu] = 0;
  grfpu_faddd(&snan, &inf, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+16);  
  tfsr[cpu] = 0;
  grfpu_faddd(&snan, &qnan, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+16);  
  tfsr[cpu] = 0;
  grfpu_faddd(&snan, &snan, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+16);  
  tfsr[cpu] = 0;
  grfpu_faddd(&snan, &denorm, &z);
  if (!densupp) {
    if (((tfsr[cpu] >> 14) & 3) != 2) fail((densupp<<6)+16);
  } else {
    if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+16);
  }
  set_fsr(0x0f000000); tfsr[cpu] = 0;
  for (i = 0; i < 13; i++)
  {
    grfpu_faddd(&faddd_tv[i].op1, &faddd_tv[i].op2, &z);
    if (z != *((uint64 *) &faddd_tv[i].res))  fail((densupp<<6)+16); 
  }
  if (tfsr[cpu] != 0) fail((densupp<<6)+16);
  grfpu_faddd(&faddd_tv[13].op1, &faddd_tv[13].op2, &z); 
  if ((z != faddd_tv[13].res) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | OF))) fail((densupp<<6)+16);
  tfsr[cpu] = 0;
  grfpu_faddd(&faddd_tv[14].op1, &faddd_tv[14].op2, &z);
  if (!densupp) {
    if ((z != faddd_tv[14].res) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | UF))) fail((densupp<<6)+16);
  } else {
    if (((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | UF))) fail((densupp<<6)+16);
  }
  tfsr[cpu] = 0;
  grfpu_faddd(&faddd_tv[15].op1, &faddd_tv[15].op2, &z);
  if (!densupp) {
    if ((z != faddd_tv[15].res) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | UF))) fail((densupp<<6)+16);
  } else {
    if (((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | UF))) fail((densupp<<6)+16);
  }
  tfsr[cpu] = 0;
if ((grfpu_fsubd(0x4000000000000000LL, 0x3ff0000000000000LL,&scratch) != 0x3ff0000000000000LL) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);
if ((grfpu_fsubd(0x4000000000000000LL, 0xbff0000000000000LL,&scratch) != 0x4008000000000000LL) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);
if ((grfpu_fsubd(0xc000000000000000LL, 0x3ff0000000000000LL,&scratch) != 0xc008000000000000LL) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);
if ((grfpu_fsubd(0xc000000000000000LL, 0xbff0000000000000LL,&scratch) != 0xbff0000000000000LL) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);

if ((grfpu_fadds(0x40000000, 0x3f800000,&scratch) != 0x40400000) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);
if ((grfpu_fsubs(0x40000000, 0x3f800000,&scratch) != 0x3f800000) || (tfsr[cpu] != 0)) fail((densupp<<6)+16);
  

  /* FDIVD check */
  tfsr[cpu] = 0;
  grfpu_fdivd(&x, &nzero, &z); if ((z != ninf) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | DZ))) fail((densupp<<6)+17);
  tfsr[cpu] = 0;
  grfpu_fdivd(&x, &pinf, &z); if ((z != pzero) || (tfsr[cpu] != 0)) fail((densupp<<6)+17);
  grfpu_fdivd(&x, &qnan, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+17);
  grfpu_fdivd(&x, &snan, &z); if ((z != qsnan) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+17);
  tfsr[cpu] = 0;
  grfpu_fdivd(&x, &denorm, &z);
  if (!densupp) {
     if ((tfsr[cpu] & FTT) != UNFINEXC) fail((densupp<<6)+17);
   } else {
    if (tfsr[cpu] != 0) fail((densupp<<6)+17);
   }
  tfsr[cpu] = 0;
  grfpu_fdivd(&zero, &x, &z); if ((z != zero) || (tfsr[cpu] != 0)) fail((densupp<<6)+17);
  grfpu_fdivd(&nzero, &pzero, &z); if ((z != qsnan) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+17);
  tfsr[cpu] = 0;
  grfpu_fdivd(&nzero, &pinf, &z); if ((z != nzero) || (tfsr[cpu] != 0)) fail((densupp<<6)+17);  
  grfpu_fdivd(&zero, &qnan, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail (7);
  grfpu_fdivd(&zero, &snan, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+17);
  tfsr[cpu] = 0;
  grfpu_fdivd(&zero, &denorm, &z);
 if (!densupp) {
    if ((tfsr[cpu] & FTT) != UNFINEXC) fail((densupp<<6)+17);
  } else {
    if (tfsr[cpu] != 0) fail((densupp<<6)+17);
  }
  tfsr[cpu] = 0;
  grfpu_fdivd(&ninf, &x, &z); if ((z != ninf) || (tfsr[cpu] != 0)) fail((densupp<<6)+17);
  grfpu_fdivd(&ninf, &nzero, &z); if ((z != pinf) || (tfsr[cpu] != 0)) fail((densupp<<6)+17);
  grfpu_fdivd(&inf, &inf, &z); if ((z != qsnan) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+17);
  tfsr[cpu] = 0;
  grfpu_fdivd(&inf, &qnan, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+17);
  grfpu_fdivd(&inf, &snan, &z); if ((z != qsnan) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+17);
  tfsr[cpu] = 0;
  grfpu_fdivd(&inf, &denorm, &z);
  if (!densupp) {
    if ((tfsr[cpu] & FTT) != UNFINEXC) fail((densupp<<6)+17);
  } else {
    if (tfsr[cpu] != 0) fail((densupp<<6)+17);
  }
  tfsr[cpu] = 0;
  grfpu_fdivd(&qnan, &x, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+17);
  grfpu_fdivd(&qnan, &zero, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+17);  
  grfpu_fdivd(&qnan, &inf, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+17);  
  grfpu_fdivd(&qnan, &qnan, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+17);  
  grfpu_fdivd(&qnan, &snan, &z); if ((z != qsnan) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+17);
  tfsr[cpu] = 0;
  grfpu_fdivd(&qnan, &denorm, &z);
  if (!densupp) {
    if ((tfsr[cpu] & FTT) != UNFINEXC) fail((densupp<<6)+17);
  } else {
    if (tfsr[cpu] != 0) fail((densupp<<6)+17);
  }
  grfpu_fdivd(&snan, &x, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+17);  
  tfsr[cpu] = 0;
  grfpu_fdivd(&snan, &zero, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+17);  
  tfsr[cpu] = 0;
  grfpu_fdivd(&snan, &inf, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+17);  
  tfsr[cpu] = 0;
  grfpu_fdivd(&snan, &qnan, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+17);  
  tfsr[cpu] = 0;
  grfpu_fdivd(&snan, &snan, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+17);  
  tfsr[cpu] = 0;
  grfpu_fdivd(&snan, &denorm, &z);
 if (!densupp) {
    if ((tfsr[cpu] & FTT) != UNFINEXC) fail((densupp<<6)+17);
  } else {
   if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+17);
  }

  tfsr[cpu] = 0; a = 0x7f000102030000b0LL; b = 0x80fa0fff008723a1LL;  /* OF */
  grfpu_fdivd(&a, &b, &c); if ((c != 0xfff0000000000000LL) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | OF))) fail((densupp<<6)+17);    
  tfsr[cpu] = 0; a = 0x01000102030000b0LL; b = 0x421a0fff008723a1LL;  /* UF */
  grfpu_fdivd(&a, &b, &c);
  if (!densupp) {
    if ((c != 0x0) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | UF))) fail((densupp<<6)+17);
  } else {
    if ((c == 0x0) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | UF))) fail((densupp<<6)+17);
  }
  tfsr[cpu] = 0; a = 0x001abc0000000010LL; b = 0x3ff000400a07610cLL; /* emin */
  grfpu_fdivd(&a, &b, &c); if ((c != 0x001abb9500ea6b0fLL) || (tfsr[cpu] != 0)) fail((densupp<<6)+17);  
  tfsr[cpu] = 0; a = 0x001abc0000000010LL; b = 0x3fffff400a07610cLL; /* emin - 1 */
  grfpu_fdivd(&a, &b, &c);
  if (!densupp) {
    if ((c != 0x0) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | UF))) fail((densupp<<6)+17);
  } else {
    if ((c == 0x0) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | UF))) fail((densupp<<6)+17);
  }
  /* FDIVS */
  tfsr[cpu] = 0;
  if ((grfpu_fdivs(0x42200000, 0x40040000, &scratch) != 0x419b26ca) || (tfsr[cpu] != 0)) fail((densupp<<6)+17);
  if ((grfpu_fdivs(0x46effbff, 0x31c10000, &scratch) != 0x549f291e) || (tfsr[cpu] != 0)) fail((densupp<<6)+17);  
  if ((grfpu_fdivs(0x7981f800, 0x431ffffc, &scratch) != 0x75cff338) || (tfsr[cpu] != 0)) fail((densupp<<6)+17);     
  /* 
   * The next test illustrates the issue with denormalized results and undetected 
   * underflow (fixed in revision 3143). The first fdiv passes, even if the bug is 
   * present. The second operation puts the FPU in a state in which the bug can be 
   * triggered, and the third fdivs will trigger the bug.
   */
  if (!densupp) {
    tfsr[cpu] = 0;
    if ((grfpu_fdivs(0x00800000, 0x3f800001, &scratch) != 0x0) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | UF))) fail((densupp<<6)+17);
    tfsr[cpu] = 0;
    if ((grfpu_fdivs(0x3f800000, 0x3f800000, &scratch) != 0x3f800000) || (tfsr[cpu] != 0)) fail((densupp<<6)+17);
    if ((grfpu_fdivs(0x00800000, 0x3f800001, &scratch) != 0x0) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | UF))) fail((densupp<<6)+17);
  }

  /* FMULD */
  tfsr[cpu] = 0;
  grfpu_fmuld(&x, &nzero, &z); if ((z != nzero) || (tfsr[cpu] != 0)) fail((densupp<<6)+18);
  grfpu_fmuld(&x, &pinf, &z); if ((z != pinf) || (tfsr[cpu] != 0)) fail((densupp<<6)+18);
  grfpu_fmuld(&x, &qnan, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+18);
  grfpu_fmuld(&x, &snan, &z); if ((z != qsnan) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+18);
  tfsr[cpu] = 0;
  grfpu_fmuld(&x, &denorm, &z);
  if (!densupp) {
    if ((tfsr[cpu] & FTT) != UNFINEXC) fail((densupp<<6)+18);
  } else {
    if (((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | UF))) fail((densupp<<6)+18);
  }
  tfsr[cpu] = 0;
  grfpu_fmuld(&zero, &x, &z); if ((z != zero) || (tfsr[cpu] != 0)) fail((densupp<<6)+18);
  grfpu_fmuld(&nzero, &ninf, &z); if ((z != qsnan) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+18);
  tfsr[cpu] = 0;
  grfpu_fmuld(&zero, &qnan, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+1177);
  grfpu_fmuld(&zero, &snan, &z); if ((z != qsnan) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+18);
  tfsr[cpu] = 0;
  grfpu_fmuld(&zero, &denorm, &z);
  if (!densupp) {
    if ((tfsr[cpu] & FTT) != UNFINEXC) fail((densupp<<6)+18);
  } else {
    if (tfsr[cpu] != 0) fail((densupp<<6)+18);
  }
  tfsr[cpu] = 0;
  grfpu_fmuld(&inf, &x, &z); if ((z != inf) || (tfsr[cpu] != 0)) fail((densupp<<6)+18);
  grfpu_fmuld(&inf, &zero, &z); if ((z != qsnan) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+18);
  tfsr[cpu] = 0;
  grfpu_fmuld(&inf, &qnan, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+18);
  grfpu_fmuld(&inf, &snan, &z); if ((z != qsnan) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+18);
  tfsr[cpu] = 0;
  grfpu_fmuld(&inf, &denorm, &z);
  if (!densupp) {
    if ((tfsr[cpu] & FTT) != UNFINEXC) fail((densupp<<6)+18);
  } else {
    if (tfsr[cpu] != 0) fail((densupp<<6)+18);
  }
  tfsr[cpu] = 0;
  grfpu_fmuld(&qnan, &x, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+18);
  grfpu_fmuld(&qnan, &zero, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+18);
  grfpu_fmuld(&qnan, &inf, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+18);
  grfpu_fmuld(&qnan, &qnan, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+18);
  grfpu_fmuld(&qnan, &snan, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+18);  
  tfsr[cpu] = 0;
  grfpu_fmuld(&snan, &x, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+18);  
  tfsr[cpu] = 0;
  grfpu_fmuld(&snan, &zero, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+18);  
  tfsr[cpu] = 0;
  grfpu_fmuld(&snan, &inf, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+18);  
  tfsr[cpu] = 0;
  grfpu_fmuld(&snan, &qnan, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+18);  
  tfsr[cpu] = 0;
  grfpu_fmuld(&snan, &snan, &z); if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+18);  
  tfsr[cpu] = 0;
  grfpu_fmuld(&snan, &denorm, &z);
  if (!densupp) {
    if (((tfsr[cpu] >> 14) & 3) != 2) fail((densupp<<6)+18);
  } else {
    if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV)) fail((densupp<<6)+18);
  }

  set_fsr(0x0f000000); tfsr[cpu] = 0;
  for (i = 0; i < 6; i++)
  {
    grfpu_fmuld(&fmuld_tv[i].op1, &fmuld_tv[i].op2, &z);
    if ((z != fmuld_tv[i].res) || (tfsr[cpu] != 0)) fail((densupp<<6)+18); 
  }
  grfpu_fmuld(&fmuld_tv[6].op1, &fmuld_tv[6].op2, &z);
  if (!densupp) {
    if ((z != fmuld_tv[6].res) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | UF))) fail((densupp<<6)+18);
  } else {
    if ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | UF)) fail((densupp<<6)+18);
  }
 tfsr[cpu] = 0;
 grfpu_fmuld(&fmuld_tv[7].op1, &fmuld_tv[7].op2, &z); if ((z != fmuld_tv[7].res) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | OF))) fail((densupp<<6)+18); tfsr[cpu] = 0; 
  grfpu_fmuld(&fmuld_tv[8].op1, &fmuld_tv[8].op2, &z); if ((z != fmuld_tv[8].res) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | OF))) fail((densupp<<6)+18); tfsr[cpu] = 0;
  grfpu_fmuld(&fmuld_tv[9].op1, &fmuld_tv[9].op2, &z); if ((z != fmuld_tv[9].res) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | UF))) fail((densupp<<6)+18); tfsr[cpu] = 0;
  grfpu_fmuld(&fmuld_tv[10].op1, &fmuld_tv[10].op2, &z); if ((z != fmuld_tv[10].res) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | OF))) fail((densupp<<6)+18); tfsr[cpu] = 0; 
  if ((grfpu_fmuls(0x40400000, 0x40000000) != 0x40c00000) || (tfsr[cpu] != 0)) fail((densupp<<6)+18);

  /* FSMULD */  
  grfpu_fsmuld(0x7f800000, 0x40000000, &z, &scratch); if ((z != 0x7FF0000000000000LL) || (tfsr[cpu] != 0)) fail((densupp<<6)+27);
  grfpu_fsmuld(0x7f800000, 0xc0000000, &z, &scratch); if ((z != 0xFFF0000000000000LL) || (tfsr[cpu] != 0)) fail((densupp<<6)+28);
  grfpu_fsmuld(0x40000000, 0x00000010, &z, &scratch);
  if (!densupp) {
    if ((tfsr[cpu] & FTT) != UNFINEXC) fail((densupp<<6)+29);
  } else {
    if (tfsr[cpu] != 0) fail((densupp<<6)+29);
  }
 tfsr[cpu] = 0;
 /* Check for FSMULD exponent check bug fixed in revision 3497 */
 grfpu_fsmuld(0x00800000, 0x3f000000, &z, &scratch); if ((z != 0x3800000000000000LL) || (tfsr[cpu] != 0)) fail((densupp<<6)+30);
 grfpu_fsmuld(0x7f7fffff, 0x40000000, &z, &scratch); if ((z != 0x47FFFFFFE0000000LL) || (tfsr[cpu] != 0)) fail((densupp<<6)+31);
  /* Check for FSMULD corner case bug fixed in rev. 4018 */
 grfpu_fsmuld(0x7f400000, 0x3fc00000, &z, &scratch); if ((z != 0x47f2000000000000LL) || (tfsr[cpu] != 0)) fail((densupp<<6)+33);
  /* Check that the full result vector is propagated */
 grfpu_fsmuld(0x7f7fffff, 0x7f7fffff, &z, &scratch); if ((z != 0x4FEFFFFFC0000020LL) || (tfsr[cpu] != 0)) fail((densupp<<6)+32);

  /* FSQRTD */
  set_fsr(0x0f000000); tfsr[cpu] = 0;
  grfpu_sqrtd(&pzero, &z); if ((z != pzero) || (tfsr[cpu] != 0)) fail((densupp<<6)+19);
  grfpu_sqrtd(&nzero, &z); if ((z != nzero) || (tfsr[cpu] != 0)) fail((densupp<<6)+19);
  grfpu_sqrtd(&pinf, &z); if ((z != pinf) || (tfsr[cpu] != 0)) fail((densupp<<6)+19);
  grfpu_sqrtd(&ninf, &z); if ((z != qsnan) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+19);
  tfsr[cpu] = 0;
  grfpu_sqrtd(&snan, &z); if ((z != qsnan) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+19);
  tfsr[cpu] = 0;
  grfpu_sqrtd(&qnan, &z); if ((z != qnan) || (tfsr[cpu] != 0)) fail((densupp<<6)+19);
  x = 0x4030000000000000LL; y = 0xc03de00030002001LL;
  grfpu_sqrtd(&x, &z); if ((z != 0x4010000000000000LL) || (tfsr[cpu] != 0)) fail((densupp<<6)+19);
  grfpu_sqrtd(&y, &z); if ((z != qsnan) || ((tfsr[cpu] & FTT_CEXC) != (IEEE754EXC | NV))) fail((densupp<<6)+19);
  tfsr[cpu] = 0;
  grfpu_sqrtd(&denorm, &z);
  if (!densupp) {
    if (((tfsr[cpu] >> 14) & 3) != 2) fail((densupp<<6)+19);
  } else {
    if (tfsr[cpu] != 0) fail((densupp<<6)+19);
  }


  /* FSQRTS */
  tfsr[cpu] = 0;
  if ((grfpu_fsqrts(0x47c80000,&scratch) != 0x43a00000) || (tfsr[cpu] != 0)) fail((densupp<<6)+19);
  /* Check FSQRTS handling of exact results in round-to-zero mode, fixed in revision 4029 */
  set_fsr(0x40000000);
  if ((grfpu_fsqrts(0x07D625E2,&scratch) != 0x23A59000) || (tfsr[cpu] != 0)) fail((densupp<<6)+35);
  if ((grfpu_fsqrts(0x4A882000,&scratch) != 0x45040000) || (tfsr[cpu] != 0)) fail((densupp<<6)+35);


  /* check non-IEEE mode */
  if (!densupp) {
    set_fsr(0x00400000);
    grfpu_faddd(&x, &denorm, &z);
    if ((z != 0x4030000000000000LL) || (tfsr[cpu] != 0)) fail((densupp<<6)+20);
    grfpu_fmuld(&denorm, &y, &z);
    if ((z != 0x8000000000000000LL) || (tfsr[cpu] != 0)) fail((densupp<<6)+20);

    /* Check if we have fitos/fitod bug, fixed in rev 2993 */
    if ((grfpu_fitos(1,&scratch) != 0x3f800000)  || (tfsr[cpu] != 0)) fail((densupp<<6)+20);
    if ((grfpu_fitod(1,&scratch) != 0x3ff0000000000000LL)  || (tfsr[cpu] != 0)) fail((densupp<<6)+20);

    /* Check infinity arithmetic bug in non-IEEE mode and down-rounding mode, fixed in rev 4021 */
    set_fsr(0x40400000);
    z=grfpu_fsubd(denorm,pinf,&scratch); if ((z != ninf) || (tfsr[cpu] != 0)) fail((densupp<<6)+34);
  }

  /* check RZ, RP, RM rounding modes */
  set_fsr(0x40000000); x = 0x3ff0000000000000LL; y = 0x3ca00000100200f0LL;
  grfpu_faddd(&x, &y, &z); if (z != 0x3ff0000000000000LL) fail((densupp<<6)+21);
  set_fsr(0x80000000); x = 0x3ff0000000000000LL; y = 0x0050000000010001LL;
  grfpu_faddd(&x, &y, &z); if (z != 0x3ff0000000000001LL) fail((densupp<<6)+21);
  set_fsr(0xc0000000); x = 0xbff0000000000000LL; y = 0x8050000000010001LL;
  grfpu_faddd(&x, &y, &z); if (z != 0xbff0000000000001LL) fail((densupp<<6)+21);

  /* Check for infinity arithmetic bugs, fixed in rev 3081 */
  set_fsr(0x40000000); x = 0x3ff0000000000000LL;
  grfpu_faddd(&x, &inf, &z); if (z != inf) fail((densupp<<6)+21);
  set_fsr(0x80000000); x = 0x3ff0000000000000LL; y = 0x0050000000010001LL;
  grfpu_faddd(&x, &inf, &z); if (z != inf) fail((densupp<<6)+21);
  set_fsr(0xc0000000); x = 0xbff0000000000000LL; y = 0x8050000000010001LL;
  grfpu_faddd(&x, &inf, &z); if (z != inf) fail((densupp<<6)+21);

  set_fsr(0x40000000); x = 0x3ff0000000000001LL; y = 0x4000000000000001LL;
  grfpu_fmuld(&x, &y, &z); if (z != 0x4000000000000002LL) fail((densupp<<6)+21);
  set_fsr(0x80000000); 
  grfpu_fmuld(&x, &y, &z); if (z != 0x4000000000000003LL) fail((densupp<<6)+21);
  set_fsr(0xc0000000); x = 0xbff0000000000001LL;
  grfpu_fmuld(&x, &y, &z); if (z != 0xc000000000000003LL) fail((densupp<<6)+21);

  set_fsr(0x40000000); x = 0x3ffab954734ba011LL; y = 0x3ff01012bc985631LL;
  grfpu_fdivd(&x, &y, &z); if (z != 0x3ffa9e96b06cd02fLL) fail((densupp<<6)+21);  
  set_fsr(0x80000000);
  grfpu_fdivd(&x, &y, &z); if (z != 0x3ffa9e96b06cd030LL) fail((densupp<<6)+21);
  set_fsr(0xc0000000); y = 0xbff01012bc985631LL;  
  grfpu_fdivd(&x, &y, &z); if (z != 0xbffa9e96b06cd030LL) fail((densupp<<6)+21);  

  /* Check for rounding bugs, fixed in revision 3143 */
  set_fsr(0x40000000); x = 0x40e0000000000000LL; y = 0x4040000000000000LL;
  grfpu_fdivd(&x, &y, &z); if (z != 0x4090000000000000LL) fail((densupp<<6)+21);  
  set_fsr(0x80000000);
  grfpu_fdivd(&x, &y, &z); if (z != 0x4090000000000000LL) fail((densupp<<6)+21);
  set_fsr(0xc0000000); 
  grfpu_fdivd(&x, &y, &z); if (z != 0x4090000000000000LL) fail((densupp<<6)+21);  

  if (!densupp) {
    set_fsr(0x40000000);
    if ((grfpu_fdivs(0x00800000, 0x3f800001, &scratch) != 0x0)) fail((densupp<<6)+21);
    set_fsr(0x80000000);
    if ((grfpu_fdivs(0x00800000, 0x3f800001, &scratch) != 0x0)) fail((densupp<<6)+21);
    set_fsr(0xc0000000);
    if ((grfpu_fdivs(0x00800000, 0x3f800001, &scratch) != 0x0)) fail((densupp<<6)+21);
  } else {
    set_fsr(0x40000000);
    if ((grfpu_fdivs(0x00800000, 0x3f800001, &scratch) != 0x007fffff)) fail((densupp<<6)+21);
    set_fsr(0x80000000);
    if ((grfpu_fdivs(0x00800000, 0x3f800001, &scratch) != 0x00800000)) fail((densupp<<6)+21);
    set_fsr(0xc0000000);
    if ((grfpu_fdivs(0x00800000, 0x3f800001, &scratch) != 0x007fffff)) fail((densupp<<6)+21);
  }

  set_fsr(0x40000000); x = 0x3ff0000000000000LL;
  grfpu_sqrtd(&x, &z); if ((z != x) || (tfsr[cpu] != 0)) fail((densupp<<6)+21);
  set_fsr(0x80000000);
  grfpu_sqrtd(&x, &z); if ((z != x) || (tfsr[cpu] != 0)) fail((densupp<<6)+21);
  set_fsr(0xc0000000);
  grfpu_sqrtd(&x, &z); if ((z != x) || (tfsr[cpu] != 0)) fail((densupp<<6)+21);

  set_fsr(0x40000000);
  if ((grfpu_fsqrts(0x3f7fffff,&scratch) != 0x3f7fffff)) fail((densupp<<6)+21);
  set_fsr(0x80000000);
  if ((grfpu_fsqrts(0x3f7fffff,&scratch) != 0x3f800000)) fail((densupp<<6)+21);
  set_fsr(0xc0000000);
  if ((grfpu_fsqrts(0x3f7fffff,&scratch) != 0x3f7fffff)) fail((densupp<<6)+21);

  
  /* check GRFPC lock logic */
  set_fsr(0);
  grfpc_dpdep_tst(&z); if (z != 0xbff8000000000000LL) fail((densupp<<6)+22);
  grfpc_spdep_tst(&fl); if (fl != 0xbfc00000) fail((densupp<<6)+22);
  grfpc_spdep_tst2(&fl); if (fl != 0x3f800000) fail((densupp<<6)+22);
  grfpc_spdpdep_tst(&z); if (z != 0x3fefdff00ffc484aLL) fail((densupp<<6)+22); 

  /* check unfinished FP trap */
  if (!densupp) {
    grfpu_fdivd(&x, &denorm, &z);
    if (((tfsr[cpu] & ((1 << 17) - 1)) >> 14) != 2) fail((densupp<<6)+23); 
    /* check FP instruction in FQ */
    //unfaddr = ((unsigned int *) &grfpu_fdivd) + 2; unfinst = *unfaddr;
    unfaddr = ((unsigned int *) grfpu_fdivd) + 2; unfinst = *unfaddr;
    if (((unsigned int) unfaddr) != grfpufq[4*cpu]) fail((densupp<<6)+24);  
    if (unfinst != grfpufq[4*cpu+1]) fail((densupp<<6)+24);
    if (grfpufq[4*cpu+2] != 0) fail((densupp<<6)+24);
    if (grfpufq[4*cpu+3] != 0) fail((densupp<<6)+24);
  }

  /* Check for pipelined FMULS bug fixed in rev 3858 */
  if (test_pl1(&scratch) == 1) fail((densupp<<6)+25);  

  /* look-up table test */
  x = 0x3100a4068f346c9bLL; y = 0;
  divident(&x); 
  for (i = 0 ; i < 256; i++)
  {
    *((unsigned int *) &y) = divisor[i];
    divromtst(&y, &z);
    if (z != *((uint64 *) &divres[2*i]))  fail((densupp<<6)+25); 
  }

  for (i = 0; i < 256; i = i + 2) 
  {
    *((unsigned int *) &y) = divisor[i];
    grfpu_sqrtd(&y, &z);
    if (z != *((uint64 *) &sqrtres[i])) fail((densupp<<6)+26);
  }

//  report_end(); 
}   

