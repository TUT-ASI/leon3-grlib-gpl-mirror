-----------------------------------------------------------------------------
-- LEON3 Demonstration design test bench configuration
-- Copyright (C) 2009 Aeroflex Gaisler
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library techmap;
use techmap.gencomp.all;
package config is

-- Technology and synthesis options
  constant CFG_FABTECH              : integer := nexus;
  constant CFG_MEMTECH              : integer := nexus;
  constant CFG_PADTECH              : integer := nexus;
  -- Simulation
  constant CFG_SIMULATION           : boolean := false;
  -- GRLIB debugging
  constant CFG_DUART                : integer := 1;
  -- AMBA addresses
  constant CFG_APBADDR_0            : integer := 16#A00#; -- APB address 
  constant CFG_APBADDR_1            : integer := 16#A01#; -- APB address 
  constant CFG_APBADDR_2            : integer := 16#A02#; -- APB address
  constant CFG_OC_RAM_ADDR          : integer := 16#A10#; -- ON-CHIP RAM address
  constant CFG_DDR3_ADDR            : integer := 16#800#; -- MRAM address 
  constant CFG_AHBIO                : integer := 16#aFF#; -- AHB base address of the AHB I/O area 
  constant CFG_SPFI_IOADDR          : integer := 16#800#; -- (+ CFG_HSSL_NUM*16#010#) ADDR field of the AHB IO BAR  
  constant CFG_GRPCI2_IOADDR        : integer := 16#000#; -- ADDR field of the AHB IO BAR (for PCI config and PCI IO access).
  constant CFG_GRPCI2_HADDR         : integer := 16#000#; -- MASK field of the AHB BAR.
  constant CFG_SIM_TEST_REPORT      : integer := 16#B00#; -- Addres to the simulation report  
  constant CFG_AHBCTL_DDR3_AHBIO    : integer := 16#AF2#; -- AHB base address of the AHB I/O area (Second AHB)
  constant CFG_SPIM_IOADDR          : integer := 16#A80#; -- I/O Address for SPIM controller
  constant CFG_SPIM_ADDR            : integer := 16#A40#; -- SPI memory address   
  -- AMBA settings
  constant CFG_NCPU                 : integer := (0);
  constant CFG_PCLOW                : integer := 2;
  constant CFG_DISAS                : integer := 1;
  constant CFG_FPNPEN               : integer := 1;
  constant CFG_AHB_DTRACE           : integer := 1;
  constant CFG_SPLIT                : integer := 1;
  -- AHB status register
  constant CFG_AHBSTAT              : integer := 1; -- Enable AHB Status register
  constant CFG_AHBSTATN             : integer := (1);
  -- Modular timer
  constant CFG_GPT_ENABLE           : integer := 0; -- Enable General Purpose Timer Unit
  -- Interrupt controller
  constant CFG_IRQ3_ENABLE          : integer := 1; -- Enable interrupt control
  -- Interrupt constants 
  constant AHBSTAT_PIRQ             : integer := 1;
  constant GPT_PIRQ                 : integer := 2; 
  constant APBUART1_PIRQ            : integer := 3;  
  constant SPIM_PIRQ                : integer := 4;
  constant SPWRTR_PIRQ              : integer := 5;  
  constant PCI2_PIRQ                : integer := 6; 
  constant GPIO_PIRQ                : integer := 7;  -- + gr740_gpio2(4..0)
  constant SPFI_PIRQ                : integer := 12; -- + CFG_HSSL_NUM 
  constant MDIO_PIRQ                : integer := 16;
  constant GRETH_PIRQ               : integer := 17;
  constant NAND_PIRQ                : integer := 18;
  constant I2C1_PIRQ                : integer := 19;
  constant DMACTRL_PIRQ             : integer := 20;
  -- SPI memory controller
  constant CFG_SPIMCTRL             : integer := 1;
  constant CFG_SPIMCTRL_SDCARD      : integer := 0;
  constant CFG_SPIMCTRL_READCMD     : integer := 16#3B#;
  constant CFG_SPIMCTRL_DUMMYBYTE   : integer := 1;
  constant CFG_SPIMCTRL_DUALOUTPUT  : integer := 1;
  constant CFG_SPIMCTRL_QUADOUTPUT  : integer := 0;
  constant CFG_SPIMCTRL_DUALINPUT   : integer := 0;
  constant CFG_SPIMCTRL_QUADINPUT   : integer := 0;
  constant CFG_SPIMCTRL_DSPI        : integer := 0;
  constant CFG_SPIMCTRL_QSPI        : integer := 0;
  constant CFG_SPIMCTRL_DUMMYCYCLES : integer := (0);
  constant CFG_SPIMCTRL_EXTADDR     : integer := 0;
  constant CFG_SPIMCTRL_RECONF      : integer := 0;
  constant CFG_SPIMCTRL_SCALER      : integer := (3);
  constant CFG_SPIMCTRL_ASCALER     : integer := (8);
  constant CFG_SPIMCTRL_PWRUPCNT    : integer := 0;
  constant CFG_SPIMCTRL_OFFSET      : integer := 16#0#;
  -- Configuration memory scrubber
  constant CFG_GRCSCRUB             : integer := 0;
  -- AHB RAM
  constant CFG_AHBRAMEN             : integer := 1;
  constant CFG_AHBRSZ               : integer := 128;
  constant CFG_AHBRPIPE             : integer := 0;
  -- FT AHB RAM
  constant CFG_FTAHBRAM_EN          : integer := 0;
  constant CFG_FTAHBRAM_SZ          : integer := 128; 
  constant CFG_FTAHBRAM_PIPE        : integer := 0;
  constant CFG_FTAHBRAM_EDAC        : integer := 1;
  constant CFG_FTAHBRAM_SCRU        : integer := 0;
  constant CFG_FTAHBRAM_ECNT        : integer := 0;
  constant CFG_FTAHBRAM_EBIT        : integer := (1);
  --  NANDFLASH
  constant CFG_NANDFCTRL2_EN        : integer := 0; -- Enable Nandflash controller
  -- JTAG based DSU interface
  constant CFG_AHB_JTAG             : integer := 1; -- Enable JTAG (Debug)
  -- UART
  constant CFG_AHB_UART             : integer := 0; -- Enable Debug UART 
  constant CFG_UART_1_ENABLE        : integer := 1; -- Enable UART 1 (shares same pins as the debuglink)
  -- I2C FMC
  constant CFG_I2C_FMC              : integer := 0; -- Enable I2C to FMC connector
  -- GRGPIO port 
  constant CFG_GRGPIO_EN            : integer := 1; -- Enable general GPIO IP 
  constant CFG_GRGPIO_WIDTH         : integer := (9);
  constant CFG_GRGPIO_IRQGEN        : integer := 0; -- individual interrup for each mask I/O
  constant CFG_GRGPIO_IMASK         : integer := 16#000001f0#; -- Sets interrupt for corresponing GPIO signal 
  -- GRPCI2 interface
  constant CFG_FGPA_HOST            : integer := 0; -- 0: GR740 is host, 1: FPGA is host
  constant CFG_GRPCI2_MASTER        : integer := 1; -- Enable PCI master
  constant CFG_GRPCI2_TARGET        : integer := 1; -- Enable PCI target
  constant CFG_GRPCI2_DMA           : integer := 0; -- Enable PCI DMA
  constant CFG_PCI2_IRQMODE         : integer := 0; -- IRQ routing option [0..3]
  constant CFG_PCI2_FT              : integer := 0; -- Enable fault-tolerance against SEU errors [0..1]
  constant CFG_GRPCI2_VID           : integer := 16#1AC8#; -- Sets vendor id
  constant CFG_GRPCI2_DID           : integer := 16#0055#; -- Sets Device id
  constant CFG_GRPCI2_CLASS         : integer := 16#FF0000#; -- Sets PCI class code
  constant CFG_GRPCI2_TRACE         : integer := 0; -- Enable and number of entries of the PCI trace buffer [0,32,64..16384]
  constant CFG_GRPCI2_CAP           : integer := 16#40#; --  Enabled and sets the offset of the first item in the Extended PCI Config Space
  constant CFG_GRPCI2_NCAP          : integer := 16#00#; -- Offset of the first user defined item in the capability list
  constant CFG_GRPCI2_EXTCFG        : integer := (0); -- Default value of the user defined Extended PCI config Space to AHB address mapping.
  constant CFG_GRPCI2_BAR0          : integer := (29); -- Sets the default size of BAR0 in address bits. [0..31]
  constant CFG_PCI_BAR0_ADDR        : integer := 16#800000#;  -- CFG_DDR3_ADDR;
  constant CFG_GRPCI2_BAR1          : integer := (29); -- Sets the default size of BAR0 in address bits. [0..31]
  constant CFG_PCI_BAR1_ADDR        : integer := 16#A00000#; --CFG_APBADDR_0;
  constant CFG_GRPCI2_BAR2          : integer := (0); -- Sets the default size of BAR0 in address bits. [0..31]
  constant CFG_GRPCI2_BAR3          : integer := (0); -- Sets the default size of BAR0 in address bits. [0..31]
  constant CFG_GRPCI2_BAR4          : integer := (0); -- Sets the default size of BAR0 in address bits. [0..31] 
  constant CFG_GRPCI2_BAR5          : integer := (0); -- Sets the default size of BAR0 in address bits. [0..31]
  constant CFG_GRPCI2_FDEPTH        : integer := 5; -- Depth of each of the FIFOs in the data path. [3..7]
  constant CFG_GRPCI2_FCOUNT        : integer := 4; -- Number of FIFOs in the data path [2..4] 
  constant CFG_GRPCI2_ENDIAN        : integer := 0; -- Default value of the endianess conversion setting [0..1]
  constant CFG_GRPCI2_DEVINT        : integer := 1; -- Enable the device to drive the PCI INTA signal [0..1]
  constant CFG_GRPCI2_DEVINTMSK     : integer := 16#0#; -- Default value of the irq mask for the dirq input
  constant CFG_GRPCI2_HOSTINT       : integer := 1; -- Enable the core to sample the PCI INTA signals todrive a AHB irq. [0..1]
  constant CFG_GRPCI2_HOSTINTMSK    : integer := 16#0#; -- Default value for the PCI INTA-D signals.
  constant CFG_GRPCI2_NSYNC         : integer := 2; -- Number of synchronization registers between the two clock domains. [0..2]
  constant CFG_GRPCI2_HOSTTST       : integer := 2; -- Mode of reset signal, 2 = The AHB reset is driven on the PCI reset. [0..2]
  constant CFG_GRPCI2_BYPASS        : integer := 0; -- When 1, logic is implemented to bypass the pad on signals driven by the core.
  -- PCI arbiter
  constant CFG_PCI_ARB              : integer := 1; -- Enable PCI Arbiter
  constant CFG_PCI_ARBAPB           : integer := 1; -- Enbale APB interface 
  constant CFG_PCI_ARB_NGNT         : integer :=(2); -- set number of masters connected to arbiter 
  -- HSSL/SpaceFibre
  constant CFG_HSSL_EN              : integer := 0; -- Enable HSSL/SpaceFibre
  constant CFG_HSSL_EN_SD0          : integer := 1; -- Enable SerDes link, quad 0 lane 0
  constant CFG_HSSL_EN_SD2          : integer := 0; -- Enable SerDes link, quad 0 lane 2 
  constant CFG_HSSL_EN_SD6          : integer := 0; -- Enable SerDes link, quad 1 lane 2
  constant CFG_HSSL_EN_SD7          : integer := 0; -- Enable SerDes link, quad 1 lane 3
  constant CFG_HSSL_NUM             : integer := CFG_HSSL_EN_SD0  + CFG_HSSL_EN_SD2 + CFG_HSSL_EN_SD6 + CFG_HSSL_EN_SD7;
  constant CFG_GRHSSL_VC            : integer := 2; -- Sets the number of Virtuel channels 
  constant CFG_GRHSSL_RMAP          : integer := 1;
  constant CFG_GRHSSL_DMA           : integer := 1; -- Sets the number of DMA channels
  constant CFG_GRSPFI_FT_VC         : integer := 0; 
  constant CFG_GRSPFI_FT_RT1        : integer := 0; 
  constant CFG_GRSPFI_FT_RT2        : integer := 0; 
  constant CFG_GRSPFI_FT_IF         : integer := 0; 
  constant CFG_GRSPFI_FT_DATA       : integer := 0; 
  constant CFG_GRSPFI_FT_BC         : integer := 0; 
  -- Reference clock selection for the two quads. 0: Use quad-local reference clock, 1: Use quad 0 external reference clock, 2: Use quad 1 external reference clock
  -- Using a reference clock from a fabric PLL is possible in principle, not implmeneted yet TODO In principle, dynamic frequency switching is supported by the SerDes,
  -- but this design has no support for it. When changing the reference clock settings make sure to update the corresponding serdes_channel_* IP configuration so that its frequency matches.
  constant CFG_HSSL_SDQ0_REFCLK     : integer := 2; -- refclk for Q0
  constant CFG_HSSL_SDQ1_REFCLK     : integer := 2; -- refclk for Q1
  -- SpaceFibre-SpaceWire Bridge
  constant CFG_SPW_SPFI_BR_EN       : integer := 0; -- Enable SpaceFibre-SpaceWire Bridge
  -- Spacewire router
  constant CFG_SPW_EN               : integer := 0;
  constant CFG_SPW_EN_GR740_4       : integer := 1;
  constant CFG_SPW_EN_GR740_5       : integer := 1;
  constant CFG_SPW_EN_GR740_6       : integer := 0;
  constant CFG_SPW_EN_GR740_7       : integer := 0;
  constant CFG_SPW_EN_MEZ_1         : integer := 0;
  constant CFG_SPW_EN_MEZ_2         : integer := 0;
  constant CFG_SPW_EN_MEZ_3         : integer := 0;
  constant CFG_SPW_EN_MEZ_4         : integer := 0;      
  constant CFG_SPW_SPWPORTS         : integer := CFG_SPW_EN_GR740_4 + CFG_SPW_EN_GR740_5 + CFG_SPW_EN_GR740_6 + CFG_SPW_EN_GR740_7 + CFG_SPW_EN_MEZ_1 + CFG_SPW_EN_MEZ_2 + CFG_SPW_EN_MEZ_3 + CFG_SPW_EN_MEZ_4;
  constant CFG_SPW_LOOP_BACK        : integer := 0;  -- Loopback, prevents pad instantiation
  constant CFG_SPW_PADS             : integer := 1;  -- Instantiate pads
  constant CFG_SPW_INPUT_TYPE       : integer := 3;  -- Receiver type: DDR(3), SDR(2) or XOR (0)
  constant CFG_SPW_OUTPUT_TYPE      : integer := 0;  -- Transmitter type 0 = SDR
  constant CFG_SPW_RXTX_SAMECLK     : integer := 1;  -- 1 = same clock for rx and tx
  constant CFG_SPW_FIFOSIZE         : integer := 16;        -- # N-char FIFO
  constant CFG_SPW_TECH             : integer := CFG_MEMTECH;
  constant CFG_SPW_TECHFIFO         : integer := 1;  -- Use RAM cells for FIFOs
  constant CFG_SPW_FT               : integer := 0;  -- Fault-tolerance
  constant CFG_SPW_AMBAPORTS        : integer := 1; 
  constant CFG_SPW_FIFOPORTS        : integer := CFG_SPW_SPFI_BR_EN*CFG_HSSL_NUM;
  constant CFG_SPW_RMAP             : integer := 16#FFFF#;  -- Hardware RMAP target
  constant CFG_SPW_RMAPCRC          : integer := 16#FFFF#;  -- Covered by CFG_SPW_RMAP
  constant CFG_SPW_FIFOSIZE2        : integer := 16;
  constant CFG_SPW_RXUNALIGNED      : integer := 16#FFFF#;  -- Covered by CFG_SPW_RMAP
  constant CFG_SPW_RMAPBUFS         : integer := 4;  -- # buffers to hold RMAP replies
  constant CFG_SPW_DMACHAN          : integer := 2;  -- # DMA channels
  constant CFG_SPW_TIMERBITS        : integer := 16;
  constant CFG_SPW_PNP              : integer := 0;  -- Specification not done
  constant CFG_SPW_AUTOSCRUB        : integer := 0;  -- Automatic scrub of table
  -- SpaceWire Router instance ID, CFG_SPWINSTID will be present on bits
  -- 7:2 in the SpaceWire router instance ID.
  constant CFG_SPWINSTID            : integer := 00;  -- Will start at 0x40
  -- DDR3 
  constant CFG_DDR3                 : integer  := 0; -- Enable DDR3 memory 
  -- DMACTRL 
  constant CFG_DMACTRL              : integer  := 1; -- Enable DMACTRL 
  constant CFG_EN_BM1               : integer  := 0; -- Enable second master interface to DMACTRL
  -- ETHERNET
  constant CFG_GRETH                : integer  := 1; -- Enable RGMII 1
  constant CFG_GRETH1G              : integer  := 0; -- Enable 1000 Mbit mode NOTE: If this is disabled the internal must be enabled 
  constant CFG_ETH_MDIO             : integer  := 1; -- Enable Internal MDIO interface in the greth core, 
                                                     -- (Setting this to zero will enable the external mdio core that only is compatible with 1000 Mbit mode.)  
  constant CFG_ETH_PHY_ADD          : integer  := 2; -- Enable the Management interface,   
  constant CFG_ETH_FIFO             : integer  := 8; -- Sets the size in 32-bit words of the RX and TX FIFOs.
  constant CFG_DSU_ETH              : integer  := 1; -- Enable Debug link
  constant CFG_ETH_BURSTLEN         : integer  := 64; -- Set burst length
  constant CFG_ETH_FT               : integer  := 0; -- Enable fault tolerance for receive and transmit buffers [0..2]
  constant CFG_ETH_BUF              : integer  := 16; -- Select the size of the EDCL buffer in kB.
  constant CFG_ETH_IPM              : integer  := 16#C0A8#; -- Sets the upper 16 bits of the EDCL IP address reset value. 
  constant CFG_ETH_IPL              : integer  := 16#0033#; -- Sets the lower 16 bits of the EDCL IP address reset value. 
  constant CFG_ETH_ENM              : integer  := 16#0050c2#; -- Sets the upper 24 bits of the EDCL MAC address.
  constant CFG_ETH_ENL              : integer  := 16#75a339#; -- Sets the lower 24 bits of the EDCL MAC address. 
  -- AMBA Bus indexes
  -- Masters
  constant hmidx_ahbuart            : integer := -1 + CFG_AHB_UART;
  constant hmidx_ahbjtag            : integer := hmidx_ahbuart + CFG_AHB_JTAG;
  constant hmidx_greth              : integer := hmidx_ahbjtag + CFG_GRETH;
  constant hmidx_nandfctrl2         : integer := hmidx_greth + CFG_NANDFCTRL2_EN;
  constant hmidx_grpci2             : integer := hmidx_nandfctrl2 + CFG_GRPCI2_TARGET;
  constant hdmidx_grpci2            : integer := hmidx_grpci2 + CFG_GRPCI2_DMA;
  constant hmidx_dmactrl            : integer := hdmidx_grpci2 + CFG_DMACTRL;
  constant hmidx_spwrtr             : integer := hmidx_dmactrl + CFG_SPW_EN;
  constant hmidx_grhssl             : integer := hmidx_spwrtr + CFG_SPW_EN*(CFG_SPW_AMBAPORTS - 1) + CFG_HSSL_EN;
  constant maxahbm                  : integer := hmidx_grhssl +  CFG_HSSL_EN*(CFG_HSSL_NUM*CFG_GRHSSL_DMA -1) + 1 ; -- total number of ahbm, latest hmidx + 1
  -- Slaves
  constant hsidx_apbctrl_0          : integer := 0; 
  constant hsidx_apbctrl_1          : integer := hsidx_apbctrl_0 + CFG_SPW_EN; 
  constant hsidx_ahb2               : integer := hsidx_apbctrl_1 + 1*(CFG_DDR3 + CFG_DMACTRL - CFG_DMACTRL*CFG_DDR3);
  constant hsidx_ahbram             : integer := hsidx_ahb2 + CFG_AHBRAMEN;
  constant hsidx_ftahbram           : integer := hsidx_ahbram + CFG_FTAHBRAM_EN;
  constant hsidx_spimctrl           : integer := hsidx_ftahbram + CFG_SPIMCTRL;
  constant hsidx_grpci2             : integer := hsidx_spimctrl + CFG_GRPCI2_MASTER;
  constant hsidx_spwrtr             : integer := hsidx_grpci2 + CFG_SPW_EN;  
  constant hsidx_ahbrep             : integer := hsidx_spwrtr 
                                        --pragma translate_off
                                          + 1
                                        --pragma translate_on
                                        ;
  constant hsidx_grhssl             : integer := hsidx_ahbrep + CFG_HSSL_EN;
  constant maxahbs                  : integer := hsidx_grhssl + CFG_HSSL_EN*(CFG_HSSL_NUM - 1) + 1 ;  -- total number of ahbs, latest hsidx + 1
  -- APB_0 index
  constant pidx_ftahbram            : integer :=  0;
  constant pidx_apbuart             : integer :=  1;
  constant pidx_irqmp               : integer :=  2;
  constant pidx_gptimer             : integer :=  3;
  constant pidx_grpci2              : integer :=  4; 
  constant pidx_pciarb              : integer :=  5;  
  constant pidx_ahbuart             : integer :=  6;  
  constant pidx_grcscrub            : integer :=  7; 
  constant pidx_ahbstat             : integer :=  8; 
  constant pidx_mdio                : integer :=  9;
  constant pidx_greth               : integer :=  10;
  constant pidx_grgpio              : integer :=  11;
  constant pidx_gp_register         : integer :=  12;
  constant pidx_nandfctrl2          : integer :=  13;
  constant pidx_i2c                 : integer :=  14;
  constant pidx_dmactrl             : integer :=  15;
  constant paddr_ftahbram           : integer :=  16#000#; -- requires 256 bytes
  constant paddr_apbuart            : integer :=  16#001#; -- requires 256 bytes
  constant paddr_irqmp              : integer :=  16#002#; -- requires 256 bytes
  constant paddr_gptimer            : integer :=  16#003#; -- requires 256 bytes
  constant paddr_grpci2             : integer :=  16#004#; -- requires 256 bytes
  constant paddr_pciarb             : integer :=  16#005#; -- requires 256 bytes
  constant paddr_ahbuart            : integer :=  16#006#; -- requires 256 bytes
  constant paddr_grcscrub           : integer :=  16#007#; -- requires 256 bytes
  constant paddr_ahbstat            : integer :=  16#008#; -- requires 256 bytes
  constant paddr_mdio               : integer :=  16#009#; -- requires 256 bytes
  constant paddr_greth              : integer :=  16#00a#; -- requires 256 bytes
  constant paddr_grgpio             : integer :=  16#00b#; -- requires 256 bytes
  constant paddr_nandfctrl2         : integer :=  16#00c#; -- requires 512 bytes
  constant paddr_gp_register        : integer :=  16#00e#; -- requires 256 bytes
  constant paddr_i2c                : integer :=  16#00f#; -- requires 256 bytes
  constant paddr_dmactrl            : integer :=  16#010#; -- requires 512 bytes
  -- APB_1
  constant pidx_spwrtr              : integer :=  0;  -- + AMBAPORTS
  constant paddr_spwrtr             : integer :=  16#000#; -- requires 256 bytes * AMBAPORTS
end;

