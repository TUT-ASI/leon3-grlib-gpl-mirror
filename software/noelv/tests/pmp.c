//#define SHORT
// Use -DXDEFS for compiler to be able to specify these externally.
#if !defined(XDEFS)
//# define DESKTOP      // Run on a PC to check logic.
# define NO_MMU       // Do not activate MMU.
//# define MMODE        // Machine mode PMP test (using lock bits, that is).
//# define COMPRESSED   // Compressed instruction support (for execution test).

// Working
// no_mmu mmode execute_test
// no_mmu mmode compressed execute_test
// no_mmu mmode write_test value_check
// no_mmu mmode read_test  value_check
// (The above cannot be matched against spike due to lock bits.)
// no_mmu write_test value_check
// no_mmu read_test  value_check
// write_test value_check
// read_test  value_check

// qqq Missing test for execution protection in non-mmode and with MMU!
// qqq Do less tests of execution protection due to alignment!
// qqq Count fault/OK to ensure correctness!
// qqq Verify that destination registers are not updated on fault! Done already?

//# define EXECUTE_TEST // Tests execution rather than reads. WORKS! qqq Should have value check.
# define WRITE_TEST   // Test writes rather than reads.
# define VALUE_CHECK  // Check that correct changes (or not) happen.
# define QUICK        // Shorten test.
//# define QUICKEST

//# define NO_TOR       // Disable range based PMP testing.
# if !defined(EXECUTE_TEST)
#  define G 1          // Use other granularity than the default 0 (4 bytes).
# else
#  define G 3          // Use other granularity than the default 0 (4 bytes).
# endif
#endif

#if defined(MMODE) && !defined(NO_MMU)
# error "Bad combination of options!"
#endif

#if !defined(WRITE_TEST) && !defined(EXECUTE_TEST)
# define READ_TEST
#endif

#if defined(EXECUTE_TEST) && defined(VALUE_CHECK)
# error "Execution test cannot check values!"
#endif

#if !defined(G)
# if !defined(EXECUTE_TEST)
#  define G 0
# else
#  define G 3          // Use cacheline size since fetch (8 byte) gets complicated.
# endif
#endif

// The NOEL-V instruction fetches are done 8 bytes at a time.
// But things get hairy if we can get errors in the middle of cacheline fill.
//#if defined(EXECUTE_TEST) && (G < 1)
//# error "Execution test must have granularity >= 1 (8 bytes)!"
#if defined(EXECUTE_TEST) && (G < 3)
# error "Execution test must have granularity >= 3 (32 bytes, one cacheline)!"
#endif

// See LICENSE for license details.

// Test of PMP functionality.

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>


#if defined(WRITE_TEST)
# define PMP_FLAGS        (PMP_R | PMP_W)    // Only PMP_W is illegal.
# define CAUSE_MEM_ACCESS CAUSE_STORE_ACCESS
#elif defined(EXECUTE_TEST)
# define PMP_FLAGS        (PMP_X)
# define CAUSE_MEM_ACCESS CAUSE_FETCH_ACCESS
#elif defined(READ_TEST)
# define PMP_FLAGS        PMP_R
# define CAUSE_MEM_ACCESS CAUSE_LOAD_ACCESS
#endif


int trap_count;
int test_count;

uintptr_t write_value;

#if defined(QUICK)
// Read and write tests have the same numbers!
# if !defined(EXECUTE_TEST)
#  define TEST_NO 3240
#  define TRAP_NO 1620
# else
#  define TEST_NO 2968
#  define TRAP_NO 1496
# endif
#else
// Read and write tests have the same numbers!
# if !defined(EXECUTE_TEST)
#  define TEST_NO 16328
#  define TRAP_NO 8013
# else
#  define TEST_NO 15068
#  define TRAP_NO 7503
# endif
#endif

#if !defined(DESKTOP)
# include "util.h"

volatile int trap_expected;
volatile uintptr_t trap_addr;


//# define INLINE inline __attribute__((always_inline))
# define INLINE

# if !defined(MMODE)
#  define SFENCE_VMA do { asm volatile ("sfence.vma" ::: "memory"); } while (0)
#  define LOAD(type,new_mstat,address,value)                       \
                     do { asm volatile ("csrrw %0, mstatus, %0; "  \
                                        "l" #type " %1, (%2); "    \
                                        "csrw mstatus, %0"         \
                                        : "+&r" (new_mstat),       \
                                          "+r"  (value)            \
                                        : "r"   (address));        \
                     } while (0)
#  define STORE(type,new_mstat,address,value)                      \
                     do { asm volatile ("csrrw %0, mstatus, %0; "  \
                                        "s" #type " %1, (%2); "    \
                                        "csrw mstatus, %0"         \
                                        : "+&r" (new_mstat),       \
                                          "=r"  (value)            \
                                        : "r"   (address));        \
                     } while (0)
# else
#  define SFENCE_VMA
// Machine mode tests require the use of the pmpcfg lock bits.
// Note that while these cannot be disabled in a "real" implementation,
// here they can due to a special write to the CSR register DFEATURESEN.
// qqq Does not work for some reason! #  define dfeaturesen 0x7c0
#  define UNLOCKABLE  0x100
#  define LOAD(type,lock_mask,address,value)                       \
                     do { asm volatile ("csrrs %0, pmpcfg0, %0; "  \
                                        "l" #type " %1, (%2); "    \
                                        "csrw pmpcfg0, %0"         \
                                        : "+&r" (lock_mask),       \
                                          "+r"  (value)            \
                                        : "r"   (address));        \
                     } while (0)
# define STORE(type,lock_mask,address,value)                       \
                     do { asm volatile ("csrrs %0, pmpcfg0, %0; "  \
                                        "s" #type " %1, (%2); "    \
                                        "csrw pmpcfg0, %0"         \
                                        : "+&r" (lock_mask),       \
                                          "+r"  (value)            \
                                        : "r"   (address));        \
                     } while (0)
# define EXECUTE(lock_mask,address,value)                          \
                     do { asm volatile ("csrrs %0, pmpcfg0, %0; "  \
                                        "jalr x1,0(%2); "          \
                                        "csrw pmpcfg0, %0"         \
                                        : "+&r" (lock_mask),       \
                                          "=r"  (value)            \
                                        : "r"   (address));        \
                     } while (0)
# endif

//# define LOAD(type,new_mstat,address,value)  MEM(type, new_mstat, address, value)
//# define STORE(type,new_mstat,address,value) MEM("s" #type, new_mstat, address, value)
# define MSTATUS(part) (MSTATUS_ ## part)
# define REPORT_HITS(addr, size, p, hits)
# define REPORT(trap_expected, addr, size) do { if (trap_expected) exit(2); } while (0)
# define VCHECK(addr, v1, v2)              do { if (v1 != v2)      exit(4); } while (0)

uintptr_t handle_trap(uintptr_t cause, uintptr_t epc, uintptr_t regs[32])
{
  if (cause == CAUSE_ILLEGAL_INSTRUCTION)
    exit(0); // no PMP support

  if (!trap_expected || cause != CAUSE_MEM_ACCESS)
    exit(1);
  trap_expected = 0;

  if (read_csr(mtval) != trap_addr)
    exit(5);

#if !defined(EXECUTE_TEST)
  return epc + insn_len(epc);
#else
  return regs[1];
#endif
}
#else
int trap_expected;
uintptr_t trap_addr;

# define INLINE
# define SFENCE_VMA
# define LOAD(type,lock_mask,address,value)
# define STORE(type,lock_mask,address,value)
# define EXECUTE(lock_mask,address,value)
# define MSTATUS(part)             0
# define REPORT_HITS(addr, size, p, hits)                         \
  do {                                                            \
    printf("0x%x/%d in 0x%x-0x%x %d (%d)\n",                      \
           (int)(addr & 0xfff), (int) size,                       \
           (int)p.a0 & 0xfff, ((int)p.a1 - 1) & 0xfff,            \
           (int)hits);                                            \
  } while (0)
# define REPORT(trap_expected, addr, size)                        \
  do {                                                            \
    static int count = 0;                                         \
    printf("Addr: 0x%08x  Size: %d  Trap: %d (%d)\n",             \
            (int)addr & 0xfff, (int)size,                         \
            (int)trap_expected, count);                           \
    count += trap_expected;                                       \
  } while (0)
# define VCHECK(addr, v1, v2)
# define read_csr(reg)             0
# define write_csr(reg, val)
# define SATP_MODE_SV32            1
# define SATP_MODE_SV39            8
# define RISCV_PGSIZE              (4 * 1024)
# define RISCV_PGSHIFT             2
# define PTE_PPN_SHIFT             10
# define PTE_V                     0x01
# define PTE_R                     0x02
# define PTE_W                     0x04
# define PTE_A                     0x40
# define PTE_D                     0x80
# define PMP_A                     0x18
# define PMP_R                     0x01
# define PMP_W                     0x02
# define PMP_X                     0x04
# define PMP_L                     0x80
# define PMP_TOR                   (PMP_A * 1)
# define PMP_NA4                   (PMP_A * 2)
# define PMP_NAPOT                 (PMP_A * 3)
# define PMP_SHIFT                 2
#endif

volatile char cdata[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15};
volatile long tmp;

#define SCRATCH RISCV_PGSIZE
uintptr_t scratch[RISCV_PGSIZE / sizeof(uintptr_t)] __attribute__((aligned(RISCV_PGSIZE)));


#if !defined(VALUE_CHECK)
# undef VCHECK
# define VCHECK(addr, v1, v2)
#endif
#if __riscv_xlen >= 64
# define MAGIC 0xf001deadc0de50b5
#else
# define MAGIC 0xdeadc0de
#endif

#if defined(NO_MMU)
# undef  SCRATCH
# define SCRATCH ((uintptr_t)scratch)
#else
# if 0
uintptr_t l1pt[RISCV_PGSIZE / sizeof(uintptr_t)] __attribute__((aligned(RISCV_PGSIZE)));
uintptr_t l2pt[RISCV_PGSIZE / sizeof(uintptr_t)] __attribute__((aligned(RISCV_PGSIZE)));
# if __riscv_xlen >= 64
uintptr_t l3pt[RISCV_PGSIZE / sizeof(uintptr_t)] __attribute__((aligned(RISCV_PGSIZE)));
# else
#  define l3pt l2pt
# endif
# else
uintptr_t pt[4 * RISCV_PGSIZE / sizeof(uintptr_t)] __attribute__((aligned(4 * RISCV_PGSIZE)));
#  define l1pt (&pt[0])
#  define l2pt (&pt[RISCV_PGSIZE / sizeof(uintptr_t)])
# if __riscv_xlen >= 64
#  define l3pt (&pt[2 * RISCV_PGSIZE / sizeof(uintptr_t)])
# else
#  define l3pt l2pt
# endif
# endif
#endif


static void init_pmp(void)
{
  // Disable any previous PMP setup.
  write_csr(pmpcfg0, 0);
  write_csr(pmpcfg2, 0);
#if __riscv_xlen < 64
  write_csr(pmpcfg1, 0);
  write_csr(pmpcfg3, 0);
#endif
}


// Makes use of PMP 4.
static void init_pt(void)
{
#if !defined(NO_MMU)
  l1pt[0]                      = ((uintptr_t)l2pt >> RISCV_PGSHIFT << PTE_PPN_SHIFT) | PTE_V;
  l3pt[SCRATCH / RISCV_PGSIZE] = ((uintptr_t)scratch >> RISCV_PGSHIFT << PTE_PPN_SHIFT) | PTE_A | PTE_D | PTE_V | PTE_R | PTE_W;
# if __riscv_xlen >= 64
  l2pt[0]                      = ((uintptr_t)l3pt >> RISCV_PGSHIFT << PTE_PPN_SHIFT) | PTE_V;
  uintptr_t vm_choice = SATP_MODE_SV39;
# else
  uintptr_t vm_choice = SATP_MODE_SV32;
# endif
  write_csr(satp, ((uintptr_t)l1pt >> RISCV_PGSHIFT) |
                  (vm_choice * (SATP_MODE & ~(SATP_MODE << 1))));

# if 0
  // Set up PMP:s to cover page tables.
  // qqq Check for errors when page table walk misses?
  write_csr(pmpaddr4, ((uintptr_t)l1pt + (RISCV_PGSIZE / 2 - 1)) >> PMP_SHIFT);
  write_csr(pmpaddr5, ((uintptr_t)l2pt + (RISCV_PGSIZE / 2 - 1)) >> PMP_SHIFT);
  write_csr(pmpaddr6, ((uintptr_t)l3pt + (RISCV_PGSIZE / 2 - 1)) >> PMP_SHIFT);
#  if __riscv_xlen >= 64
  write_csr(pmpcfg0,  (uintptr_t)(PMP_NAPOT | PMP_R) << (4 * 8) |
                      (uintptr_t)(PMP_NAPOT | PMP_R) << (5 * 8) |
                      (uintptr_t)(PMP_NAPOT | PMP_R) << (6 * 8));
#  else
  write_csr(pmpcfg1,  (uintptr_t)(PMP_NAPOT | PMP_R) << (0 * 8) |
                      (uintptr_t)(PMP_NAPOT | PMP_R) << (1 * 8) |
                      (uintptr_t)(PMP_NAPOT | PMP_R) << (2 * 8));
#  endif
# else
  // Set up PMP to cover page tables.
  // qqq Check for errors when page table walk misses?
  write_csr(pmpaddr4, ((uintptr_t)pt + (4 * RISCV_PGSIZE / 2 - 1)) >> PMP_SHIFT);
#  if __riscv_xlen >= 64
  write_csr(pmpcfg0,  (uintptr_t)(PMP_NAPOT | PMP_R) << (4 * 8));
#  else
  write_csr(pmpcfg1,  (uintptr_t)(PMP_NAPOT | PMP_R) << (0 * 8));
#  endif
# endif
#endif
}


// Makes use of PMP 5-6.
// Sets up 3.
// (1-2 are used by tests.)
static void config_pmp(void)
{
  uintptr_t cfg;

  // Prepare scratch catch-all for later tests, but do not activate.
//  write_csr(pmpaddr3, -1);
  write_csr(pmpaddr3, ((uintptr_t)scratch + (RISCV_PGSIZE / 2 - 1)) >> PMP_SHIFT);

#if defined(MMODE)
  // Prepare high priority catch-all for verification, but do not activate.
  write_csr(pmpaddr0, -1);
#endif

  // Set up medium priority no-access PMP to cover scratch area.
  write_csr(pmpaddr5, ((uintptr_t)scratch + (RISCV_PGSIZE / 2 - 1)) >> PMP_SHIFT);
#if __riscv_xlen >= 64
  cfg = read_csr(pmpcfg0);
# if !defined(MMODE)
  write_csr(pmpcfg0,  cfg | (uintptr_t)(PMP_NAPOT) << (5 * 8));
# else
  write_csr(pmpcfg0,  cfg | (uintptr_t)(PMP_L | PMP_NAPOT) << (5 * 8));
# endif
#else
  cfg = read_csr(pmpcfg1);
# if !defined(MMODE)
  write_csr(pmpcfg1,  cfg | (uintptr_t)(PMP_NAPOT) << (1 * 8));
# else
  write_csr(pmpcfg1,  cfg | (uintptr_t)(PMP_L | PMP_NAPOT) << (1 * 8));
# endif
#endif

#if 1 //defined(MMODE)
  // Set up low priority catch-all.
  // Relies on a higher priority no-catch for area of interest (see main()).
  write_csr(pmpaddr6, -1);
# if __riscv_xlen >= 64
  cfg = read_csr(pmpcfg0);
  write_csr(pmpcfg0, cfg | (uintptr_t)(PMP_L | PMP_NAPOT | PMP_X | PMP_R | PMP_W) << (6 * 8));
# else
  cfg = read_csr(pmpcfg1);
  write_csr(pmpcfg1, cfg | (uintptr_t)(PMP_L | PMP_NAPOT | PMP_X | PMP_R | PMP_W) << (2 * 8));
# endif
#endif

#if defined(MMODE)
  // Make it possible to clear lock bits (Gaisler special).
  uintptr_t en = read_csr(0x7c0);    // dfeaturesen
  write_csr(0x7c0, en | UNLOCKABLE);
#endif
}


INLINE uintptr_t va2pa(uintptr_t va)
{
  if (va < SCRATCH || va >= SCRATCH + RISCV_PGSIZE)
    exit(3);
  return va - SCRATCH + (uintptr_t)scratch;
}


#define GRANULE (1UL << PMP_SHIFT)

typedef struct {
  uintptr_t cfg;
  uintptr_t a0;
  uintptr_t a1;
} pmpcfg_t;

INLINE uintptr_t pmp_hits(const pmpcfg_t p, uintptr_t addr, uintptr_t size)
{
  pmpcfg_t q = p;
  if ((p.cfg & PMP_A) == 0)
    return 1;

  if ((p.cfg & PMP_A) != PMP_TOR) {
    uintptr_t range = 1;

    if ((p.cfg & PMP_A) == PMP_NAPOT) {
      range <<= 1;
      for (uintptr_t i = 1; i; i <<= 1) {
        if ((p.a1 & i) == 0)
          break;
        q.a1 &= ~i;
        range <<= 1;
      }
    }

    q.a0 = q.a1;
    q.a1 = q.a0 + range;
  }

  q.a0 *= GRANULE;
  q.a1 *= GRANULE;
  addr = va2pa(addr);

//  printf("Hits 0x%x-0x%x  0x%x %d\n", (int)q.a0, (int)q.a1, (int)addr, (int)size);
//  printf("");
  uintptr_t hits = 0;
  for (uintptr_t i = 0; i < size; i += GRANULE) {
    if (q.a0 <= addr + i && addr + i < q.a1)
      hits += GRANULE;
  }

  REPORT_HITS(addr, size, p, hits);

  return hits;
}


INLINE int pmp_ok(const pmpcfg_t p, uintptr_t addr, uintptr_t size)
{
  return pmp_hits(p, addr, size) >= size;
}


INLINE int pmp_ok_or_miss(const pmpcfg_t p, uintptr_t addr, uintptr_t size)
{
  uintptr_t hits = pmp_hits(p, addr, size);

  return hits == 0 || hits >= size;
}


#if defined(READ_TEST)
INLINE uintptr_t test_one(uintptr_t addr, uintptr_t size)
{
#if !defined(MMODE)
  uintptr_t new_csr = (read_csr(mstatus) & ~MSTATUS(MPP)) | (MSTATUS(MPP) & (MSTATUS(MPP) >> 1)) | MSTATUS(MPRV);
#else
  uintptr_t new_csr = (PMP_L << 8) | (PMP_L << 16) | ((uintptr_t)PMP_L << 24);
#endif
  uintptr_t value       = MAGIC;
  switch (size) {
    case 1: LOAD(bu, new_csr, addr, value); break;
    case 2: LOAD(hu, new_csr, addr, value); break;
#if __riscv_xlen >= 64
    case 4: LOAD(wu, new_csr, addr, value); break;
    case 8: LOAD(d,  new_csr, addr, value); break;
#else
    case 4: LOAD(w,  new_csr, addr, value); break;
#endif
    default: __builtin_unreachable();
  }

  return value;
}
#elif defined(WRITE_TEST)
INLINE uintptr_t test_one(uintptr_t addr, uintptr_t size)
{
#if !defined(MMODE)
  uintptr_t new_csr = (read_csr(mstatus) & ~MSTATUS(MPP)) | (MSTATUS(MPP) & (MSTATUS(MPP) >> 1)) | MSTATUS(MPRV);
#else
uintptr_t new_csr = (PMP_L << 8) | (PMP_L << 16) | ((uintptr_t)PMP_L << 24);
#endif
#if __riscv_xlen >= 64
  // MMIX random according to Wikipedia.
  uintptr_t value       = write_value = write_value * 6364136223846793005 + 1442695040888963407;
#else
  // Numerical Recipes random according to Wikipedia.
  uintptr_t value       = write_value = write_value * 1664525 + 1013904223;
#endif
  switch (size) {
    case 1: STORE(b, new_csr, addr, value); return value & 0xff;
    case 2: STORE(h, new_csr, addr, value); return value & 0xffff;
    case 4: STORE(w, new_csr, addr, value); return value & 0xffffffff;
#if __riscv_xlen >= 64
    case 8: STORE(d, new_csr, addr, value); return value;
#endif
    default: __builtin_unreachable();
  }
}
#else
INLINE uintptr_t test_one(uintptr_t addr, uintptr_t size)
{
#if !defined(MMODE)
  uintptr_t new_csr = (read_csr(mstatus) & ~MSTATUS(MPP)) | (MSTATUS(MPP) & (MSTATUS(MPP) >> 1)) | MSTATUS(MPRV);
#else
  uintptr_t new_csr = (PMP_L << 8) | (PMP_L << 16) | ((uintptr_t)PMP_L << 24);
#endif
  uintptr_t value       = MAGIC;
  EXECUTE(new_csr, addr, value); return value;
}
#endif


INLINE uintptr_t read_scratch(uintptr_t addr, uintptr_t size)
{
#if defined(MMODE)
  uintptr_t cfg = read_csr(pmpcfg0);
  write_csr(pmpcfg0, cfg | (PMP_L | PMP_NAPOT | PMP_X | PMP_R | PMP_W));
#endif

#if 0
  uintptr_t value = 0;
  for(int i = 0; i < size; i++) {
    value |= ((addr + i) & 0xff) << (8 * i);
  }

  return value;
#else
  addr = addr - SCRATCH + (uintptr_t)scratch;
  uintptr_t value;
  switch (size) {
  case 1: value = *(uint8_t  *)addr; break;
  case 2: value = *(uint16_t *)addr; break;
  case 4: value = *(uint32_t *)addr; break;
#if __riscv_xlen >= 64
  case 8: value = ((uint64_t)*(uint32_t *)(addr + 4) << 32) | *(uint32_t *)addr; break;
#endif
  }
#endif

#if defined(MMODE)
  write_csr(pmpcfg0, cfg);
#endif

  return value;
}


// Verify correct behavior for all access sizes at addr.
INLINE void test_all_sizes(const pmpcfg_t p, uintptr_t addr,
                           int (*ok)(const pmpcfg_t, uintptr_t, uintptr_t))
{
#if !defined(EXECUTE_TEST)
  for (size_t size = 1; size <= sizeof(uintptr_t); size *= 2) {
    if (addr & (size - 1))
      continue;
    size_t offset = 0;
    int expect_fail = trap_expected = !ok(p, addr, size);
#elif defined(COMPRESSED)
  if (addr & (2 - 1))
    return;
  size_t size = 0;
  for (size_t offset = 0; offset <= 2; offset += 2) {
    int expect_fail = trap_expected = !ok(p, (addr + offset) & ~7, 8);
#else
  if (addr & (4 - 1))
    return;
  size_t offset = 0, size = 0;
  {
    int expect_fail = trap_expected = !ok(p, addr & ~7, 8);
#endif
    uintptr_t expected = MAGIC;
#if defined(READ_TEST) || defined(EXECUTE_TEST)
    if (!expect_fail)   // Should we really read?
#elif defined(WRITE_TEST)
    if (expect_fail)    // Should we not write?
#endif
#if !defined(EXECUTE_TEST)
      expected = read_scratch(addr, size);  // Original memory value.
#else
      expected = MAGIC + 1;
#endif
    test_count++;
    trap_count += trap_expected;
    trap_addr = addr + offset;
    uintptr_t value = test_one(addr + offset, size); // Returns value read/written.
    REPORT(trap_expected, addr + offset, size);
#if defined(WRITE_TEST)
    if (!expect_fail)
      expected = read_scratch(addr, size);  // What was, hopefully, written.
    else
      value = read_scratch(addr, size);     // Hopefully unchanged.
#endif
#if !defined(EXECUTE_TEST)
    VCHECK(addr, value, expected);
#endif
  }
}


// Verify correct behavior for all access sizes at addr.
INLINE void test_all_sizes_before(const pmpcfg_t p, uintptr_t addr)
{
  // Expect all to fail since at least part outside.
  test_all_sizes(p, addr, pmp_ok);

  // Catch-all - Allow read from all of scratch via pmp2 (see config_pmp()).
  uintptr_t cfg0 = read_csr(pmpcfg0);
  write_csr(pmpcfg0, (((uintptr_t)(PMP_NAPOT | PMP_FLAGS) << 24) & 0xff000000LL) | (cfg0 & ~0xff000000LL));
  SFENCE_VMA;

  // Expect all except double word to be fine since they hit the catch-all.
  // Double word should still fail, since it will hit both but will
  // not fit in the first (original) one!
  test_all_sizes(p, addr, pmp_ok_or_miss);

  // Disable catch-all
  write_csr(pmpcfg0, cfg0);
  SFENCE_VMA;
}


// Test from base to (base + n * GRANULE), where n * GRANULE < range.
// Also test at n=-1, n=-2 and n=range/GRANULE, when appropriate.
//INLINE void test_range_once(const pmpcfg_t p, uintptr_t base, uintptr_t range)
INLINE void test_range_once(const pmpcfg_t p, uintptr_t bottom, uintptr_t top, uintptr_t base, uintptr_t range)
{
  for (uintptr_t addr = base; addr < base + range; addr += GRANULE)
    test_all_sizes(p, addr, pmp_ok);

  // Test that accesses fail just outside the range.
  if (base + range <= top - 2 * GRANULE) test_all_sizes(p, base + range, pmp_ok);
  if (base - 2 * GRANULE >= bottom)      test_all_sizes(p, base - 2 * GRANULE, pmp_ok);

  // If range is not double word aligned, such accesses from one word before are
  // supposed to fail due to the first part being outside (example in arch doc).
  // Shorter accesses do not hit this range at all, but might hit another.
  if (base -     GRANULE >= bottom)      test_all_sizes_before(p, base - GRANULE);
}


INLINE pmpcfg_t set_pmp(const pmpcfg_t p)
{
//  printf("PMP 0x%x 0x%x 0x%x\n", (int)p.cfg, (int)p.a0 * 4, (int)p.a1 * 4);
  uintptr_t cfg0 = read_csr(pmpcfg0);
  write_csr(pmpcfg0, cfg0 & ~0xff0000);
  write_csr(pmpaddr1, p.a0);
  write_csr(pmpaddr2, p.a1);
  write_csr(pmpcfg0, ((p.cfg << 16) & 0xff0000) | (cfg0 & ~0xff0000));
  SFENCE_VMA;
  return p;
}


INLINE pmpcfg_t set_pmp_range(uintptr_t base, uintptr_t range)
{
  pmpcfg_t p;
  p.cfg = PMP_TOR | PMP_FLAGS;
  p.a0 = base >> PMP_SHIFT;
  p.a1 = (base + range) >> PMP_SHIFT;
  return set_pmp(p);
}


INLINE pmpcfg_t set_pmp_napot(uintptr_t base, uintptr_t range)
{
  pmpcfg_t p;
  p.cfg = PMP_FLAGS | (range > GRANULE ? PMP_NAPOT : PMP_NA4);
  p.a0 = 0;
  p.a1 = (base + (range/2 - 1)) >> PMP_SHIFT;
  return set_pmp(p);
}


// Test with TOR, and with NAPOT if range is 2^n and addr is aligned to range.
//static void test_range(uintptr_t addr, uintptr_t range)
static void test_range(uintptr_t bottom, uintptr_t top, uintptr_t addr, uintptr_t range)
{
#if defined(G) && G
  const int align_mask = (1 << (G + 2)) - 1;
  if ((addr & align_mask) || (range & align_mask))
    return;
#endif

#if !defined(NO_TOR)
  pmpcfg_t p = set_pmp_range(va2pa(addr), range);
  test_range_once(p, bottom, top, addr, range);
#else
  pmpcfg_t p;
#endif

  if ((range & (range - 1)) == 0 && (addr & (range - 1)) == 0) {
    p = set_pmp_napot(va2pa(addr), range);
    test_range_once(p, bottom, top, addr, range);
  }
}


// Test from addr to (addr + n * GRANULE), where n * GRANULE <= size.
//static void test_ranges(uintptr_t addr, uintptr_t size)
static void test_ranges(uintptr_t bottom, uintptr_t addr, uintptr_t size)
{
  for (uintptr_t range = GRANULE; range <= size; range += GRANULE)
    test_range(bottom, bottom + size, addr, range);
}


// Test from (addr + n * GRANULE) to (addr + size), where n * GRANULE < size.
static void exhaustive_test(uintptr_t addr, uintptr_t size)
{
  for (uintptr_t base = addr; base < addr + size; base += GRANULE)
    test_ranges(addr, base, size - (base - addr));
}


#if 0
//volatile char *buf = (void *)(SCRATCH + 0x40);
volatile char buf[128];
#endif
#if 0
  uintptr_t a[512], b[512], c[512];
//  int a[512], b[512], c[512];
#endif
int main(void)
{
  static uintptr_t dummy = (uintptr_t)exhaustive_test;
  int value;
#if 0
  SFENCE_VMA;
#if 0
  write_csr(0x7c0, 0x02007f);
  write_csr(pmpaddr0, -1);
  write_csr(pmpcfg0, 0x9c);
  write_csr(0x7c0, 0x02027f);
//  value = *(volatile uint32_t *)0;   // CCR
  value = *(volatile uint32_t *)8;   // I$ config
  value = *(volatile uint32_t *)12;   // D$ config
  write_csr(0x7c0, 0x02017f);
#endif
# if 0
  asm volatile (//"csrc 0x7c0, 2;"
                "1: mv s0, %1;"
                "nop;"
                "nop;"
                "nop;"
                "nop;"
                "nop;"
                "nop;"
                "nop;"
//                "li sp, %0;"
                "sd s0, 0(sp);"
                "sd ra, 0(sp);"
                "lui s1, 0x4002e;"
                "addi s1, s1, -1640;"
//                "1: addi s0, s0, 0;"
                "addi s0, s0, -1752;"
                "beq s1, s0, 1b;"
                "ld a5, 0(s0);"
                "addi s0, s0, 8;"
                "jalr ra, 0(a5);"
                "addi s0, s0, 7;"
                "beq s3, zero, 2f;"
                "nop;"
                "nop;"
                "nop;"
                "nop;"
                "nop;"
                "2: nop;"
                : "+&r" (value)
//                : "r" (exhaustive_test));
                : "r" (&dummy + 1752 / 8));
# elif 1
  asm volatile ("mv s0, %1;"
                "lw s1, 0(s0);"
                "sw s1, 0(s0);"
                : "+&r" (value)
//                : "r" (exhaustive_test));
                : "r" (&dummy));
# else
  asm volatile ("li s0, 1;"
//                "nop;"
                "1: addi s0, s0, 1;"
                "addi s0, s0, 1;"
                "addi s0, s0, 1;"
                "addi s0, s0, 1;"
                "addi s0, s0, 1;"
                "addi s0, s0, 1;"
                "addi s0, s0, 1;"
                "addi s0, s0, 1;"
                "addi s0, s0, 1;"
                "addi s0, s0, 1;"
                "addi s0, s0, 1;"
                "addi s0, s0, 1;"
                "bne s1, x0, 1b;"
                : "+&r" (value)
//                : "r" (exhaustive_test));
                : "r" (&dummy));
# endif
#endif
  // Disable all extensions (including FP), and set initial protection state.
  // This makes it more likely that different implementations get exactly the
  // same contents in mstatus from here on.
  uintptr_t new_mstatus = read_csr(mstatus) &
                          ~(MSTATUS(MXR) | MSTATUS(SUM) | MSTATUS(MPRV) | MSTATUS(MPP) | MSTATUS(SPP) |
                            MSTATUS(FS) | MSTATUS(XS));
  write_csr(mstatus, new_mstatus);
  init_pmp();
  init_pt();

#if !defined(SHORT)
//  SFENCE_VMA;  // For changing alignment.

#if defined(VALUE_CHECK)
  for(int i = 0; i < RISCV_PGSIZE; i++) {
    ((uint8_t *)scratch)[i] = i & 0xff;
  }
#elif defined(EXECUTE_TEST)
  for(int i = 0; i < RISCV_PGSIZE / 4; i += 2) {
//    ((volatile uint32_t *)scratch)[i]     = 0x00000013; // nop
//    ((volatile uint32_t *)scratch)[i]     = 0x00150513; // addi a0, a0, 1
#if !defined(COMPRESSED)
    ((volatile uint32_t *)scratch)[i]     = 0x00050513 | (i * 65536 * 16); // addi a0, a0, i
    ((volatile uint32_t *)scratch)[i + 1] = 0x00008067; // jalr x0, 0(ra)  ie ret
#else
    int l = i & 0x3f;
    int h = (i >> 6) & 0x3f;
    if (h == 0)
      ((volatile uint16_t *)scratch)[i * 2]   = 0x4501; // c.li a0, 0
    else
      ((volatile uint16_t *)scratch)[i * 2]   = 0x6501 | (((h & 0x20) << 12) | ((h & 0x1f) << 2)); // c.lui a0, (h & 0x3f)
    ((volatile uint16_t *)scratch)[i * 2 + 1] = 0x8119; // c.srli a0, 6
    ((volatile uint16_t *)scratch)[i * 2 + 2] = 0x0501 | (((l & 0x20) << 12) | ((l & 0x1f) << 2)); // c.addi a0, (l & 0x3f)
    ((volatile uint16_t *)scratch)[i * 2 + 3] = 0x8082; // c.jr ra  ie ret
#endif
  }
#endif

  config_pmp();

#if 0
  for(int i = 0; i < 100; i++) {
    a[i] = (b[i] + 1234567890) * 1234567890 / 987654321LL;
  }
#elif 0
  for(int i = 0; i < 100; i += 2) {
    a[i] = b[i] + c[i];
    a[i + 1] = b[i + 1] + c[i + 1];
  }
#elif 0
  for(int i = 0; i < 100; i++) {
    l1pt[i] = l2pt[i] + l3pt[i];
  }
#elif 0
  *(volatile long *)&cdata[0] = 0x7766554433221100L;
  *(volatile long *)&cdata[8] = 0xffeeddccbbaa9988L;
  cdata[2] = 2;
  cdata[7] = 7;
  cdata[8] = 8;
  cdata[13] = 13;
  tmp = cdata[2];
  tmp = cdata[7];
  tmp = cdata[8];
  tmp = cdata[13];
#elif 0
  tmp = *(volatile short *)&cdata[2];
  tmp = *(volatile short *)&cdata[6];
  tmp = *(volatile short *)&cdata[8];
  tmp = *(volatile short *)&cdata[12];
#elif 0
  tmp = *(volatile int *)&cdata[4];
  tmp = *(volatile int *)&cdata[12];
  tmp = *(volatile int *)&cdata[0];
  tmp = *(volatile int *)&cdata[8];
#elif 0
  {
    int i;
    for(i = 0; i < 16; i++) {
      cdata[i] = i + i * 16;
    }
  }
  cdata[1] = 42;
  SFENCE_VMA;
  tmp = cdata[1];
  tmp = *(volatile char *)&cdata[0];
  tmp = *(volatile char *)&cdata[1];
  tmp = *(volatile char *)&cdata[9];
  tmp = *(volatile char *)&cdata[11];
  tmp = *(volatile int *)&cdata[4];
  tmp = *(volatile int *)&cdata[12];
  tmp = *(volatile int *)&cdata[0];
  tmp = *(volatile int *)&cdata[8];
  tmp = *(volatile long *)&cdata[8];
  tmp = *(volatile long *)&cdata[0];
#elif 0
  ((volatile int  *)buf)[ 0] = trap_expected;
  ((volatile int  *)buf)[ 0] = 1;
  trap_expected              = 42;
  ((volatile int  *)buf)[ 1] = 2;
  ((volatile int  *)buf)[ 2] = 3;
  ((volatile int  *)buf)[ 3] = ((volatile int  *)buf)[ 0];
  ((volatile int  *)buf)[ 4] = ((volatile int  *)buf)[ 1];
  ((volatile int  *)buf)[ 5] = trap_expected;
  ((volatile long *)buf)[ 0] = 0x0011223344556677;
  ((volatile long *)buf)[ 1] = 0x8899aabbccddeeff;
  ((volatile char *)buf)[16] = ((volatile char *)buf)[ 6];
  ((volatile char *)buf)[17] = ((volatile char *)buf)[ 4];
  ((volatile char *)buf)[18] = ((volatile char *)buf)[ 3];
  ((volatile char *)buf)[19] = ((volatile char *)buf)[ 1];
  ((volatile char *)buf)[20] = ((volatile char *)buf)[15];
  ((volatile char *)buf)[21] = ((volatile char *)buf)[13];
  ((volatile char *)buf)[22] = ((volatile char *)buf)[10];
  ((volatile char *)buf)[23] = ((volatile char *)buf)[ 8];
  ((volatile int  *)buf)[ 6] = ((volatile int  *)buf)[ 4];
  ((volatile int  *)buf)[ 7] = ((volatile int  *)buf)[ 5];
  ((volatile long *)buf)[ 4] = ((volatile long *)buf)[ 1];
  ((volatile long *)buf)[ 5] = ((volatile long *)buf)[ 0];
#endif

#if !defined(QUICK)
  const int max_exhaustive = 32;
#else
  const int max_exhaustive = 16;
#endif
#if !defined(QUICKEST)
  exhaustive_test(SCRATCH, max_exhaustive);
  exhaustive_test(SCRATCH + RISCV_PGSIZE - max_exhaustive, max_exhaustive);

# if !defined(QUICK)
  test_range(SCRATCH, SCRATCH + RISCV_PGSIZE,
             SCRATCH, RISCV_PGSIZE);
# else
  test_range(SCRATCH, SCRATCH + RISCV_PGSIZE,
             SCRATCH, 256);
  test_range(SCRATCH, SCRATCH + RISCV_PGSIZE,
             SCRATCH + RISCV_PGSIZE - 256, 256);
# endif
# if !defined(QUICK)
  test_range(SCRATCH, SCRATCH + RISCV_PGSIZE / 2 + 2 * GRANULE,
             SCRATCH, RISCV_PGSIZE / 2);
# else
  test_range(SCRATCH, SCRATCH + RISCV_PGSIZE / 2 + 2 * GRANULE,
             SCRATCH, 256);
  test_range(SCRATCH, SCRATCH + RISCV_PGSIZE / 2 + 2 * GRANULE,
             SCRATCH + RISCV_PGSIZE / 2 - 256, 256);
# endif
#endif
#if !defined(QUICK)
  test_range(SCRATCH + RISCV_PGSIZE / 2 - 2 * GRANULE, SCRATCH + RISCV_PGSIZE - 2 * GRANULE,
             SCRATCH + RISCV_PGSIZE / 2, RISCV_PGSIZE / 2);
#else
  test_range(SCRATCH + RISCV_PGSIZE / 2 - 2 * GRANULE, SCRATCH + RISCV_PGSIZE - 2 * GRANULE,
             SCRATCH + RISCV_PGSIZE / 2, 256);
  test_range(SCRATCH + RISCV_PGSIZE / 2 - 2 * GRANULE, SCRATCH + RISCV_PGSIZE - 2 * GRANULE,
             SCRATCH + RISCV_PGSIZE - 256, 256);
#endif

#if defined(DESKTOP)
  printf("Tests: %d  Traps: %d\n", test_count, trap_count);
#endif

#if !defined(DESKTOP)
 asm volatile ("mv s1, %0; "
               "mv s2, %1;"
               "mv s3, %2;"
               : "+&r" (test_count),
                 "+r"  (test_count)
               : "r"   (trap_count));

  if ((test_count != TEST_NO) || (trap_count != TRAP_NO)) {
//    exit(trap_count);
  }
#endif

#endif

  return 0;
}
