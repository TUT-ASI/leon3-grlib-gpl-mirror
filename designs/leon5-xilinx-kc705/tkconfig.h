#if defined CONFIG_SYN_INFERRED
#define CONFIG_SYN_TECH inferred
#elif defined CONFIG_SYN_UMC
#define CONFIG_SYN_TECH umc
#elif defined CONFIG_SYN_RHUMC
#define CONFIG_SYN_TECH rhumc
#elif defined CONFIG_SYN_DARE
#define CONFIG_SYN_TECH dare
#elif defined CONFIG_SYN_SAED32
#define CONFIG_SYN_TECH saed32
#elif defined CONFIG_SYN_RHS65
#define CONFIG_SYN_TECH rhs65
#elif defined CONFIG_SYN_ATC18
#define CONFIG_SYN_TECH atc18s
#elif defined CONFIG_SYN_ATC18RHA
#define CONFIG_SYN_TECH atc18rha
#elif defined CONFIG_SYN_AXCEL
#define CONFIG_SYN_TECH axcel
#elif defined CONFIG_SYN_AXDSP
#define CONFIG_SYN_TECH axdsp
#elif defined CONFIG_SYN_PROASICPLUS
#define CONFIG_SYN_TECH proasic
#elif defined CONFIG_SYN_ALTERA
#define CONFIG_SYN_TECH altera
#elif defined CONFIG_SYN_STRATIX
#define CONFIG_SYN_TECH stratix1
#elif defined CONFIG_SYN_STRATIXII
#define CONFIG_SYN_TECH stratix2
#elif defined CONFIG_SYN_STRATIXIII
#define CONFIG_SYN_TECH stratix3
#elif defined CONFIG_SYN_STRATIXIV
#define CONFIG_SYN_TECH stratix4
#elif defined CONFIG_SYN_STRATIXV
#define CONFIG_SYN_TECH stratix5
#elif defined CONFIG_SYN_CYCLONEII
#define CONFIG_SYN_TECH stratix2
#elif defined CONFIG_SYN_CYCLONEIII
#define CONFIG_SYN_TECH cyclone3
#elif defined CONFIG_SYN_CYCLONEIV
#define CONFIG_SYN_TECH cyclone3
#elif defined CONFIG_SYN_IHP25
#define CONFIG_SYN_TECH ihp25
#elif defined CONFIG_SYN_IHP25RH
#define CONFIG_SYN_TECH ihp25rh
#elif defined CONFIG_SYN_CMOS9SF
#define CONFIG_SYN_TECH cmos9sf
#elif defined CONFIG_SYN_BRAVEMED
#define CONFIG_SYN_TECH nx
#elif defined CONFIG_SYN_ECLIPSE
#define CONFIG_SYN_TECH eclipse
#elif defined CONFIG_SYN_PEREGRINE
#define CONFIG_SYN_TECH peregrine
#elif defined CONFIG_SYN_PROASIC
#define CONFIG_SYN_TECH proasic
#elif defined CONFIG_SYN_PROASIC3
#define CONFIG_SYN_TECH apa3
#elif defined CONFIG_SYN_PROASIC3E
#define CONFIG_SYN_TECH apa3e
#elif defined CONFIG_SYN_PROASIC3L
#define CONFIG_SYN_TECH apa3l
#elif defined CONFIG_SYN_IGLOO
#define CONFIG_SYN_TECH apa3
#elif defined CONFIG_SYN_IGLOO2
#define CONFIG_SYN_TECH igloo2
#elif defined CONFIG_SYN_SF2
#define CONFIG_SYN_TECH smartfusion2
#elif defined CONFIG_SYN_RTG4
#define CONFIG_SYN_TECH rtg4
#elif defined CONFIG_SYN_POLARFIRE
#define CONFIG_SYN_TECH polarfire
#elif defined CONFIG_SYN_FUSION
#define CONFIG_SYN_TECH actfus
#elif defined CONFIG_SYN_SPARTAN2
#define CONFIG_SYN_TECH virtex
#elif defined CONFIG_SYN_VIRTEX
#define CONFIG_SYN_TECH virtex
#elif defined CONFIG_SYN_VIRTEXE
#define CONFIG_SYN_TECH virtex
#elif defined CONFIG_SYN_SPARTAN3
#define CONFIG_SYN_TECH spartan3
#elif defined CONFIG_SYN_SPARTAN3E
#define CONFIG_SYN_TECH spartan3e
#elif defined CONFIG_SYN_SPARTAN6
#define CONFIG_SYN_TECH spartan6
#elif defined CONFIG_SYN_VIRTEX2
#define CONFIG_SYN_TECH virtex2
#elif defined CONFIG_SYN_VIRTEX4
#define CONFIG_SYN_TECH virtex4
#elif defined CONFIG_SYN_VIRTEX5
#define CONFIG_SYN_TECH virtex5
#elif defined CONFIG_SYN_VIRTEX6
#define CONFIG_SYN_TECH virtex6
#elif defined CONFIG_SYN_VIRTEX7
#define CONFIG_SYN_TECH virtex7
#elif defined CONFIG_SYN_KINTEX7
#define CONFIG_SYN_TECH kintex7
#elif defined CONFIG_SYN_KINTEXU
#define CONFIG_SYN_TECH kintexu
#elif defined CONFIG_SYN_ARTIX7
#define CONFIG_SYN_TECH artix7
#elif defined CONFIG_SYN_ZYNQ7000
#define CONFIG_SYN_TECH zynq7000
#elif defined CONFIG_SYN_ARTIX77
#define CONFIG_SYN_TECH artix7
#elif defined CONFIG_SYN_ZYNQ7000
#define CONFIG_SYN_TECH zynq7000
#elif defined CONFIG_SYN_RH_LIB18T
#define CONFIG_SYN_TECH rhlib18t
#elif defined CONFIG_SYN_SMIC13
#define CONFIG_SYN_TECH smic013
#elif defined CONFIG_SYN_UT025CRH
#define CONFIG_SYN_TECH ut25
#elif defined CONFIG_SYN_UT130HBD
#define CONFIG_SYN_TECH ut130
#elif defined CONFIG_SYN_UT90NHBD
#define CONFIG_SYN_TECH ut90
#elif defined CONFIG_SYN_TSMC90
#define CONFIG_SYN_TECH tsmc90
#elif defined CONFIG_SYN_TM65GPLUS
#define CONFIG_SYN_TECH tm65gplus
#elif defined CONFIG_SYN_CUSTOM1
#define CONFIG_SYN_TECH custom1
#else
#error "unknown target technology"
#endif

#if defined CONFIG_SYN_INFER_RAM
#define CFG_RAM_TECH inferred
#elif defined CONFIG_MEM_UMC
#define CFG_RAM_TECH umc
#elif defined CONFIG_MEM_RHUMC
#define CFG_RAM_TECH rhumc
#elif defined CONFIG_MEM_DARE
#define CFG_RAM_TECH dare
#elif defined CONFIG_MEM_SAED32
#define CFG_RAM_TECH saed32
#elif defined CONFIG_MEM_RHS65
#define CFG_RAM_TECH rhs65
#elif defined CONFIG_MEM_VIRAGE
#define CFG_RAM_TECH memvirage
#elif defined CONFIG_MEM_ARTISAN
#define CFG_RAM_TECH memartisan
#elif defined CONFIG_MEM_CUSTOM1
#define CFG_RAM_TECH custom1
#elif defined CONFIG_MEM_VIRAGE90
#define CFG_RAM_TECH memvirage90
#elif defined CONFIG_MEM_INFERRED
#define CFG_RAM_TECH inferred
#else
#define CFG_RAM_TECH CONFIG_SYN_TECH
#endif

#if defined CONFIG_TRANS_GTP0
#define CFG_TRANS_TECH TT_XGTP0
#elif defined CONFIG_TRANS_GTP1
#define CFG_TRANS_TECH TT_XGTP1
#elif defined CONFIG_TRANS_GTX0
#define CFG_TRANS_TECH TT_XGTX0
#elif defined CONFIG_TRANS_GTX1
#define CFG_TRANS_TECH TT_XGTX1
#elif defined CONFIG_TRANS_GTH0
#define CFG_TRANS_TECH TT_XGTH0
#elif defined CONFIG_TRANS_GTH1
#define CFG_TRANS_TECH TT_XGTH1
#else
#define CFG_TRANS_TECH TT_XGTP0
#endif

#if defined CONFIG_SYN_INFER_PADS
#define CFG_PAD_TECH inferred
#else
#define CFG_PAD_TECH CONFIG_SYN_TECH
#endif

#ifndef CONFIG_SYN_NO_ASYNC
#define CONFIG_SYN_NO_ASYNC 0
#endif

#ifndef CONFIG_SYN_SCAN
#define CONFIG_SYN_SCAN 0
#endif


#if defined CONFIG_CLK_ALTDLL
#define CFG_CLK_TECH CONFIG_SYN_TECH
#elif defined CONFIG_CLK_HCLKBUF
#define CFG_CLK_TECH axcel
#elif defined CONFIG_CLK_BRAVEMED
#define CFG_CLK_TECH nx
#elif defined CONFIG_CLK_PRO3PLL
#define CFG_CLK_TECH apa3
#elif defined CONFIG_CLK_PRO3EPLL
#define CFG_CLK_TECH apa3e
#elif defined CONFIG_CLK_PRO3LPLL
#define CFG_CLK_TECH apa3l
#elif defined CONFIG_CLK_FUSPLL
#define CFG_CLK_TECH actfus
#elif defined CONFIG_CLK_CLKDLL
#define CFG_CLK_TECH virtex
#elif defined CONFIG_CLK_CLKPLLE2
#define CFG_CLK_TECH CONFIG_SYN_TECH
#elif defined CONFIG_CLK_DCM
#define CFG_CLK_TECH CONFIG_SYN_TECH
#elif defined CONFIG_CLK_LIB18T
#define CFG_CLK_TECH rhlib18t
#elif defined CONFIG_CLK_RHUMC
#define CFG_CLK_TECH rhumc
#elif defined CONFIG_CLK_SAED32
#define CFG_CLK_TECH saed32
#elif defined CONFIG_CLK_RHS65
#define CFG_CLK_TECH rhs65
#elif defined CONFIG_CLK_DARE
#define CFG_CLK_TECH dare
#elif defined CONFIG_CLK_EASIC45
#define CFG_CLK_TECH easic45
#elif defined CONFIG_CLK_UT130HBD
#define CFG_CLK_TECH ut130
#else
#define CFG_CLK_TECH inferred
#endif

#ifndef CONFIG_CLK_MUL
#define CONFIG_CLK_MUL 2
#endif

#ifndef CONFIG_CLK_DIV
#define CONFIG_CLK_DIV 2
#endif

#ifndef CONFIG_OCLK_DIV
#define CONFIG_OCLK_DIV 1
#endif

#ifndef CONFIG_OCLKB_DIV
#define CONFIG_OCLKB_DIV 0
#endif

#ifndef CONFIG_OCLKC_DIV
#define CONFIG_OCLKC_DIV 0
#endif

#ifndef CONFIG_PCI_CLKDLL
#define CONFIG_PCI_CLKDLL 0
#endif

#ifndef CONFIG_PCI_SYSCLK
#define CONFIG_PCI_SYSCLK 0
#endif

#ifndef CONFIG_CLK_NOFB
#define CONFIG_CLK_NOFB 0
#endif


#ifndef CONFIG_PROC_NUM
#define CONFIG_PROC_NUM 1
#endif

#if defined CONFIG_FPU_GRFPU5
#define CONFIG_FPU 1
#else
#define CONFIG_FPU 0
#endif

#if defined CONFIG_AHB_128BIT
#define CONFIG_AHBW 128
#elif defined CONFIG_AHB_64BIT
#define CONFIG_AHBW 64
#else
#define CONFIG_AHBW 32
#endif

#ifndef CONFIG_BWMASK
#define CONFIG_BWMASK 0
#endif

#ifndef CONFIG_CACHE_FIXED
#define CONFIG_CACHE_FIXED 0
#endif

#ifndef CONFIG_DSU_UART
#define CONFIG_DSU_UART 0
#endif


#ifndef CONFIG_DSU_JTAG
#define CONFIG_DSU_JTAG 0
#endif

#ifndef CONFIG_DSU_ETH
#define CONFIG_DSU_ETH 0
#endif

#ifndef CONFIG_DSU_IPMSB
#define CONFIG_DSU_IPMSB C0A8
#endif

#ifndef CONFIG_DSU_IPLSB
#define CONFIG_DSU_IPLSB 0033
#endif

#ifndef CONFIG_DSU_ETHMSB
#define CONFIG_DSU_ETHMSB 020000
#endif

#ifndef CONFIG_DSU_ETHLSB
#define CONFIG_DSU_ETHLSB 000009
#endif

#if defined CONFIG_DSU_ETHSZ1
#define CFG_DSU_ETHB 1
#elif CONFIG_DSU_ETHSZ2
#define CFG_DSU_ETHB 2
#elif CONFIG_DSU_ETHSZ4
#define CFG_DSU_ETHB 4
#elif CONFIG_DSU_ETHSZ8
#define CFG_DSU_ETHB 8
#elif CONFIG_DSU_ETHSZ16
#define CFG_DSU_ETHB 16
#elif CONFIG_DSU_ETHSZ32
#define CFG_DSU_ETHB 32
#else
#define CFG_DSU_ETHB 1
#endif

#ifndef CONFIG_DSU_ETH_PROG
#define CONFIG_DSU_ETH_PROG 0
#endif

#ifndef CONFIG_DSU_ETH_DIS
#define CONFIG_DSU_ETH_DIS 0
#endif

#ifndef CONFIG_MCTRL_LEON2
#define CONFIG_MCTRL_LEON2 0
#endif

#ifndef CONFIG_MCTRL_SDRAM
#define CONFIG_MCTRL_SDRAM 0
#endif

#ifndef CONFIG_MCTRL_SDRAM_SEPBUS
#define CONFIG_MCTRL_SDRAM_SEPBUS 0
#endif

#ifndef CONFIG_MCTRL_SDRAM_INVCLK
#define CONFIG_MCTRL_SDRAM_INVCLK 0
#endif

#ifndef CONFIG_MCTRL_SDRAM_BUS64
#define CONFIG_MCTRL_SDRAM_BUS64 0
#endif

#ifndef CONFIG_MCTRL_8BIT
#define CONFIG_MCTRL_8BIT 0
#endif

#ifndef CONFIG_MCTRL_16BIT
#define CONFIG_MCTRL_16BIT 0
#endif

#ifndef CONFIG_MCTRL_5CS
#define CONFIG_MCTRL_5CS 0
#endif

#ifndef CONFIG_MCTRL_EDAC
#define CONFIG_MCTRL_EDAC 0
#endif

#ifndef CONFIG_MCTRL_PAGE
#define CONFIG_MCTRL_PAGE 0
#endif

#ifndef CONFIG_MCTRL_PROGPAGE
#define CONFIG_MCTRL_PROGPAGE 0
#endif


#ifndef CONFIG_MIG_7SERIES
#define CONFIG_MIG_7SERIES 0
#endif
#ifndef CONFIG_MIG_7SERIES_MODEL
#define CONFIG_MIG_7SERIES_MODEL 0
#endif
#ifndef CONFIG_AHBSTAT_ENABLE
#define CONFIG_AHBSTAT_ENABLE  0
#endif

#ifndef CONFIG_AHBSTAT_NFTSLV
#define CONFIG_AHBSTAT_NFTSLV  1
#endif

#ifndef CONFIG_AHBROM_ENABLE
#define CONFIG_AHBROM_ENABLE 0
#endif

#ifndef CONFIG_AHBROM_START
#define CONFIG_AHBROM_START 000
#endif

#ifndef CONFIG_AHBROM_PIPE
#define CONFIG_AHBROM_PIPE 0
#endif

#if (CONFIG_AHBROM_START == 0) && (CONFIG_AHBROM_ENABLE == 1)
#define CONFIG_ROM_START 100
#else
#define CONFIG_ROM_START 000
#endif


#ifndef CONFIG_AHBRAM_ENABLE
#define CONFIG_AHBRAM_ENABLE 0
#endif

#ifndef CONFIG_AHBRAM_START
#define CONFIG_AHBRAM_START A00
#endif

#if defined CONFIG_AHBRAM_SZ1
#define CFG_AHBRAMSZ 1
#elif CONFIG_AHBRAM_SZ2
#define CFG_AHBRAMSZ 2
#elif CONFIG_AHBRAM_SZ4
#define CFG_AHBRAMSZ 4
#elif CONFIG_AHBRAM_SZ8
#define CFG_AHBRAMSZ 8
#elif CONFIG_AHBRAM_SZ16
#define CFG_AHBRAMSZ 16
#elif CONFIG_AHBRAM_SZ32
#define CFG_AHBRAMSZ 32
#elif CONFIG_AHBRAM_SZ64
#define CFG_AHBRAMSZ 64
#elif CONFIG_AHBRAM_SZ128
#define CFG_AHBRAMSZ 128
#elif CONFIG_AHBRAM_SZ256
#define CFG_AHBRAMSZ 256
#elif CONFIG_AHBRAM_SZ512
#define CFG_AHBRAMSZ 512
#elif CONFIG_AHBRAM_SZ1024
#define CFG_AHBRAMSZ 1024
#elif CONFIG_AHBRAM_SZ2048
#define CFG_AHBRAMSZ 2048
#elif CONFIG_AHBRAM_SZ4096
#define CFG_AHBRAMSZ 4096
#else
#define CFG_AHBRAMSZ 1
#endif

#ifndef CONFIG_AHBRAM_PIPE
#define CONFIG_AHBRAM_PIPE 0
#endif
#ifndef CONFIG_GRETH_ENABLE
#define CONFIG_GRETH_ENABLE 0
#endif

#ifndef CONFIG_GRETH_GIGA
#define CONFIG_GRETH_GIGA 0
#endif

#if defined CONFIG_GRETH_FIFO4
#define CFG_GRETH_FIFO 4
#elif defined CONFIG_GRETH_FIFO8
#define CFG_GRETH_FIFO 8
#elif defined CONFIG_GRETH_FIFO16
#define CFG_GRETH_FIFO 16
#elif defined CONFIG_GRETH_FIFO32
#define CFG_GRETH_FIFO 32
#elif defined CONFIG_GRETH_FIFO64
#define CFG_GRETH_FIFO 64
#else
#define CFG_GRETH_FIFO 8
#endif

#ifndef CONFIG_GRETH_FT
#define CONFIG_GRETH_FT 0
#endif

#ifndef CONFIG_GRETH_EDCLFT
#define CONFIG_GRETH_EDCLFT 0
#endif

#ifndef CONFIG_GRETH_SGMII_MODE
#define CONFIG_GRETH_SGMII_MODE 0
#endif

#ifndef CONFIG_GRETH_FMC_MODE
#define CONFIG_GRETH_FMC_MODE 0
#endif

#ifndef CONFIG_GRETH2_ENABLE
#define CONFIG_GRETH2_ENABLE 0
#endif

#ifndef CONFIG_GRETH2_GIGA
#define CONFIG_GRETH2_GIGA 0
#endif

#if defined CONFIG_GRETH2_FIFO4
#define CFG_GRETH2_FIFO 4
#elif defined CONFIG_GRETH2_FIFO8
#define CFG_GRETH2_FIFO 8
#elif defined CONFIG_GRETH2_FIFO16
#define CFG_GRETH2_FIFO 16
#elif defined CONFIG_GRETH2_FIFO32
#define CFG_GRETH2_FIFO 32
#elif defined CONFIG_GRETH2_FIFO64
#define CFG_GRETH2_FIFO 64
#else
#define CFG_GRETH2_FIFO 8
#endif

#ifndef CONFIG_UART1_ENABLE
#define CONFIG_UART1_ENABLE 0
#endif

#if defined CONFIG_UA1_FIFO1
#define CFG_UA1_FIFO 1
#elif defined CONFIG_UA1_FIFO2
#define CFG_UA1_FIFO 2
#elif defined CONFIG_UA1_FIFO4
#define CFG_UA1_FIFO 4
#elif defined CONFIG_UA1_FIFO8
#define CFG_UA1_FIFO 8
#elif defined CONFIG_UA1_FIFO16
#define CFG_UA1_FIFO 16
#elif defined CONFIG_UA1_FIFO32
#define CFG_UA1_FIFO 32
#else
#define CFG_UA1_FIFO 1
#endif

#ifndef CONFIG_IRQ3_ENABLE
#define CONFIG_IRQ3_ENABLE 0
#endif
#ifndef CONFIG_IRQ3_NSEC
#define CONFIG_IRQ3_NSEC 0
#endif
#ifndef CONFIG_GPT_ENABLE
#define CONFIG_GPT_ENABLE 0
#endif

#ifndef CONFIG_GPT_NTIM
#define CONFIG_GPT_NTIM 1
#endif

#ifndef CONFIG_GPT_SW
#define CONFIG_GPT_SW 8
#endif

#ifndef CONFIG_GPT_TW
#define CONFIG_GPT_TW 8
#endif

#ifndef CONFIG_GPT_IRQ
#define CONFIG_GPT_IRQ 8
#endif

#ifndef CONFIG_GPT_SEPIRQ
#define CONFIG_GPT_SEPIRQ 0
#endif
#ifndef CONFIG_GPT_ENABLE
#define CONFIG_GPT_ENABLE 0
#endif

#ifndef CONFIG_GPT_NTIM
#define CONFIG_GPT_NTIM 1
#endif

#ifndef CONFIG_GPT_SW
#define CONFIG_GPT_SW 8
#endif

#ifndef CONFIG_GPT_TW
#define CONFIG_GPT_TW 8
#endif

#ifndef CONFIG_GPT_IRQ
#define CONFIG_GPT_IRQ 8
#endif

#ifndef CONFIG_GPT_SEPIRQ
#define CONFIG_GPT_SEPIRQ 0
#endif

#ifndef CONFIG_GPT_WDOGEN
#define CONFIG_GPT_WDOGEN 0
#endif

#ifndef CONFIG_GPT_WDOG
#define CONFIG_GPT_WDOG 0
#endif

#ifndef CONFIG_GRGPIO_ENABLE
#define CONFIG_GRGPIO_ENABLE 0
#endif
#ifndef CONFIG_GRGPIO_IMASK
#define CONFIG_GRGPIO_IMASK 0000
#endif
#ifndef CONFIG_GRGPIO_WIDTH
#define CONFIG_GRGPIO_WIDTH 1
#endif

#ifndef CONFIG_I2C_ENABLE
#define CONFIG_I2C_ENABLE 0
#endif
#ifndef CONFIG_VGA_ENABLE
#define CONFIG_VGA_ENABLE 0
#endif
#ifndef CONFIG_SVGA_ENABLE
#define CONFIG_SVGA_ENABLE 0
#endif
#ifndef CONFIG_KBD_ENABLE
#define CONFIG_KBD_ENABLE 0
#endif


#ifndef CONFIG_SPIMCTRL
#define CONFIG_SPIMCTRL 0
#endif

#ifndef CONFIG_SPIMCTRL_READCMD
#define CONFIG_SPIMCTRL_READCMD 0
#endif

#ifndef CONFIG_SPIMCTRL_DUMMYBYTE
#define CONFIG_SPIMCTRL_DUMMYBYTE 0
#endif

#ifndef CONFIG_SPIMCTRL_DUALOUTPUT
#define CONFIG_SPIMCTRL_DUALOUTPUT 0
#endif

#ifndef CONFIG_SPIMCTRL_SCALER
#define CONFIG_SPIMCTRL_SCALER 1
#endif

#ifndef CONFIG_SPIMCTRL_ASCALER
#define CONFIG_SPIMCTRL_ASCALER 1
#endif

#ifndef CONFIG_SPIMCTRL_PWRUPCNT
#define CONFIG_SPIMCTRL_PWRUPCNT 0
#endif

#ifndef CONFIG_SPIMCTRL_OFFSET
#define CONFIG_SPIMCTRL_OFFSET 0
#endif

#ifndef CONFIG_DEBUG_UART
#define CONFIG_DEBUG_UART 0
#endif
