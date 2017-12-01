#define MCFG1 0x103802ff //32 BIT BUS
//#define MCFG2 0X0000146f // ENABLE SRAM // Disable DRAM // Disable Read Write Modify
//#define MCFG2 0xe6A06e60   // gr-cpc-xc4v value
//#define MCFG2 0xe6A1746F   // trial combined value
#define MCFG2 0X7ba1746f // ENABLE SDRAM // Disable SRAM // 512M Bank //1024 Columns //
//#define MCFG2 0xe6B81260 // ENABLE SRAM // Disable DRAM // Enable Read Write Modify
#define MCFG3 0x000ff000
#define ASDCFG 0x80000000
#define DSDCFG 0xe6A06e60
#define L2MCTRLIO 0x80000000
#define IRQCTRL   0x80000200
#define RAMSTART  0x40000000
#define RAMSIZE   0x00100000

