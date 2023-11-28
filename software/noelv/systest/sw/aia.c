
//#include <stdlib.h>
#include <stdio.h>
#include "testmod.h"
#include "aia.h"

#ifdef NOELV_SYSTEST
#  include "bcc/bcc.h"
#else
#  include "irqmp.h"
#endif


// Parameters maximum possible values
// Used to define the structures containing the
// pointers pointing to the slaves' registers
#define MAX_DOM      10
#define MAX_SRC      64
#define MAX_GEILEN   32


// Misa bit masks
#define S_MODE_MASK  (1 << 18)
#define H_EXT_MASK   (1 << 7)

//----------------------------------------------------------
// Global interrupts control
//----------------------------------------------------------

#define MSTATUS_UIE      1
#define MSTATUS_SIE      (1 << 1)
#define MSTATUS_HIE      (1 << 2)
#define MSTATUS_MIE      (1 << 3)

#define MSTATUS_MPIE     (1 << 7)
#define MSTATUS_MPP1     (1 << 11)
#define MSTATUS_MPP2     (1 << 12)
#define MSTATUS_MPV      ((uint64_t) (1) << 39)

#define SSTATUS_SPP      (1 << 8)
#define HSTATUS_SPV      (1 << 7)

#define IRQ_S_SOFT       1
#define IRQ_H_SOFT       2
#define IRQ_M_SOFT       3
#define IRQ_S_TIMER      5
#define IRQ_H_TIMER      6
#define IRQ_M_TIMER      7
#define IRQ_S_EXT        9
#define IRQ_H_EXT        10
#define IRQ_M_EXT        11
#define IRQ_COP          12
#define IRQ_HOST         13

#define MIP_SSIP         (1 << IRQ_S_SOFT)
#define MIP_HSIP         (1 << IRQ_H_SOFT)
#define MIP_MSIP         (1 << IRQ_M_SOFT)
#define MIP_STIP         (1 << IRQ_S_TIMER)
#define MIP_HTIP         (1 << IRQ_H_TIMER)
#define MIP_MTIP         (1 << IRQ_M_TIMER)
#define MIP_SEIP         (1 << IRQ_S_EXT)
#define MIP_HEIP         (1 << IRQ_H_EXT)
#define MIP_MEIP         (1 << IRQ_M_EXT)

#define MIE_SSIE         (1 << IRQ_S_SOFT)
#define MIE_HSIE         (1 << IRQ_H_SOFT)
#define MIE_MSIE         (1 << IRQ_M_SOFT)
#define MIE_STIE         (1 << IRQ_S_TIMER)
#define MIE_HTIE         (1 << IRQ_H_TIMER)
#define MIE_MTIE         (1 << IRQ_M_TIMER)
#define MIE_SEIE         (1 << IRQ_S_EXT)
#define MIE_HEIE         (1 << IRQ_H_EXT)
#define MIE_MEIE         (1 << IRQ_M_EXT)




// TRAP HANDLER
#define MTVEC_MODE_DIRECT     0x00
#define MTVEC_MODE_VECTORED   0x01
#define MCAUSE_INT_MASK       0x8000000000000000
#define MCAUSE_CODE_MASK      0x7FFFFFFFFFFFFFFF
#define M_SOFTWARE_INT        3
#define S_SOFTWARE_INT        1
#define M_TIMER_INT           7
#define M_EXTERNAL_INT        11
#define S_EXTERNAL_INT        9
#define VS_EXTERNAL_INT       10


//----------------------------------------------------------
// CSR instructions
//----------------------------------------------------------

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



//----------------------------------------------------------
// IMSIC
//----------------------------------------------------------

// IMSIC interrupt files
#define MACHINE_BASE_OFF                     0x00000000
#define SUPERVISOR_BASE_OFF                  0x00000000
#define PAGE_SIZE                            0x00001000

// INDIRECTLY ACCESSED REGISTERS
#define EIDELIVERY                          0x70
#define EITHRESHOLD                         0x72
#define EIP_BASE                            0x80
#define EIE_BASE                            0xC0



//----------------------------------------------------------
// APLIC
//----------------------------------------------------------

#define DOMAIN_SIZE            0x8000

// Domain offsets
#define DOMAINCFG_OFF          0x0000
#define SOURCECFG_OFF          0x0004
#define MMSIADDRCFG_OFF        0x1BC0
#define MMSIADDRCFGH_OFF       0x1BC4
#define SMSIADDRCFG_OFF        0x1BC8
#define SMSIADDRCFGH_OFF       0x1BCC
#define SETIP_OFF              0x1C00
#define SETIPNUM_OFF           0x1CDC
#define IN_CLRIP_OFF           0x1D00
#define CLRIPNUM_OFF           0x1DDC
#define SETIE_OFF              0x1E00
#define SETIENUM_OFF           0x1EDC
#define CLRIE_OFF              0x1F00
#define CLRIENUM_OFF           0x1FDC
#define SETIPNUM_LE_OFF        0x2000
#define SETIPNUM_BE_OFF        0x2004
#define GENMSI_OFF             0x3000
#define TARGET_OFF             0x3004

// IDC offsets
#define IDC_SIZE               0x4000
#define IDC_CORE_OFF           0x20

#define IDELIVERY_OFF          0x00
#define IFORCE_OFF             0x04
#define ITHRESHOLD_OFF         0x08
#define TOPI_OFF               0x18
#define CLAIMI_OFF             0x1C

//----------------------------------------------------------
// ACLINT
//----------------------------------------------------------
#define MSIP_OFF               0x0000

#define MTIMECMP_OFF           0x4000
#define SSIP_OFF               0xc000
#define MTIME_OFF              0xbff8



//----------------------------------------------------------
// Global variables and constants
//----------------------------------------------------------
// Software interrupt registers
volatile uint32_t *msip_hart;
volatile uint32_t *ssip_hart;

// Timer interrupt registers
volatile uint64_t *mtimercmp_hart;
volatile uint64_t *mtimer;


// Pointers to communicate with interrupt handler 
volatile int result_core;
volatile int eiid_core;
// Set direct mode to 1 before asserting an APLIC interrupt when 
// the APLIC is configured in direct delivery mode
volatile int direct_mode;
volatile int direct_dom;
// Signals the machine mode trap handler to clear the ssip bit 
volatile int clear_ssip = 0;

// APLIC registers
struct APLIC_reg_map {
  uint32_t *domaincfg;
  uint32_t *sourcecfg[MAX_SRC+1];
  uint32_t *mmsiaddrcfg;
  uint32_t *mmsiaddrcfgh;
  uint32_t *smsiaddrcfg;
  uint32_t *smsiaddrcfgh;
  uint32_t *setip[MAX_SRC/64+1];
  uint32_t *setipnum;
  uint32_t *in_clrip[MAX_SRC/64+1];
  uint32_t *clripnum;
  uint32_t *setie[MAX_SRC/64+1];
  uint32_t *setienum;
  uint32_t *clrie[MAX_SRC/64+1];
  uint32_t *clrienum;
  uint32_t *setipnum_le;
  uint32_t *setipnum_be;
  uint32_t *genmsi;
  uint32_t *target[MAX_SRC+1];
};
volatile struct APLIC_reg_map APLICregs[MAX_DOM];

// APLIC IDC registers
typedef struct APLIC_IDC_reg_map {
  uint32_t *idelivery;
  uint32_t *iforce;
  uint32_t *ithreshold;
  uint32_t *topi;
  uint32_t *claimi;
} APLIC_IDC_reg_map;

volatile APLIC_IDC_reg_map IDCregs[MAX_DOM][1]; //only 1 cpu

// IMSIC registers
struct IMSIC_reg_map {
  uint32_t *m_seteipnum;
  uint32_t *s_seteipnum;
  uint32_t *g_seteipnum[MAX_GEILEN+1];
};
volatile struct IMSIC_reg_map IMSICregs[1]; //only 1 cpu


//----------------------------------------------------------
// Function declarations
//----------------------------------------------------------

//-- Configuration functions -------------------------------
// Initilize the structures cointining the pointers pointing
// to the registers within the memory map
void init_IMSIC_reg_map (addr_t imsic_addr, int geilen, int sbits, int vcpubits);
void init_APLIC_reg_map (addr_t aplic_addr, int domains, int sources);
void init_APLIC_IDC_reg_map(addr_t aplic_addr, int domains);

//Configure PMP
void PMPconfig(void);

// Functions to configure external interrupts
void interrupt_global_enable (void);
void interrupt_global_disable (void);
void external_interrupt_enable (void);
void software_interrupt_enable (void);
void timer_interrupt_enable (void);
void timer_interrupt_disable (void);
void M_configure_imsic (int neiid);
void S_configure_imsic (int neiid);
void VS_configure_imsic (int neiid, int vgein);

// Trap handler and different interrupt handlers
void __attribute__((weak, interrupt)) M_trap_handler();
void __attribute__ ((interrupt ("supervisor"))) __attribute__ ((weak)) S_trap_handler();
void software_interrupt_handler(void);
void timer_interrupt_handler(void);
void M_external_interrupt_handler(void);
void S_external_interrupt_handler(void);
void VS_external_interrupt_handler(void);
void M_software_interrupt_handler(void);
void S_software_interrupt_handler(void);
void M_timer_interrupt_handler(void);
//----------------------------------------------------------

//-- Test functions ----------------------------------------
int M_IMSIC_interrupt_test(int neiid);
int S_IMSIC_interrupt_test(int neiid);
int VS_IMSIC_interrupt_test(int neiid, int vgein);
int APLIC_MSI_interrupt_test(int domains, int sources);
int APLIC_direct_interrupt_test(int domains, int sources);
int M_software_interrupt_test(void);
int S_software_interrupt_test(void);
int timer_interrupt_test(void);
//----------------------------------------------------------

//-- Auxiliar functions ------------------------------------
// Sets VGEIN
void setVGEIN(int vgein);
// Functions to change the priviledge mode
void __attribute__ ((noinline)) Machine2Supervisor(void);
void __attribute__ ((noinline)) Supervisor2VirtualSup(void);
// Compute the EIE and EIP addresses
int EIE(int reg);
int EIP(int reg);
// Calculates the number of required bits to store a maximum 
// value
int bits_number(int value);
// It gives time to the interrupt to reach the pipeline and 
// be traped
void waitForInterrupt(int delay);
//----------------------------------------------------------


//----------------------------------------------------------
// Test
//----------------------------------------------------------

int aia_test(addr_t aclint_addr, addr_t imsic_addr, addr_t aplic_addr, int cpus, 
             int geilen, int domains, int lite, int smstateen, int smrnmi) {

  int i;
  uint64_t hvitcl ;

  int s_mode, h_ext;

  uint32_t mode = MTVEC_MODE_DIRECT;
  uintptr_t mtvec_base;
  uintptr_t stvec_base;

  // Check if Supervisor mode and Hypervisor extensions are enabled
  s_mode = read_csr(misa) & S_MODE_MASK;
  h_ext  = read_csr(misa) & H_EXT_MASK;

  // Pointers to software interrupt registers
  msip_hart = (uint32_t *) (aclint_addr + MSIP_OFF);
  ssip_hart = (uint32_t *) (aclint_addr + SSIP_OFF);
  
  // Pointers to timer interrupt registers
  mtimercmp_hart = (uint64_t *) (aclint_addr + MTIMECMP_OFF);
  mtimer = (uint64_t *) (aclint_addr + MTIME_OFF);

  int ncpubits, vcpubits, sbits;
  int sources, neiid;
  
  report_device(0x010CD000);
  report_device(0x010CE000);
  report_device(0x010CF000);
  
  ncpubits = bits_number(cpus);
  vcpubits = bits_number(geilen+1);
  sbits = ncpubits+vcpubits+12;

  
  // If lite version was chosen, only the first source
  // for the APLIC and the first external interrupt identity
  // are tried
  if (lite == 1) {
    sources = 1;
    neiid = 1;
  } else {
    sources = 5;
    neiid = 5;
  }

  if (smstateen == 1) {
    //Set AIA realted bits of mstateen0 and hstateen0 to 1
    set_csr(0x30c, ((uint64_t) 1 << 63) | ((uint64_t) 0b111 << 58) );
    set_csr(0x60c, ((uint64_t) 0b111 << 58));
  }

  if (smrnmi == 1) {
    //Set mnstatus nmie to 1 to enable interrupts
    set_csr(0x744, 1 << 3);
  }


  // PMP has to be configured to allow other modes different
  // than machine mode to access memory
  PMPconfig();


  // Initialize pointers to IMSIC and APLIC registers
  init_IMSIC_reg_map(imsic_addr, geilen, sbits, vcpubits);
  init_APLIC_reg_map (aplic_addr, domains, sources);
  init_APLIC_IDC_reg_map(aplic_addr, domains);

  // -- Configure external interrupts --------------------------------
  /* Write disable all interrupts prior to setup */
  interrupt_global_disable();

  // Set the trap handler routines
  // Set the interrupt mode as direct mode
  mtvec_base = (uintptr_t) &M_trap_handler;
  stvec_base = (uintptr_t) &S_trap_handler;
  write_csr(mtvec,  (mtvec_base | mode));
  write_csr(stvec,  (stvec_base | mode));
  write_csr(0x205, (stvec_base | mode)); //vstvec

  // Enable external interrupts
  external_interrupt_enable();

  // Enable software interrupts
  software_interrupt_enable();

  // Configure IMSIC machine interrupt file
  M_configure_imsic(neiid);
  // Configure IMSIC supervisor interrupt file
  S_configure_imsic(neiid);
  // Configure the first IMSIC virtual supervisor interrupt files
  VS_configure_imsic(neiid,1);

  // Enable global interrupts
  interrupt_global_enable();
  // -----------------------------------------------------------------

  // -- TESTS --------------------------------------------------------
  // -----------------------------------------------------------
  // -- Machine mode interrupts --------------------------------
  // -----------------------------------------------------------

  // Set APLIC direct mode to 0
  direct_mode = 0;

  report_subtest(1);
  if (M_IMSIC_interrupt_test(neiid) != 1) {
    fail(12);
  }

  report_subtest(2);
  if (APLIC_MSI_interrupt_test(domains, sources) != 1) {
    fail(13);
  }
  
  report_subtest(3);
  if (M_software_interrupt_test() != 1) {
    fail(14);
  }
  


  report_subtest(4);
  if (timer_interrupt_test() != 1) {
    fail(15);
  }

  if (s_mode) {
    report_subtest(5);
    if (S_IMSIC_interrupt_test(neiid) != 1) {
      fail(16);
    }

    report_subtest(6);
    if (S_software_interrupt_test() != 1) {
      fail(17);
    }
  }

  // Set the EIDELIVERY IMSIC register to deliver and handle the 
  // interrupts directly from the APLIC
  write_csr(0x350, EIDELIVERY);            
  write_csr(0x351, 0x40000000);
  write_csr(0x150, EIDELIVERY);            
  write_csr(0x151, 0x40000000);

  report_subtest(7);
  if (APLIC_direct_interrupt_test(domains, sources) != 1) {
    fail(18);
  }


  if (s_mode) {
    // -----------------------------------------------------------
    // -- Supervisor mode interrupts -----------------------------
    // -----------------------------------------------------------
    // Configure eidelivery from the supervisor interrupt file to deliver
    // interrupts from the interrupt file.
    write_csr(0x150, EIDELIVERY);            
    write_csr(0x151, 1);
    // Test in Supervisor mode:
    // * Supervisor external interrupts
    // * Supervisor software interrupts
    // * Virtual Supervisor external interrupts

    // Delegate interrupts
    set_csr(mideleg, MIE_SEIE);
    set_csr(mideleg, MIE_SSIE);
    // Virtual Supervisor external interrupts are delegated by 
    // default
    Machine2Supervisor();


    report_subtest(8);
    if (S_IMSIC_interrupt_test(neiid) != 1) {
      fail(19);
    }

    report_subtest(9);
    if (S_software_interrupt_test() != 1) {
      fail(20);
    }

    report_subtest(10);
    if (h_ext) {
      setVGEIN(1);
      if (VS_IMSIC_interrupt_test(neiid, 1) != 1) {
        fail(21);
      }
    }

    // -----------------------------------------------------------
    // -- Virtual Supervisor mode interrupts ---------------------
    // -----------------------------------------------------------

    if (h_ext) {
      // Delegate interrupts
      set_csr(0x603, MIE_HEIE); // HIDELEG (delegate VS external interrupts)
      set_csr(0x603, MIE_HSIE); // HIDELEG (delegate VS software interrupts)

      write_csr(0x609, 0); //set HVIP to 0

      setVGEIN(1);
      Supervisor2VirtualSup();
      // Enable external interrupts for VS mode
      set_csr(sstatus, MSTATUS_SIE); 
  
      report_subtest(11);
      if (VS_IMSIC_interrupt_test(neiid, 1) != 1) {
        fail(22);
      }
    }

  }

  return(0);
}




//----------------------------------------------------------
// Function definitions
//----------------------------------------------------------

void init_IMSIC_reg_map (addr_t imsic_addr, int geilen, int sbits, int vcpubits) {
  const int endianness = 0;
  int j;
  IMSICregs[0].m_seteipnum = (uint32_t *) (imsic_addr + 4*endianness + (0 << 12));
  IMSICregs[0].s_seteipnum = (uint32_t *) (imsic_addr + 4*endianness + (1 << sbits) + (0 << (vcpubits+12)));
  for(j=1 ; j<=geilen ; j++){
    IMSICregs[0].g_seteipnum[j] = (uint32_t *) (imsic_addr + 4*endianness + (1 << sbits) + (0 << (vcpubits+12)) + (j << 12));
  }
}

void init_APLIC_reg_map (addr_t aplic_addr, int domains, int sources) {
  int i, j, k;
  uint32_t DomOff, RegOff, SrcOff;
  for(i=0 ; i<domains ; i++){
    DomOff = i*DOMAIN_SIZE+aplic_addr;
    APLICregs[i].domaincfg    = (uint32_t *) (DomOff +  DOMAINCFG_OFF);
    APLICregs[i].mmsiaddrcfg  = (uint32_t *) (DomOff +  MMSIADDRCFG_OFF);
    APLICregs[i].mmsiaddrcfgh = (uint32_t *) (DomOff +  MMSIADDRCFGH_OFF);
    APLICregs[i].smsiaddrcfg  = (uint32_t *) (DomOff +  SMSIADDRCFG_OFF);
    APLICregs[i].smsiaddrcfgh = (uint32_t *) (DomOff +  SMSIADDRCFGH_OFF);
    APLICregs[i].setipnum     = (uint32_t *) (DomOff +  SETIPNUM_OFF);
    APLICregs[i].clripnum     = (uint32_t *) (DomOff +  CLRIPNUM_OFF);
    APLICregs[i].setienum     = (uint32_t *) (DomOff +  SETIENUM_OFF);
    APLICregs[i].clrienum     = (uint32_t *) (DomOff +  CLRIENUM_OFF);
    APLICregs[i].setipnum_le  = (uint32_t *) (DomOff +  SETIPNUM_LE_OFF);
    APLICregs[i].setipnum_be  = (uint32_t *) (DomOff +  SETIPNUM_BE_OFF);
    APLICregs[i].genmsi       = (uint32_t *) (DomOff +  GENMSI_OFF);
    for(j=0 ; j<(sources/64+1) ; j++){
      RegOff = j*4;
      APLICregs[i].setip[j]    = (uint32_t *) (DomOff + SETIP_OFF + RegOff);
      APLICregs[i].in_clrip[j] = (uint32_t *) (DomOff + IN_CLRIP_OFF + RegOff);
      APLICregs[i].setie[j]    = (uint32_t *) (DomOff + SETIE_OFF + RegOff);
      APLICregs[i].clrie[j]    = (uint32_t *) (DomOff + CLRIE_OFF + RegOff);
    }
    for(k=1 ; k<=sources ; k++){
      SrcOff = (k-1)*4;
      APLICregs[i].target[k]    = (uint32_t *) (DomOff + TARGET_OFF + SrcOff);
      APLICregs[i].sourcecfg[k] = (uint32_t *) (DomOff + SOURCECFG_OFF + SrcOff);
    }
  }
}


void init_APLIC_IDC_reg_map(addr_t aplic_addr, int domains) {
  int i, j, k;
  uint32_t DomOff, CoreOff;
  for(i=0 ; i<domains ; i++){
  DomOff = i*DOMAIN_SIZE+IDC_SIZE+aplic_addr;
    CoreOff = j*IDC_CORE_OFF;
    IDCregs[i][0].idelivery  = (uint32_t *) (IDELIVERY_OFF  + DomOff + CoreOff);
    IDCregs[i][0].iforce     = (uint32_t *) (IFORCE_OFF     + DomOff + CoreOff);
    IDCregs[i][0].ithreshold = (uint32_t *) (ITHRESHOLD_OFF + DomOff + CoreOff);
    IDCregs[i][0].topi       = (uint32_t *) (TOPI_OFF       + DomOff + CoreOff);
    IDCregs[i][0].claimi     = (uint32_t *) (CLAIMI_OFF     + DomOff + CoreOff);
  }
}


// Machine mode trap handler
void __attribute__((weak, interrupt)) M_trap_handler() {
  uint64_t mcause_value = read_csr(mcause);
  uint64_t int_cause = mcause_value & MCAUSE_CODE_MASK;
  uint64_t mtopi = read_csr(0xfb0) >> 16;
  // [31]=1 interrupt, else exception
  if (mcause_value & MCAUSE_INT_MASK) {
    if (int_cause == mtopi) {
      // Branch to interrupt handler here
      switch(int_cause) {
        case M_EXTERNAL_INT:
          M_external_interrupt_handler();
          break;
        case S_EXTERNAL_INT:
          S_external_interrupt_handler();
          break;
        case M_SOFTWARE_INT:        
          M_software_interrupt_handler();
          break;
        case S_SOFTWARE_INT:        
          S_software_interrupt_handler();
          break;
        case M_TIMER_INT:
          M_timer_interrupt_handler();
          break;
        default:
          break;
      }
    } else {
      fail(23);
    }
  } else {
    // It should jump here only when supervisor mode tries to 
    // disable mip.ssip to disable the supervisor software interrupt
    if (clear_ssip == 1) {
      clear_csr(mip, MIP_SSIP);
      write_csr(mepc, read_csr(mepc)+4);
      clear_ssip = 0;
    } else {
      fail(29);
    }
  }
}


// Supervisor mode trap handler
void __attribute__ ((interrupt ("supervisor"))) __attribute__ ((weak)) S_trap_handler() {
  uint64_t scause_value = read_csr(scause);
  uint64_t int_cause = scause_value & MCAUSE_CODE_MASK;
  uint64_t stopi = read_csr(0xdb0) >> 16;
  uint64_t priority = read_csr(0xdb0) & ~(0xFFFFFFFF << 16);
  // [31]=1 interrupt, else exception
  if (scause_value & MCAUSE_CODE_MASK) {
    if (int_cause == stopi) {
      // Branch to interrupt handler here
      switch(int_cause) {
        case S_EXTERNAL_INT:
          S_external_interrupt_handler();
          break;
        case VS_EXTERNAL_INT:
          VS_external_interrupt_handler();
          break;
        case S_SOFTWARE_INT:        
          S_software_interrupt_handler();
          break;
        default:
          break;
      }
    } else {
      fail(25);
    }
  } else {
    fail(26);
  }
}

// CSR addresses:
//-----------------
// miselect   0x350
// mireg      0x351
// mtopei     0x35C
//-----------------
void M_external_interrupt_handler(void) {
  int i;
  uint64_t eip_init, eip_final, mtopei_init, mtopei_final;
  int coreID;
  uint32_t claimi;

  if (direct_mode == 0) {
    // IMSIC interrupt
    // Read the corresponding EIP register and check
    // that the value coincides with the expected one
    write_csr(0x350, EIP((eiid_core/64)*2)); //Only even addresses are valid
    eip_init = read_csr(0x351);
    if (eip_init != (uint64_t) 1 << (eiid_core % 64)) {
      fail(0);
    }
    // Read the MTOPEI register and check
    // that the value coincides with the expected one
    mtopei_init = swap_csr(0x35C, 0);
    if (eiid_core != mtopei_init >> 16 || eiid_core!= (mtopei_init  & ~(0xFFFF << 16))) {
      fail(1);
    }
    // Read the corresponding EIP register and check
    // that the value is zero
    eip_final = read_csr(0x351);
    if (eip_final != 0) {
      fail(2);
    }
    // Read the MTOPEI register and check
    // that the value is zero
    mtopei_final = swap_csr(0x35C, 0);
    if (mtopei_final != 0) {
      fail(3);
    }
    if (result_core == 0)
      result_core = 1; //TEST PASSED

  } else { //APLIC direct mode
    claimi = *IDCregs[direct_dom][0].claimi;
    if (claimi >> 16 != eiid_core || (claimi & 0x000000FF) != eiid_core) {
      fail(4);
    }
    claimi = *IDCregs[direct_dom][0].claimi;
    if (claimi != 0) {
      fail(5);
    }

    if (result_core == 0)
      result_core = 2; //TEST PASSED
  }

}

// CSR addresses:
//-----------------
// siselect   0x150
// sireg      0x151
// stopei     0x15C
//-----------------
void S_external_interrupt_handler(void) {
  int i;
  uint64_t eip_init, eip_final, stopei_init, stopei_final;
  int coreID;
  uint32_t claimi;

  if (direct_mode == 0) {
    // IMSIC interrupt
    // Read the corresponding EIP register and check
    // that the value coincides with the expected one
    write_csr(0x150, EIP((eiid_core/64)*2)); //Only even addresses are valid
    eip_init = read_csr(0x151);
    if (eip_init != (uint64_t) 1 << (eiid_core % 64)) {
      fail(6);
    }
    // Read the MTOPEI register and check
    // that the value coincides with the expected one
    stopei_init = swap_csr(0x15C, 0);
    if (eiid_core != stopei_init >> 16 || eiid_core!= (stopei_init  & ~(0xFFFF << 16))) {
      fail(7);
    }
    // Read the corresponding EIP register and check
    // that the value is zero
    eip_final = read_csr(0x151);
    if (eip_final != 0) {
      fail(8);
    }
    // Read the MTOPEI register and check
    // that the value is zero
    stopei_final = swap_csr(0x15C, 0);
    if (stopei_final != 0) {
      fail(9);
    }
    if (result_core == 0)
      result_core = 1; //TEST PASSED


  } else { //APLIC direct mode
    claimi = *IDCregs[direct_dom][0].claimi;
    if (claimi >> 16 != eiid_core || (claimi & 0x000000FF) != eiid_core) {
      fail(10);
    }
    claimi = *IDCregs[direct_dom][0].claimi;
    if (claimi != 0) {
      fail(11);
    }

    if (result_core == 0)
      result_core = 2; //TEST PASSED
  }
}

// CSR addresses:
//-----------------
// vsiselect   0x250
// vsireg      0x251
// vstopei     0x25C
//-----------------
void VS_external_interrupt_handler(void) {
  int i;
  uint64_t eip_init, eip_final, vstopei_init, vstopei_final;

  // Read the corresponding EIP register and check
  // that the value coincides with the expected one
  write_csr(0x250, EIP((eiid_core/64)*2)); //Only even addresses are valid
  eip_init = read_csr(0x251);
  if (eip_init != (uint64_t) 1 << (eiid_core % 64)) {
    fail(24);
  }
  // Read the VSTOPEI register and check
  // that the value coincides with the expected one
  vstopei_init = swap_csr(0x25C, 0);
  if (eiid_core != vstopei_init >> 16 || eiid_core!= (vstopei_init  & ~(0xFFFF << 16))) {
    fail(25);
  }
  // Read the corresponding EIP register and check
  // that the value is zero
  eip_final = read_csr(0x251);
  if (eip_final != 0) {
    fail(26);
  }
  // Read the VSTOPEI register and check
  // that the value is zero
  vstopei_final = swap_csr(0x25C, 0);
  if (vstopei_final != 0) {
    fail(27);
  }
  if (result_core == 0)
    result_core = 1; //TEST PASSED
}


void M_software_interrupt_handler (void) {
  msip_hart[0] = 0;
  result_core = 1;
}

void S_software_interrupt_handler (void) {
  //This instruction will rise a illegal 
  //instruction exception. The MIP_SSIP bit will
  //be cleared inside the machine trap handler
  clear_ssip = 1;
  clear_csr(mip, MIP_SSIP);
  result_core = 1;
}

void M_timer_interrupt_handler (void) {
  timer_interrupt_disable();
  result_core = 1;
}

void interrupt_global_enable (void) {
  set_csr(mstatus, MSTATUS_MIE); 
  set_csr(mstatus, MSTATUS_SIE); //It also writes sstatus sie bit
}

void interrupt_global_disable (void) {
  clear_csr(mstatus, MSTATUS_MIE); 
  clear_csr(mstatus, MSTATUS_SIE); //It also writes sstatus sie bit
}

void external_interrupt_enable (void) {
  set_csr(mie, MIE_MEIE);  //Enable machine external interrupts 
  set_csr(mie, MIE_SEIE);  //Enable supervisor external interrupts          
  set_csr(0x604, MIE_HEIE); //HIE (VSEIE interrupts are delegated to supervisor mode by default)
}

void software_interrupt_enable (void) {
  set_csr(mie, MIE_MSIE); 
  set_csr(mie, MIE_SSIE); 
  set_csr(0x604, MIE_HSIE); //HIE (VS software interrupts)
}

void timer_interrupt_enable (void) {
  set_csr(mie, MIE_MTIE); 
}

void timer_interrupt_disable (void) {
  clear_csr(mie, MIE_MTIE); 
}

// CSR addresses:
//-----------------
// miselect   0x350
// mireg      0x351
// mtopei     0x35C
//-----------------
void M_configure_imsic (int neiid) {
  int i;
  uint64_t eidelivery_written;
  // set eidelivery to 1
  write_csr(0x350, EIDELIVERY);            
  write_csr(0x351, 1);
  // set eithreshold to 0
  write_csr(0x350, EITHRESHOLD);            
  write_csr(0x351, 0);
  // Set all IE bits to 1
  for (i=0 ; i<=(neiid/64) ; i++) {
    write_csr(0x350, EIE(i*2)); //only even addresses are valid            
    write_csr(0x351, 0xFFFFFFFFFFFFFFFF);
  }
}

// CSR addresses:
//-----------------
// siselect   0x150
// sireg      0x151
// stopei     0x15C
//-----------------
void S_configure_imsic (int neiid) {
  int i;
  uint64_t eidelivery_written;
  // set eidelivery to 1
  write_csr(0x150, EIDELIVERY);            
  write_csr(0x151, 1);
  // set eithreshold to 0
  write_csr(0x150, EITHRESHOLD);            
  write_csr(0x151, 0);
  // Set all IE bits to 1
  for (i=0 ; i<=(neiid/64) ; i++) {
    write_csr(0x150, EIE(i*2)); //only even addresses are valid            
    write_csr(0x151, 0xFFFFFFFFFFFFFFFF);
  }
}

// CSR addresses:
//-----------------
// vsiselect   0x250
// vsireg      0x251
// vstopei     0x25C
//-----------------
void VS_configure_imsic (int neiid, int vgein) {
  int i;
  uint64_t eidelivery_written;
  //configure vgein
  setVGEIN(vgein);
  // set eidelivery to 1
  write_csr(0x250, EIDELIVERY);            
  write_csr(0x251, 1);
  // set eithreshold to 0
  write_csr(0x250, EITHRESHOLD);            
  write_csr(0x251, 0);
  // Set all IE bits to 1
  for (i=0 ; i<=(neiid/64) ; i++) {
    write_csr(0x250, EIE(i*2)); //only even addresses are valid            
    write_csr(0x251, 0xFFFFFFFFFFFFFFFF);
  }
}



void setVGEIN(int vgein) {
  uint64_t prev_hstatus, new_hstatus;
  //configure vgein
  prev_hstatus = read_csr(0x600); //hstatus
  prev_hstatus = prev_hstatus & ~((uint64_t) (0b111111) << 12);
  new_hstatus = prev_hstatus | ((uint64_t) (vgein) << 12);
  write_csr(0x600, new_hstatus);
}

void PMPconfig() {
  uint64_t pmp_config = 0b01111; //A=TOR RWX=1
  uint64_t pmp_addr = 0xffffffff;
  write_csr(pmpcfg0, pmp_config);
  write_csr(pmpaddr0, pmp_addr);

}

void __attribute__ ((noinline)) Machine2Supervisor() {
  //Set mstatus.MPP to supervisor (01)
  set_csr(mstatus, MSTATUS_MPP1);
  clear_csr(mstatus, MSTATUS_MPP2); 

  __asm__ __volatile__ (
    "la t0, Machine2Supervisor_cont" "\n\t"
    "csrrw t1, mepc, t0"             "\n\t"
    "mret"                           "\n\t"
    "Machine2Supervisor_cont:"       "\n\t"
  );
}


void __attribute__ ((noinline)) Supervisor2VirtualSup (void) {
  //Set sstatus.MPP to supervisor (1)
  set_csr(sstatus, SSTATUS_SPP);
  //Set SPV to 1 to enter in virtual mode after sret
  set_csr(0x600, HSTATUS_SPV); //hstatus

  __asm__ __volatile__ (
    "la t0, Supervisor2VirtualSup_cont" "\n\t"
    "csrrw t1, sepc, t0"                "\n\t"
    "sret"                              "\n\t"
    "Supervisor2VirtualSup_cont:"       "\n\t"
  );
}

int EIE(int reg) {
  return EIE_BASE + reg;
}
int EIP(int reg) {
  return EIP_BASE + reg;
}

int bits_number(int value) {
  if (value == 0)
    return 0;
  else if (value == 1)
    return 1;
  else if (value == 2)
    return 1;
  else if (value <= 4)
    return 2;
  else if (value <= 8)
    return 3;
  else if (value <= 16)
    return 4;
  else if (value <= 32)
    return 5;
  else if (value <= 64)
    return 6;
  else if (value <= 128)
    return 7;
  else if (value <= 256)
    return 8;
  else if (value <= 512)
    return 9;
  else
    return 0;
}

void waitForInterrupt(int delay) {
  volatile int i;
  for (i=1 ; i<=delay ; i++);
}

int M_IMSIC_interrupt_test(int neiid) {
  int i, j;

  for (j=1 ; j<=neiid ; j++) {
    result_core = 0;
    eiid_core = j;
    *IMSICregs[0].m_seteipnum = j;
    waitForInterrupt(5);
    if (result_core == 0) 
      fail(28);
    if (result_core != 1) {
      return -1;
    }
  }
  return 1;
}

int S_IMSIC_interrupt_test(int neiid) {
  int j;

  for (j=1 ; j<=neiid ; j++) {
    result_core = 0;
    eiid_core = j;
    *IMSICregs[0].s_seteipnum = j;
    waitForInterrupt(5);
    if (result_core == 0) 
      fail(28);
    if (result_core != 1) {
      return -1;
    }
  }
  return 1;
}


int VS_IMSIC_interrupt_test(int neiid, int vgein) {
  int j, k;

  for (k=1 ; k<=neiid ; k++) {
    result_core = 0;
    eiid_core = k;
    *IMSICregs[0].g_seteipnum[vgein] = k;
    waitForInterrupt(5);
    if (result_core == 0) 
      fail(28);
    if (result_core != 1) {
      return -1;
    }
  }
  
  return 1;
}

int APLIC_MSI_interrupt_test(int domains, int sources) {
  int i, j, k;
  int hart;

  for (j=0 ; j<domains ; j++) {
    // Enable interrupts in every domain and set them as MSI delivery mode
    *APLICregs[j].domaincfg = 0b100000100; //DM = 1 and EI = 1
    for (k=1 ; k<=sources ; k++) {
      // Configure every domain source as detached
      *APLICregs[j].sourcecfg[k] = 1; //SM=1 (detached)
      // Configure every source target
      *APLICregs[j].target[k] = (k | (0 << 18)); //EIID=k; Hart_index=i
    }
    for (k=1 ; k<=sources ; k++) {
      result_core = 0;
      eiid_core = k;
      *APLICregs[j].setipnum = k; // eip(k) = 1
      *APLICregs[j].setienum = k; // eie(k) = 1
      waitForInterrupt(5);
      if (result_core == 0) 
        fail(28);
      if (result_core != 1) {
        return -1;
      }
    }
    // Delegate all sources to the next domain
    for (k=1 ; k<=sources ; k++) {
      *APLICregs[j].sourcecfg[k] = 1<<10; //D=1 
    }
  }
  return 1;
}

int M_software_interrupt_test(void) {
  int i;

  // Rise machine software interrupt
  result_core = 0;
  msip_hart[0] = 1;
  waitForInterrupt(5);
  if (result_core == 0) 
    fail(28);

  return 1;
}

int S_software_interrupt_test(void) {

  // Rise supervisor software interrupt
  result_core = 0;
  ssip_hart[0] = 1;
  waitForInterrupt(5);
  if (result_core == 0) 
    fail(28);

  return 1;
}

// WARNING: this test assumes that the IMSIC EIDELIVERY
// register to deliver interrupts from the APLIC is set to
// 0x40000000 so interrupts are forwarded from APLIC
int APLIC_direct_interrupt_test(int domains, int sources){
  int j, k;
  int hart;

  // This shared variable informs the trap handler that direct mode is being tested
  direct_mode = 1;
  for (j=0 ; j<domains ; j++) {
    // Enable interrupts in every domain and set them as MSI delivery mode
    *APLICregs[j].domaincfg = 0b100000000; //DM = 0 and EI = 1
    // Configure the IDC structure idelivery register
    *IDCregs[j][0].idelivery = 1;
    // This shared variable informs the trap handler in which domain is active the hart
    direct_dom = j;
    for (k=1 ; k<=sources ; k++) {
      // Configure every domain source as detached
      *APLICregs[j].sourcecfg[k] = 1; //SM=1 (detached)
      // Configure every source target
      *APLICregs[j].target[k] = (k | (0 << 18)); //IPRIO=k; Hart_index=i
    }
    for (k=1 ; k<=sources ; k++) {
      result_core = 0;
      eiid_core = k;
      *APLICregs[j].setipnum = k; // eip(k) = 1
      *APLICregs[j].setienum = k; // eie(k) = 1
      waitForInterrupt(5);
      if (result_core == 0) 
        fail(28);
      if (result_core != 2) {
        return -1;
      }
    }
    // Delegate to next domain
    *APLICregs[j].domaincfg = 0b000000100; //DM = 1 and EI = 0
    for (k=1 ; k<=sources ; k++) {
      *APLICregs[j].sourcecfg[k] = 1<<10; //D=1 (detached)
    }
  }
  direct_mode = 0;
  return 1;
}

int timer_interrupt_test(void) {
  int i;
  volatile uint64_t current_time;

  result_core = 0;
  current_time = *mtimer;
  mtimercmp_hart[0] = current_time + 100;
  current_time = mtimercmp_hart[0];
  timer_interrupt_enable();
  waitForInterrupt(200);
  if (result_core == 0) 
    fail(28);

  return 1;
}
