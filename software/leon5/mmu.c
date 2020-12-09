#include <stddef.h>
#include <bcc/bcc.h>
#include "leon3.h"
#include "testmod.h" 
#include "mmu.h" 

#define TLBNUM 8

#ifndef RAMSTART
#define RAMSTART 0x40000000
#endif

#ifndef ROMSTART
#define ROMSTART 0x00000000
#endif

/* Symbols are defined in mmu_asm.S */
extern unsigned long mmu_ctx_start;
extern unsigned long mmu_pg0_start;
extern unsigned long mmu_pm0_start;
extern unsigned long mmu_pt0_start;
extern unsigned long mmu_page0_start;
extern unsigned long mmu_page1_start;
extern unsigned long mmu_page2_start;
extern unsigned long pth_addr;
extern unsigned long pth_addr1;

/* Trap handlers defined in mmu_asm.S */
extern void systest_instruction_access_exception(void);
extern void systest_data_access_exception(void);
extern void systest_trap_set_supervisor(void);

/* SPARC V8 TT values */
#define MYTT_INSTRUCTION_ACCESS_EXCEPTION 1
#define MYTT_DATA_ACCESS_EXCEPTION 9
/* 0x8F is the software trap number for "set_supervisor" */
#define MYTT_SET_SUPERVISOR 0x8F

/*
 * User functions for enter supervisor/user mode. ABI compatible and requires
 * the SET_SUPERVISOR software trap to be installed before use.
 */
void systest_enter_supervisor(void);
void systest_enter_user(void);

typedef void (*functype)(void);

extern void mmu_double(void);
extern void srmmu_set_mmureg_aligned(unsigned int val);
extern unsigned int rsysreg(unsigned int addr);

#define fail(err) do { } while(1);



void leon_flush_cache_all (void)
{
        __asm__ __volatile__(" flush ");
}

void leon_flush_tlb_all (void)
{
        leon_flush_cache_all();
        __asm__ __volatile__("sta %%g0, [%0] %1\n\t": :
                             "r" (0x400),
                             "i" (0x18) : "memory");
}

unsigned int mmugetpagesize(unsigned int k)
{
	int psz = 0;
	if (((k >> 24) & 0xf) >= 1 ) { /* impl version  >= 1 */
		psz = (k >> 16) & 0x3;
	}
	return psz;
}

int pgsz = 0;
unsigned int pgd_sh = 24, pgd_m = 0xff;
unsigned int pmd_sh = 18, pmd_m = 0x3f;
unsigned int pte_sh = 12, pte_m = 0x3f;

void mmu_func1();

int mmu_test(void)
{
  ctxd_t *c0 = (ctxd_t *)&mmu_ctx_start;
  pgd_t *g0 = (pgd_t *)&mmu_pg0_start;
  pmd_t *m0 = (pmd_t *)&mmu_pm0_start;
  pte_t *p0 = (pte_t *)&mmu_pt0_start;
  unsigned long pteval,j,k;
  unsigned long val;
  unsigned long *pthaddr = &pth_addr1;
  functype func = mmu_func1;
  int i=0;

  if ((rsysreg(12) & 8) == 0) return(0);
  report_subtest(MMU_TEST+(get_pid()<<4));

  bcc_set_trap(MYTT_INSTRUCTION_ACCESS_EXCEPTION, systest_instruction_access_exception);
  bcc_set_trap(MYTT_DATA_ACCESS_EXCEPTION, systest_data_access_exception);
  bcc_set_trap(MYTT_SET_SUPERVISOR, systest_trap_set_supervisor);

 pgsz = mmugetpagesize(srmmu_get_mmureg());

#define PGD_IDX(v) (((v) >> pgd_sh) & pgd_m)
#define PMD_IDX(v) (((v) >> pmd_sh) & pmd_m)
#define PTE_IDX(v) (((v) >> pte_sh) & pte_m)
#define DEF_ADDR(a,b,c,d) (((((a)&pgd_m)<<pgd_sh) | (((b)&pmd_m)<<pmd_sh) | (((c)&pte_m)<<pte_sh)) | (d))
 
      switch (pgsz) {
      case 0:
	      break;
      case 1:
	      pgd_sh = 24+1;
	      pgd_m = 0x7f;
	      pmd_sh = 18+1;
	      pmd_m = 0x3f;
	      pte_sh = 12+1;
	      pte_m = 0x3f;
	      break;
      case 2:
	      pgd_sh = 24+2;
	      pgd_m = 0x3f;
	      pmd_sh = 18+2;
	      pmd_m = 0x3f;
	      pte_sh = 12+2;
	      pte_m = 0x3f;
	      break;
      case 3:
	      pgd_sh = 28;
	      pgd_m = 0x0f;
	      pmd_sh = 21;
	      pmd_m = 0x7f; /* 7 bit pmd */
	      pte_sh = 12+3;
	      pte_m = 0x3f; /* 6 bit pte */
	      break;
      }

#define REAL_PAGE_SIZE (1<<(PAGE_SHIFT+pgsz))
 
 leon_flush_cache_all ();
 leon_flush_tlb_all ();

 /* Prepare Page Table Hirarchy */
 /* one-on-one mapping for context 0 */
 srmmu_ctxd_set(c0+0,(pgd_t *)g0); //ctx 0
 srmmu_ctxd_set(c0+1,(pgd_t *)g0); //ctx 1
 pteval = ((ROMSTART >> 4) | SRMMU_ET_PTE | SRMMU_EXEC);           /*ROMSTART - ROMSTART+1000000: ROM */
 srmmu_set_pte(g0+PGD_IDX(ROMSTART), pteval);
 pteval = ((0x20000000 >> 4) | SRMMU_ET_PTE | SRMMU_EXEC);  /*20000000 - 21000000: IOAREA */
 srmmu_set_pte(g0+PGD_IDX(0x20000000), pteval);
 pteval = ((RAMSTART >> 4) | SRMMU_ET_PTE | SRMMU_EXEC | SRMMU_WRITE | SRMMU_CACHE);  /*RAMSTART - RAMSTART+01000000: CRAM */
 srmmu_set_pte(g0+PGD_IDX(RAMSTART), pteval);
 pteval = ((0x70000000 >> 4) | SRMMU_ET_PTE | SRMMU_EXEC | SRMMU_WRITE | SRMMU_CACHE);  /*70000000 - 71000000: CRAM */
 srmmu_set_pte(g0+PGD_IDX(0x70000000), pteval); 

#define a_30080000 DEF_ADDR(0x3,2,0,0)
#define a_30041000 DEF_ADDR(0x3,1,1,0)
#define a_30041004 DEF_ADDR(0x3,1,1,4)
#define a_30042000 DEF_ADDR(0x3,1,2,0)
#define a_30043000 DEF_ADDR(0x3,1,3,0)
#define a_31000000 DEF_ADDR(0x3,3,0,0)
 
 /* testarea: 
  *  map RAMSTART    at 3080000 [vaddr:(0) (0x3)(2)(-)] as pmd 
  *  map page0       at 3041000 [vaddr:(0) (0x3)(1)(1)] as page SRMMU_PRIV_RDONLY
  *  map mmu_func1() at 3042000 [vaddr:(0) (0x3)(1)(2)] as page
  *  map 3043000 - 307f000 [vaddr:(0) (0x3)(1)(3)] - [vaddr:(0) (0x3)(1)(63)] as page
  * page fault test: 
  *  missing pgd at 3030000 [vaddr:(0) (0x3)(0x3)(-)]
  */
 srmmu_pgd_set(g0+0x3,m0);
 pteval = ((((unsigned long)RAMSTART) >> 4) | SRMMU_ET_PTE | SRMMU_PRIV); 
 srmmu_set_pte(m0+2, pteval);
 srmmu_set_pte(m0+3, 0);
 srmmu_pmd_set(m0+1,p0);
 srmmu_set_pte(p0+2, 0);
 pteval = ((((unsigned long)&mmu_page0_start) >> 4) | SRMMU_ET_PTE | SRMMU_PRIV_RDONLY);
 srmmu_set_pte(p0+1, pteval);
 ((unsigned long *)&mmu_page0_start)[0] = 0;
 ((unsigned long *)&mmu_page0_start)[1] = 0x12345678;
 for (i = 3;i<TLBNUM+3;i++) {
       pteval = (((((unsigned long)&mmu_page2_start)+(((i-3)%3)*REAL_PAGE_SIZE)) >> 4) | SRMMU_ET_PTE | SRMMU_PRIV);
       srmmu_set_pte(p0+i, pteval);
 }

 *((unsigned long **)&pth_addr) =  pthaddr;
 /* repair info for fault (RAMSTART)*/
 pthaddr[0] = (unsigned long) (m0+0x3);
 pthaddr[1] = ((RAMSTART >> 4) | SRMMU_ET_PTE | SRMMU_PRIV);  
 pthaddr[2] = 31000000;
 /* repair info for write protection fault (0x3041000) */
 pthaddr[3] = (unsigned long) (p0+1);
 pthaddr[4] = ((((unsigned long)&mmu_page0_start) >> 4) | SRMMU_ET_PTE | SRMMU_PRIV);
 pthaddr[5] = a_30041000;
 /* repair info for instruction page fault (0x3042000) */
 pthaddr[6] = (unsigned long) (p0+2);
 pthaddr[7] = ((((unsigned long)func) >> 4) | SRMMU_ET_PTE | SRMMU_PRIV);
 pthaddr[8] = a_30042000;
 /* repair info for priviledge protection fault (0x30041000) */
 pthaddr[9] = (unsigned long) (p0+1);
 pthaddr[10] = ((((unsigned long)&mmu_page0_start) >> 4) | SRMMU_ET_PTE | SRMMU_EXEC | SRMMU_WRITE);
 pthaddr[11] = a_30041000;
 
 srmmu_set_ctable_ptr((unsigned long)c0);

 /* test reg access */
 k = srmmu_get_mmureg();
 k = srmmu_get_ctable_ptr();
 srmmu_set_context(1);
 k = srmmu_get_context();
 srmmu_set_context(0);

 /* close your eyes and pray ... */
 srmmu_set_mmureg(0x00000001);
 asm(" flush "); //iflush 

  if (((rsysreg(0) >> ITE_BIT) & 3) == 0) mmu_double();

 /* test reg access */
 k = srmmu_get_mmureg();
 k = srmmu_get_ctable_ptr();
 k = srmmu_get_context();

 /* do tests*/
 if ( (*((volatile unsigned long *)a_30041000)) != 0 ||
      (*((volatile unsigned long *)a_30041004)) != 0x12345678 ) { fail(1); }
 if ( (*((volatile unsigned long *)a_30080000)) != (*((unsigned long *)RAMSTART))) { fail(2); }
 
 /* page faults tests*/
 val = * ((volatile unsigned long *) a_31000000 );
 /* write protection fault */
 * ((volatile unsigned long *)a_30041004) = 0x87654321;
 if ( (*((volatile unsigned long *)a_30041004)) != 0x87654321 ) { fail(3); }
 /* doubleword write */
 __asm__ __volatile__("mov %0 ,%%g1\n\t"	\
                      "set 0x12345678,%%g2\n\t"\
                      "set 0xabcdef01,%%g3\n\t"\
                      "std %%g2, [%%g1]\n\t"\
                      "std %%g2, [%%g1]\n\t": : "r" (a_30041000) :
                      "g1","g2","g3");
 if ( (*((volatile unsigned long *)a_30041000)) != 0x12345678 ||
      (*((volatile unsigned long *)a_30041004)) != 0xabcdef01) { fail(4); }
  
 for (j=a_30043000,i = 3;i<TLBNUM+3;i++,j+=REAL_PAGE_SIZE) {
       *((unsigned long *)j) = j;
       asm(" sta	%g0, [%g0] 0x11 "); //dflush
       if ( *((unsigned long*) (((unsigned long)&mmu_page2_start)+(((i-3)%3)*REAL_PAGE_SIZE))) != j ) { fail(5); }
 }
       asm(" sta	%g0, [%g0] 0x11 "); //dflush
 for (j=0,i = 3;i<TLBNUM+3;i++) {
       pteval = (((((unsigned long)&mmu_page2_start)+(((i-3)%3)*REAL_PAGE_SIZE)) >> 4) | SRMMU_ET_PTE | SRMMU_PRIV);
       if ((*(p0+i)) & (SRMMU_DIRTY | SRMMU_REF)) j++;
       if (((*(p0+i)) & ~(SRMMU_DIRTY | SRMMU_REF))  != (pteval& ~(SRMMU_DIRTY | SRMMU_REF))) { fail(6); }
 }
 //at least one entry has to have been flushed
 if (j == 0) { fail(7);}

 /* instruction page fault */
 func = (functype)a_30042000;
 func();
 
 /* flush */
 srmmu_flush_whole_tlb();
       asm(" sta	%g0, [%g0] 0x11 "); //dflush
       
 for (j=0,i = 3;i<TLBNUM+3;i++) {
       if ((*(p0+i)) & (SRMMU_DIRTY | SRMMU_REF)) j++;
 }
 if (j != TLBNUM) { fail(8);}
  
 /* check modified & ref bit */
 if (!srmmu_pte_dirty(p0[1]) || !srmmu_pte_young(p0[1])) { fail(9); };
 if (!srmmu_pte_young(m0[2])) { fail(10); };
 if (!srmmu_pte_young(p0[2])) { fail(11); };

 /* check priviledge fault */
 systest_enter_user();

 // supervisor = 0 
 val = * ((volatile unsigned long *)a_30041004);

 systest_enter_supervisor();
 
 if (((rsysreg(0) >> ITE_BIT) & 3) == 0) mmu_double();
 // supervisor = 1 
 {
   //check ctx field
   unsigned long a;
   srmmu_set_context(0);
   a = *(unsigned long *)RAMSTART;
   srmmu_set_context(1);
   a = *(unsigned long *)RAMSTART;
   srmmu_set_context(0);
   a = *(unsigned long *)RAMSTART;
 }
 {
   //bypass asi:
   unsigned int i,j;
   i = leon_load_bp(RAMSTART);
   leon_store_bp(RAMSTART,i);
   j = *((unsigned long *)RAMSTART);
   if (j != i) fail(16);
   leon_store_bp(RAMSTART,i+1);
   j = *((unsigned long *)RAMSTART); /* data in Dcache should be unchanged */
   if (j != i) fail(17);
   leon_store_bp(RAMSTART,i);
 }
 //mmu off
 srmmu_set_mmureg_aligned(0x00000000);
 
 asm("flush");

 /* Clean-up so that later tests do not fall into the trap. */
 bcc_set_trap(MYTT_INSTRUCTION_ACCESS_EXCEPTION, NULL);
 bcc_set_trap(MYTT_DATA_ACCESS_EXCEPTION, NULL);
 bcc_set_trap(MYTT_SET_SUPERVISOR, NULL);

 return(0);
}

