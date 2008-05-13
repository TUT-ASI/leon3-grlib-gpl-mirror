-- GAISLER_LICENSE
-----------------------------------------------------------------------------
-- Entity:      usbdcl
-- File:        usbdcl.vhd
-- Author:      Magnus Sjalander
-- Description: USB Debug Communcation Link
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.stdlib.all;
use grlib.amba.all;
use grlib.devices.all;
library gaisler;
use gaisler.misc.all;
use gaisler.usb.all;
library techmap;
use techmap.gencomp.all;

entity usbdcl is
  generic (
    hindex   : integer                := 0;
    memtech  : integer                := DEFMEMTECH;
    uiface   : integer range 0 to 1   := 0;
    dwidth   : integer range 8 to 16  := 8;
    oepol    : integer range 0 to 1   := 0;
    syncprst : integer range 0 to 1   := 0;
    prsttime : integer range 0 to 512 := 0;
    sysfreq  : integer                := 50000;
    keepclk  : integer range 0 to 1   := 0
  );
  port (
    -- USB
    uclk     : in  std_ulogic;
    usbi     : in  usb_in_type;
    usbo     : out usb_out_type;
    -- AHB
    hclk     : in  std_ulogic;
    hrst     : in  std_ulogic;
    ahbi     : in  ahb_mst_in_type;
    ahbo     : out ahb_mst_out_type);
end usbdcl;

architecture bhv of usbdcl is
  -- Size of memory buffer 2^ADDR_BITS
  constant ADDR_BITS : integer := 10;

-----------------------------------------------------------------------------
-- DMA buffer and descriptor constants
-----------------------------------------------------------------------------
  -- Buffer locations
  constant EP0_OUT        : std_logic_vector(31 downto 0) := X"00000200"; -- conv_std_logic_vector(512, 32);
  constant EP0_IN         : std_logic_vector(31 downto 0) := X"00000210"; -- conv_std_logic_vector(528, 32);
  constant EP1_OUT_A      : std_logic_vector(31 downto 0) := X"00000000"; -- conv_std_logic_vector(0,   32);
  constant EP1_OUT_B      : std_logic_vector(31 downto 0) := X"00000080"; -- conv_std_logic_vector(128, 32);
  constant EP1_IN_A       : std_logic_vector(31 downto 0) := X"00000100"; -- conv_std_logic_vector(256, 32);
  constant EP1_IN_B       : std_logic_vector(31 downto 0) := X"00000180"; -- conv_std_logic_vector(384, 32);
  -- Descriptor locations
  constant DESC_EP0_OUT   : std_logic_vector(31 downto 0) := X"0000022C"; -- conv_std_logic_vector(556, 32);
  constant DESC_EP0_IN    : std_logic_vector(31 downto 0) := X"0000022F"; -- conv_std_logic_vector(559, 32);
  constant DESC_EP1_OUT_A : std_logic_vector(31 downto 0) := X"00000220"; -- conv_std_logic_vector(544, 32);
  constant DESC_EP1_OUT_B : std_logic_vector(31 downto 0) := X"00000223"; -- conv_std_logic_vector(547, 32);
  constant DESC_EP1_IN_A  : std_logic_vector(31 downto 0) := X"00000226"; -- conv_std_logic_vector(550, 32);
  constant DESC_EP1_IN_B  : std_logic_vector(31 downto 0) := X"00000229"; -- conv_std_logic_vector(553, 32);
  -- Default OUT descriptor control values
  --  Reserved       SE R IE NX EN LENGTH
  -- "00000000000000 0  0 1  0  1  0000000000000"
  -- "00000000000000 0  0 1  1  1  0000000000000"
  constant EP0_OUT_CTRL   : std_logic_vector(31 downto 0) := "00000000000000001010000000000000";
  constant EP1_OUT_CTRL   : std_logic_vector(31 downto 0) := "00000000000000001110000000000000";
  -- Default IN descriptor control values
  --  Reserved      MO PI ML IE NX EN LENGTH
  -- "0000000000000 0  1  0  1  0  0  0000000000000"
  -- "0000000000000 0  1  0  1  1  0  0000000000000"
  constant EP0_IN_CTRL    : std_logic_vector(31 downto 0) := "00000000000000101000000000000000";
  constant EP1_IN_CTRL    : std_logic_vector(31 downto 0) := "00000000000000101100000000000000";

  type ARRAY_TYPE is array(natural range <>) of std_logic_vector(31 downto 0);
  constant DEFAULT_DESC : ARRAY_TYPE(0 to 17) :=
    (-- Descriptor EP1_OUT_A
     EP1_OUT_CTRL,
     EP1_OUT_A(29 downto 0) & "00",
     DESC_EP1_OUT_B(29 downto 0) & "00",
     -- Descriptor EP1_OUT_B
     EP1_OUT_CTRL,
     EP1_OUT_B(29 downto 0) & "00",
     DESC_EP1_OUT_A(29 downto 0) & "00",
     -- Descriptor EP1_IN_A
     EP1_IN_CTRL,
     EP1_IN_A(29 downto 0) & "00",
     DESC_EP1_IN_B(29 downto 0) & "00",
     -- Descriptor EP1_IN_B
     EP1_IN_CTRL,
     EP1_IN_B(29 downto 0) & "00",
     DESC_EP1_IN_A(29 downto 0) & "00",
     -- Descriptor EP0_OUT
     EP0_OUT_CTRL,
     EP0_OUT(29 downto 0) & "00",
     DESC_EP0_OUT(29 downto 0) & "00",
     -- Descriptor EP0_IN
     EP0_IN_CTRL,
     EP0_IN(29 downto 0) & "00",
     DESC_EP0_IN(29 downto 0) & "00"
     );

  -- USBDCTRL register default values
  --  Reserved    PI R CS MAXPL       NT TT EH ED EV
  -- "00000000000 0  0 0  00001000000 00 00 0  0  1"
  -- "00000000000 0  0 0  01000000000 00 10 0  0  1"
  constant USB_EP0_OUT_CTRL     : std_logic_vector(31 downto 0) := "00000000000000000010000000000001";
  constant USB_EP1_OUT_CTRL     : std_logic_vector(31 downto 0) := "00000000000000010000000000010001";
  --  Reserved    PI CI CS MAXPL       NT TT EH ED EV
  -- "00000000000 0  0  0  00001000000 00 00 0  0  1"
  -- "00000000000 0  0  0  01000000000 00 10 0  0  1"
  constant USB_EP0_IN_CTRL      : std_logic_vector(31 downto 0) := "00000000000000000010000000000001";
  constant USB_EP1_IN_CTRL      : std_logic_vector(31 downto 0) := "00000000000000010000000000010001";

  -- Reserved               AE Reserved AI EI DA
  -- "000000000000000000000 0  0000000  0  1  1"
  -- "000000000000000000000 0  0000000  0  1  0"
  constant USB_EP0_OUT_DMA_CTRL : std_logic_vector(31 downto 0) := "00000000000000000000000000000011";
  constant USB_EP1_OUT_DMA_CTRL : std_logic_vector(31 downto 0) := "00000000000000000000000000000011";
  constant USB_EP0_IN_DMA_CTRL  : std_logic_vector(31 downto 0) := "00000000000000000000000000000010";
  constant USB_EP1_IN_DMA_CTRL  : std_logic_vector(31 downto 0) := "00000000000000000000000000000010";
  
  constant USB_EP0_OUT_DMA_ADDR : std_logic_vector(31 downto 0) := DESC_EP0_OUT(29 downto 0)   & "00";
  constant USB_EP1_OUT_DMA_ADDR : std_logic_vector(31 downto 0) := DESC_EP1_OUT_A(29 downto 0) & "00";
  constant USB_EP0_IN_DMA_ADDR  : std_logic_vector(31 downto 0) := DESC_EP0_IN(29 downto 0)    & "00";
  constant USB_EP1_IN_DMA_ADDR  : std_logic_vector(31 downto 0) := DESC_EP1_IN_A(29 downto 0)  & "00";

  constant ENABLE_EP1_DATA : ARRAY_TYPE(0 to 5) :=
    (-- EP1 OUT
     USB_EP1_OUT_CTRL,
     USB_EP1_OUT_DMA_ADDR,
     USB_EP1_OUT_DMA_CTRL,
     -- EP1 IN
     USB_EP1_IN_CTRL,
     USB_EP1_IN_DMA_ADDR,
     USB_EP1_IN_DMA_CTRL
     );

  constant ENABLE_EP1_ADDR : ARRAY_TYPE(0 to 5) :=
    (-- EP1 OUT
     X"00000010", 
     X"00000018", 
     X"00000014",
     -- EP1 IN
     X"00000110", 
     X"00000118", 
     X"00000114"
     );
    
  constant DEFAULT_OUT_EP : ARRAY_TYPE(0 to 2) :=
    (-- EP0 OUT 
     USB_EP0_OUT_CTRL,
     USB_EP0_OUT_DMA_CTRL,
     USB_EP0_OUT_DMA_ADDR
     );

  constant DEFAULT_IN_EP : ARRAY_TYPE(0 to 2) :=
    (-- EP0 IN 
     USB_EP0_IN_CTRL,
     USB_EP0_IN_DMA_CTRL,
     USB_EP0_IN_DMA_ADDR
     );
  --  SI UI VI SP FI Reserved     EP DH RW TS  TM UA      SU
  -- "0  1  1  0  0  000000000000 1  0  0  000 0  0000000 0"
  constant USB_GLOBAL_CTRL_REG : std_logic_vector(31 downto 0) := "01100000000000000100000000000000";

  -- Addresses to the different registers in USBDCTRL
  constant USB_EP_OUT_ADDR      : std_logic_vector(31 downto 0) := X"00000000";
  constant USB_EP_IN_ADDR       : std_logic_vector(31 downto 0) := X"00000100";
  constant USB_GLOBAL_CTRL_ADDR : std_logic_vector(31 downto 0) := X"00000200";
  
-----------------------------------------------------------------------------
-- USB request constants
-----------------------------------------------------------------------------
  --BREQUEST CONSTANTS
  constant GET_STATUS        : std_logic_vector(7 downto 0) := X"00";
  constant CLEAR_FEATURE     : std_logic_vector(7 downto 0) := X"01";
  constant SET_FEATURE       : std_logic_vector(7 downto 0) := X"03";
  constant SET_ADDRESS       : std_logic_vector(7 downto 0) := X"05";
  constant GET_DESCRIPTOR    : std_logic_vector(7 downto 0) := X"06";
  constant SET_DESCRIPTOR    : std_logic_vector(7 downto 0) := X"07";
  constant GET_CONFIGURATION : std_logic_vector(7 downto 0) := X"08";
  constant SET_CONFIGURATION : std_logic_vector(7 downto 0) := X"09";
  constant GET_INTERFACE     : std_logic_vector(7 downto 0) := X"0A";
  constant SET_INTERFACE     : std_logic_vector(7 downto 0) := X"0B";
  constant SYNCH_FRAME       : std_logic_vector(7 downto 0) := X"0C";

  --WVALUE CONSTANTS
  constant DEVICE_REMOTE_WAKEUP : std_logic_vector(15 downto 0) := X"0100";
  constant ENDPOINT_HALT        : std_logic_vector(15 downto 0) := X"0000";
  constant TEST_MODE            : std_logic_vector(15 downto 0) := X"0200";

  --DESCRIPTOR TYPES
  constant DEVICE_T        : std_logic_vector(7 downto 0) := X"01";
  constant CONFIGURATION_T : std_logic_vector(7 downto 0) := X"02";
  constant DEVQUAL_T       : std_logic_vector(7 downto 0) := X"06";
  constant OSCONF_T        : std_logic_vector(7 downto 0) := X"07";

  --DEVICE DESCRIPTOR
  constant GRDD : DESCRIPTOR_TYPE(0 to 19) :=
    (X"12",                             --BLENGTH
     X"01",                             --BDESCRIPTORTYPE  = DEVICE
     X"10", X"02",                      --BCDUSB
     X"FF",                             --BDEVICECLASS
     X"00",                             --BDEVICESUBCLASS
     X"FF",                             --BDEVICEPROTOCOL
     X"40",                             --BMAXPACKETSIZE0  = 64 (ENDPOINT 0)
     X"81", X"17",                      --IDVENDOR 
     X"A0", X"0A",                      --IDPRODUCT
     X"00", X"00",                      --BCDDEVICE
     X"00",                             --IMANUFACTURER
     X"00",                             --IPRODUCT
     X"00",                             --ISERIALNUMBER    = No string descriptor
     X"01",                             --BNUMCONFIGURATIONS
     X"00",                             --PAD
     X"00"                              --PAD
     );

  --CONFIG+INTERFACE+2*ENDPOINT DESCRIPTOR
  constant GRCD : DESCRIPTOR_TYPE(0 to 31) :=
    --CONFIGURATION DESCRIPTOR
    (X"09",                             --BLENGTH
     X"02",                             --BDESCRIPTORTYPE  = CONFIGURATION
     X"20", X"00",                      --WTOTALLENGTH
     X"01",                             --BNUMINTERFACES
     X"01",                             --BCONFIGURATIONVALUE
     X"00",                             --ICONFIGURATION   = No string descriptor
     X"C0",                             --BMATTRIBUTES
     X"05",                             --BMAXPOWER

     --INTERFACE DESCRIPTOR
     X"09",                             --BLENGTH
     X"04",                             --BDESCRIPTORTYPE  =  INTERFACE
     X"00",                             --BINTERFACENUMBER
     X"00",                             --BALTERNATESETTING
     X"02",                             --BNUMENDPOINTS
     X"FF",                             --BINTERFACECLASS
     X"00",                             --BINTERFACESUBCLASS
     X"FF",                             --BINTERFACEPROTOCOL
     X"00",                             --IINTERFACE       = No string descriptor

     --ENDPOINT 1 BULK OUT
     X"07",                             --BLENGTH
     X"05",                             --BDESCRIPTORTYPE  = ENDPOINT
     X"01",                             --BENDPOINTADDRESS = 0=OUT, 1=Endpoint
     X"02",                             --BMATTRIBUTES     = Bulk
     X"00", X"02",                      --wMaxPacketSize   = 512
     X"01",                             --bInterval

     --ENDPOINT 1 BULK IN
     X"07",                             --bLength
     X"05",                             --bDescriptorType  = ENDPOINT
     X"81",                             --bEndpointAddress = 8=IN, 1=Endpoint
     X"02",                             --bmAttributes     = Bulk
     X"00", X"02",                      --wMaxPacketSize   = 512
     X"01"                              --bInterval
     );
  
-----------------------------------------------------------------------------
-- Main FSM
-----------------------------------------------------------------------------
  type fsm_state_type is (reset, init_memory, init_ep_out, init_ep_in, init_usb,
                          idle, usb_req, dcl_req,
                          usb_get_req, usb_get_req2, usb_err, usb_check_packet,
                          enable_ep1, disable_ep1, disable_ep1_IN, get_device_speed,
                          reenable_ep1, reenable_ep1_2, reenable_ep1_IN, reenable_ep1_IN_2,
                          clear_ep0_OUT, clear_ep0_OUT2, ep0_send, ep0_send2, send_desc,
                          wait_for_ack, validate_ack, clear_ack, clear_ack2, set_addr, 
                          dcl_get_req, dcl_get_req2, dcl_read_init, dcl_write, dcl_read,
                          dcl_send_packet, dcl_send_packet2, clear_ep1_OUT, clear_ep1_OUT2);
  type fsm_reg_type is record
    state          : fsm_state_type;
    count          : natural range 0 to 512;

    -- Used to keep track of the state of ep1
    ep1_out_halted : std_ulogic;
    ep1_in_halted  : std_ulogic;

    wait_for_ack   : std_ulogic;
    
    -- USB request fields
    bmRequestType  : std_logic_vector(7 downto 0);
    bRequest       : std_logic_vector(7 downto 0);
    wValue         : std_logic_vector(15 downto 0);
    wIndex         : std_logic_vector(15 downto 0);
    wLength        : std_logic_vector(15 downto 0);

    -- DCL request fields
    dcl_addr       : std_logic_vector(31 downto 0);
    dcl_length     : std_logic_vector(12 downto 0);
    dcl_write      : std_ulogic;
    
    address_set    : std_ulogic;
    config_done    : std_ulogic;
    error          : std_ulogic;
    speed          : std_ulogic;
  end record;

-----------------------------------------------------------------------------
-- Descriptor state tracker
-----------------------------------------------------------------------------
  type desc_reg_type is record
    ep0_in          : std_ulogic;
    ep0_out         : std_ulogic;
    ep1_in_A        : std_ulogic;
    ep1_in_B        : std_ulogic;
    ep1_out_A       : std_ulogic;
    ep1_out_B       : std_ulogic;
    last_write_addr : std_logic_vector(31 downto 0);

    ep1_out        : std_ulogic;        -- Tells if buffer A or B is active
    ep1_in         : std_ulogic;        -- Tells if buffer A or B is active
    ep1_in_desc    : std_logic_vector(ADDR_BITS-1 downto 0);
    ep1_in_buff    : std_logic_vector(ADDR_BITS-1 downto 0);
    ep1_out_desc   : std_logic_vector(ADDR_BITS-1 downto 0);
    ep1_out_buff   : std_logic_vector(ADDR_BITS-1 downto 0);
  end record;

  type desc_signals_type is record
    ep0_read    : std_ulogic;
    ep0_written : std_ulogic;
    ep1_read    : std_ulogic;
    ep1_written : std_ulogic;
  end record;
  
-----------------------------------------------------------------------------
-- FSM for the AHB connection to the USBDCTRL
-----------------------------------------------------------------------------
  type usb_ahb_state_type is (idle, write);
  
-----------------------------------------------------------------------------
-- Memory and its arbiter
-----------------------------------------------------------------------------
  -- Read arbitration
  type mem_read_state_type is (idle, dcl_read, ahb_read);
  type mem_read_reg_type is record
    state     : mem_read_state_type;
    ahb_grant : std_ulogic;
    dcl_grant : std_ulogic;
  end record;

  -- Write arbitration
  type mem_write_state_type is (idle, dcl_write, ahb_write, ahb_write_addr);
  type mem_write_reg_type is record
    state     : mem_write_state_type;
    ahb_grant : std_ulogic;
    dcl_grant : std_ulogic;
    addr      : std_logic_vector(ADDR_BITS-1 downto 0);
    write     : std_logic_vector(3 downto 0);
  end record;

  type mem_read_signal_type is record
    read_enable  : std_ulogic;
    read_addr    : std_logic_vector(ADDR_BITS-1 downto 0);
  end record;
  signal mem_read  : mem_read_signal_type;
  signal read_data : std_logic_vector(31 downto 0);

  type mem_write_signal_type is record
    write_enable : std_logic_vector(3 downto 0);
    write_addr   : std_logic_vector(ADDR_BITS-1 downto 0);
    write_data   : std_logic_vector(31 downto 0);
  end record;
  signal mem_write : mem_write_signal_type;
    
-----------------------------------------------------------------------------
-- AHB requests to the USBDCTRL AHB slave interface
-----------------------------------------------------------------------------
  type ahb_type is record
    req   : std_ulogic;
    write : std_ulogic;
    addr  : std_logic_vector(31 downto 0);
    data  : std_logic_vector(31 downto 0);
  end record;
  signal ahb_done      : std_ulogic;
  signal ahb_read_data : std_logic_vector(31 downto 0);

-----------------------------------------------------------------------------
-- DCL to memory signals
-----------------------------------------------------------------------------
  type dcl_memory_type is record
    req        : std_ulogic;
    grant      : std_ulogic;
    write      : std_ulogic;
    read_addr  : std_logic_vector(ADDR_BITS-1 downto 0);
    read_data  : std_logic_vector(31 downto 0);
    write_addr : std_logic_vector(ADDR_BITS-1 downto 0);
    write_data : std_logic_vector(31 downto 0);
  end record;

  type dcl_memory_in_type is record
    req        : std_ulogic;
    write      : std_ulogic;
    read_addr  : std_logic_vector(ADDR_BITS-1 downto 0);
    write_addr : std_logic_vector(ADDR_BITS-1 downto 0);
    write_data : std_logic_vector(31 downto 0);
  end record;

  type dcl_memory_out_type is record
    read_data   : std_logic_vector(31 downto 0);
  end record;
  signal dclo : dcl_memory_out_type;
  
-----------------------------------------------------------------------------
-- For communcation with the USBDCTRL
-----------------------------------------------------------------------------
  signal usb_ahbmi : ahb_mst_in_type;   -- Used for memory DMA accesses
  signal usb_ahbmo : ahb_mst_out_type;  -- Used for memory DMA accesses
  signal usb_ahbsi : ahb_slv_in_type;   -- Used for controlling the USBDCTRL
  signal usb_ahbso : ahb_slv_out_type;  -- Used for controlling the USBDCTRL

-----------------------------------------------------------------------------
-- For communcation with the AHB master interface
-----------------------------------------------------------------------------
  signal dmai : ahb_dma_in_type;
  signal dmao : ahb_dma_out_type;

-------------------------------------------------------------------------------
-- All registers combined into a single record
-------------------------------------------------------------------------------
  type all_reg_type is record
    main      : fsm_reg_type;
    mem_read  : mem_read_reg_type;
    mem_write : mem_write_reg_type;
    ahb       : ahb_type;
    desc      : desc_reg_type;
    usb_ahb   : usb_ahb_state_type;
  end record;

  signal r    : all_reg_type;
  signal r_in : all_reg_type;

-------------------------------------------------------------------------------
-- The main FSM, which handles USB and DCL requests
-------------------------------------------------------------------------------
  procedure main_fsm(
    r             : in    all_reg_type;          -- Current state
    v             : inout all_reg_type;          -- Updated state
    dmao          : in    ahb_dma_out_type;      -- Signals returned by the main AHB master
    ahb_done      : in    std_ulogic;
    ahb_read_data : in    std_logic_vector(31 downto 0);
    dmai          : out   ahb_dma_in_type;       -- Request accesses on the main AHB
    dclo          : in    dcl_memory_out_type;   -- Signals returned by the memory/arbiter
    dcli          : out   dcl_memory_in_type;    -- Request memory accesses
    desc          : out   desc_signals_type) is  -- Update the descriptor state
  begin
    dcli.req         := '0';
    dcli.write       := '0';
    dcli.read_addr   := (others => '0');
    dcli.write_addr  := (others => '0');
    dcli.write_data  := (others => '0');
    desc.ep0_written := '0';
    desc.ep0_read    := '0';
    desc.ep1_written := '0';
    desc.ep1_read    := '0';
    dmai.address     := (others => '0');
    dmai.start       := '0';
    dmai.burst       := '0';
    dmai.write       := '0';
    dmai.busy        := '0';
    dmai.irq         := '0';
    dmai.size        := "10";
    dmai.wdata       := dclo.read_data;

    case r.main.state is
      when reset =>
        v.main.state := init_memory;
        v.main.count := 0;

      -- Need to write the descriptors to memory
      when init_memory =>
        dcli.req        := '1';
        dcli.write      := '1';
        dcli.write_addr := DESC_EP1_OUT_A(ADDR_BITS-1 downto 5) & conv_std_logic_vector(v.main.count, 5);
        dcli.write_data := DEFAULT_DESC(r.main.count);
        if r.mem_write.dcl_grant = '1' then
          v.main.count  := r.main.count + 1;
        end if;
        if r.main.count = 17 then
          v.main.state  := init_ep_out;
          v.main.count  := 0;
          v.ahb.req     := '1';
          v.ahb.write   := '1';
          v.ahb.addr    := USB_EP_OUT_ADDR;
          v.ahb.data    := DEFAULT_OUT_EP(0);
        end if;

      -- Need to set up control registers in USBDCTRL
      when init_ep_out =>
        if ahb_done = '1' then
          if r.main.count = 2 then
            v.main.state := init_ep_in;
            v.main.count := 0;
            v.ahb.addr   := USB_EP_IN_ADDR;
            v.ahb.data   := DEFAULT_IN_EP(0);
          else
            v.main.count := r.main.count + 1;
            v.ahb.addr   := USB_EP_OUT_ADDR(31 downto 5) & conv_std_logic_vector(v.main.count, 3) & "00";
            v.ahb.data   := DEFAULT_OUT_EP(v.main.count);
          end if;
        end if;

      when init_ep_in =>
        if ahb_done = '1' then
          if r.main.count = 2 then
            v.main.state := init_usb;
            v.ahb.addr   := USB_GLOBAL_CTRL_ADDR;
            v.ahb.data   := USB_GLOBAL_CTRL_REG;
          else
            v.main.count := r.main.count + 1;
            v.ahb.addr   := USB_EP_IN_ADDR(31 downto 5) & conv_std_logic_vector(v.main.count, 3) & "00";
            v.ahb.data   := DEFAULT_IN_EP(v.main.count);
          end if;
        end if;

      when init_usb =>
        if ahb_done = '1' then
          v.main.state := idle;
          v.ahb.req    := '0';
        end if;
        -- Wait for incoming packets

      when idle =>
        dcli.req         := r.desc.ep0_out or r.desc.ep1_out_A or r.desc.ep1_out_B;
        -- Incoming packet on ep0
        if r.desc.ep0_out = '1' then
          dcli.read_addr := DESC_EP0_OUT(ADDR_BITS-1 downto 0);
          -- Incoming packet on ep1
        elsif r.desc.ep1_out_A = '1' or r.desc.ep1_out_B = '1' then
          dcli.read_addr := r.desc.ep1_out_buff;  -- Address of current buffer
        end if;
        if r.mem_read.dcl_grant = '1' then
          if r.desc.ep0_out = '1' then
            v.main.state := usb_check_packet;
          else
            v.main.state := dcl_get_req;
          end if;
        end if;

      -------------------------------------------------------------------------
      -- USB request packet received
      -------------------------------------------------------------------------
      when usb_check_packet =>
        dcli.req       := '1';
        dcli.read_addr := EP0_OUT(ADDR_BITS-1 downto 0);
        -- Check if packet is not a setup packet or
        -- not of 8 bytes length
        if dclo.read_data(17) = '0' or dclo.read_data(12 downto 0)/='0'&X"008" then
          v.main.state := clear_ep0_OUT;
          v.main.error := '1';
        else
          v.main.state := usb_get_req;
        end if;

      when usb_get_req =>
        dcli.req             := '1';
        dcli.read_addr       := EP0_OUT(ADDR_BITS-1 downto 1) & "1";
        v.main.state         := usb_get_req2;
        v.main.bmRequestType := dclo.read_data(31 downto 24);
        v.main.bRequest      := dclo.read_data(23 downto 16);
        v.main.wValue        := dclo.read_data(7 downto 0) & dclo.read_data(15 downto 8);

      when usb_get_req2 =>
        v.main.state   := clear_ep0_OUT;
        v.main.wIndex  := dclo.read_data(23 downto 16) & dclo.read_data(31 downto 24);
        v.main.wLength := dclo.read_data(7 downto 0) & dclo.read_data(15 downto 8);
        -- Enable ep0 OUT descriptor, since it's been read

      when clear_ep0_OUT =>
        dcli.req        := '1';
        dcli.write      := '1';
        dcli.write_addr := DESC_EP0_OUT(ADDR_BITS-1 downto 0);
        dcli.write_data := EP0_OUT_CTRL(31 downto 14) & "10" & X"000";
        if r.mem_write.dcl_grant = '1' then
          v.main.state  := clear_ep0_OUT2;
          desc.ep0_read := '1';         -- Notify the descriptor state tracker
          -- that buffer has been read
          -- Write to ep0 OUT DMA control register telling descriptor available (DA=1)
          v.ahb.req     := '1';
          v.ahb.write   := '1';
          v.ahb.addr    := USB_EP_OUT_ADDR(31 downto 4) & X"4";
          v.ahb.data    := USB_EP0_OUT_DMA_CTRL(31 downto 1) & '1';
        end if;

      when clear_ep0_OUT2 =>
        if ahb_done = '1' then
          v.ahb.req      := '0';
          if r.main.error = '1' then
            v.main.state := usb_err;
          else
            v.main.state := usb_req;
          end if;
        end if;

      when usb_req           =>
        case r.main.bRequest is
          when CLEAR_FEATURE =>
            -- Only supports ENDPOINT_HALT for ep1 when configured
            if r.main.config_done = '1' and r.main.wValue = ENDPOINT_HALT and r.main.bmRequestType = X"02" and r.main.wIndex(3 downto 0) = X"1" then
              v.ahb.req               := '1';
              v.ahb.write             := '1';
              v.ahb.data              := USB_EP1_OUT_CTRL(31 downto 2) & "01";
              if r.main.wIndex(7) = '0' then  -- OUT ep1
                v.ahb.addr             := USB_EP_OUT_ADDR(31 downto 8) & X"10";
                v.main.ep1_out_halted := '0';
              else                      -- IN  ep1
                v.ahb.addr            := USB_EP_IN_ADDR(31 downto 8) & X"10";
                v.main.ep1_in_halted  := '0';
              end if;
              if ahb_done = '1' then
                v.main.state          := ep0_send;  -- Send 0 length packet as ACK
                v.main.count          := 0;
                v.ahb.req             := '0';
              end if;
            else
              v.main.state            := usb_err;
            end if;

          when GET_CONFIGURATION           =>
            dcli.write_addr     := EP0_IN(ADDR_BITS-1 downto 0);
            -- Address not even set so no configuration given
            if r.main.address_set = '0' or r.main.bmRequestType/=X"80" or r.main.wValue/=X"0000" or r.main.wIndex/=X"0000" or r.main.wLength/=X"0001" then
              v.main.state      := usb_err;
              -- Device not configured, return zero
            elsif r.main.config_done = '0' then
              -- ep0 IN buffer empty
              if r.desc.ep0_in = '0' then
                dcli.req        := '1';
                dcli.write      := '1';
                dcli.write_data := (others => '0');
              end if;
              -- Return the only configuration we got = 1
            else
              -- ep0 IN buffer empty
              if r.desc.ep0_in = '0' then
                dcli.req        := '1';
                dcli.write      := '1';
                dcli.write_data := X"01000000";
              end if;
            end if;
            -- Configuration written to memory, send 1 byte packaged
            if r.mem_write.dcl_grant = '1' then
              v.main.state      := ep0_send;
              v.main.count      := 1;
            end if;

          when GET_DESCRIPTOR        =>
            v.main.count           := 0;
            if r.main.wIndex/=X"0000" or r.main.bmRequestType/=X"80" or r.main.wValue(7 downto 0)/=X"00" then
              v.main.state         := usb_err;
              -- Wait until a buffer is available to store the descriptor in
            elsif r.desc.ep0_in = '0' then
              v.main.state         := send_desc;
              case r.main.wValue(15 downto 8) is
                when DEVICE_T        =>
                  if r.main.wLength > X"0012" then
                    v.main.wLength := X"0012";
                  end if;
                when CONFIGURATION_T =>
                  if r.main.wLength > X"0020" then
                    v.main.wLength := X"0020";
                  end if;
                when DEVQUAL_T       =>
                  if r.main.wLength > X"000A" then
                    v.main.wLength := X"000A";
                  end if;
                when OSCONF_T        =>
                  v.main.state     := get_device_speed;
                  v.ahb.req        := '1';
                  v.ahb.write      := '0';
                  v.ahb.addr       := USB_GLOBAL_CTRL_ADDR(31 downto 4) & X"4";
                  if r.main.wLength > X"0020" then
                    v.main.wLength := X"0020";
                  end if;
                when others          =>
                  v.main.state     := usb_err;
              end case;
            end if;

          when GET_INTERFACE =>
            if r.main.config_done = '0' or r.main.bmRequestType/=X"81" or r.main.wIndex/=X"0000" or r.main.wLength/=X"0001" or r.main.wValue/=X"0000" then
              v.main.state    := usb_err;
              -- Write the interface once ep0 IN is empty  
            elsif r.desc.ep0_in = '0' then
              dcli.req        := '1';
              dcli.write      := '1';
              dcli.write_addr := EP0_IN(ADDR_BITS-1 downto 0);
              dcli.write_data := X"00000000";
            end if;
            -- Interface written to memory, send 1 byte package
            if r.mem_write.dcl_grant = '1' then
              v.main.state    := ep0_send;
              v.main.count    := 1;
            end if;

          when GET_STATUS       =>
            -- Invalid befor address is set
            if r.main.address_set = '0' or r.main.bmRequestType(7 downto 2)/=X"8"&"00" or r.main.bmRequestType(1 downto 0) = "11" or r.main.wLength/=X"0002" or r.main.wValue/=X"0000" then
              v.main.state            := usb_err;
              -- Only status of device or ep0 can be read before configured
            elsif r.main.config_done = '0' and (r.main.wIndex(3 downto 0)/=X"0" or r.main.bmRequestType = X"81") then
              v.main.state            := usb_err;
              -- Write the status once ep0 IN is empty
            elsif r.desc.ep0_in = '0' then
              dcli.req                := '1';
              dcli.write              := '1';
              dcli.write_addr         := EP0_IN(ADDR_BITS-1 downto 0);
              case r.main.bmRequestType is
                when X"80"      =>
                  if r.main.wIndex(7 downto 0) = X"00" then
                    dcli.write_data   := X"01000000";  -- Self powered, no remote wakeup
                  else
                    dcli.req          := '0';
                    v.main.state      := usb_err;  -- No such interface
                  end if;
                when X"81"      =>
                  if r.main.wIndex(7 downto 0) = X"00" then
                    dcli.write_data   := X"00000000";  -- Self powered, no remote wakeup
                  else
                    dcli.req          := '0';
                    v.main.state      := usb_err;  -- No such interface
                  end if;
                when others     =>
                  case r.main.wIndex(7 downto 0) is
                    when X"00"  =>      -- ep0 OUT
                      dcli.write_data := X"00000000";
                    when X"80"  =>      -- ep0 IN
                      dcli.write_data := X"00000000";
                    when X"01"  =>      -- ep1 OUT
                      dcli.write_data := "0000000" & r.main.ep1_out_halted & X"000000";
                    when X"81"  =>      -- ep1 OUT
                      dcli.write_data := "0000000" & r.main.ep1_in_halted & X"000000";
                    when others =>
                      dcli.req        := '0';
                      v.main.state    := usb_err;
                  end case;
              end case;
              -- Status written to memory, send 2 byte package
              if r.mem_write.dcl_grant = '1' then
                v.main.state          := ep0_send;
                v.main.count          := 2;
              end if;
            end if;

          when SET_ADDRESS =>
            v.main.state       := set_addr;
            v.main.address_set := '1';
            -- Set the address in the USBDCTRL
            v.ahb.req          := '1';
            v.ahb.write        := '1';
            v.ahb.addr         := USB_GLOBAL_CTRL_ADDR;
            v.ahb.data         := USB_GLOBAL_CTRL_REG(31 downto 8) & r.main.wValue(6 downto 0) & '1';

          when SET_CONFIGURATION =>
            if r.main.address_set = '0' then
              v.main.state         := usb_err;
            elsif r.main.config_done = '0' then
              -- Use the only configuration supported
              if r.main.wValue = X"0001" then
                v.main.config_done := '1';
                v.main.state       := enable_ep1;
                v.main.count       := 0;
                v.ahb.req          := '1';
                v.ahb.write        := '1';
                v.ahb.addr         := ENABLE_EP1_ADDR(0);
                v.ahb.data         := ENABLE_EP1_DATA(0);
                -- Configuration not supported
              elsif r.main.wValue /= X"0000" then
                v.main.state       := usb_err;
              end if;
            elsif r.main.config_done = '1' then
              -- Configuration 0 puts us in USB address state
              if r.main.wValue = X"0000" then
                v.main.config_done := '0';
                v.main.state       := disable_ep1;
                -- Trying to switch to unsuported state
              elsif r.main.wValue /= X"0001" then
                v.main.state       := usb_err;
              else
                --Already configured so ep1 need to be disabled and
                --then enabled
                v.main.state       := reenable_ep1;
              end if;
            end if;

          when SET_DESCRIPTOR =>
            -- Optional not implemented
            v.main.state := usb_err;

          when SET_FEATURE =>
            -- Enable test-mode
            if r.main.bmRequestType = X"00" and r.main.wValue = X"0002" and r.main.wLength = X"0000" and (r.main.wIndex(15 downto 0) = X"0001" or r.main.wIndex(15 downto 0) = X"0002" or r.main.wIndex(15 downto 0) = X"0003" or r.main.wIndex(15 downto 0) = X"0004") then
              v.ahb.req               := '1';
              v.ahb.write             := '1';
              v.ahb.addr              := USB_GLOBAL_CTRL_ADDR;
              v.ahb.data              := USB_GLOBAL_CTRL_REG(31 downto 12) & r.main.wIndex(2 downto 0) & '1' & X"00";
              -- Only supports set ENPOINT_HALT for ep1 when configured
            elsif r.main.config_done = '1' and r.main.wValue = ENDPOINT_HALT and r.main.bmRequestType = X"02" and r.main.wIndex(3 downto 0) = X"1" then
              v.ahb.req               := '1';
              v.ahb.write             := '1';
              v.ahb.data              := USB_EP1_OUT_CTRL(31 downto 3) & "101";
              if r.main.wIndex(7) = '0' then  -- OUT ep1
                v.ahb.addr            := USB_EP_OUT_ADDR(31 downto 8) & X"10";
                v.main.ep1_out_halted := '0';
              else                      -- IN  ep1
                v.ahb.addr            := USB_EP_IN_ADDR(31 downto 8) & X"10";
                v.main.ep1_in_halted  := '0';
              end if;
              -- Feature not supported
            else
              v.main.state            := usb_err;
            end if;
            if ahb_done = '1' then
              v.main.state            := ep0_send;  -- Send 0 length packet as ACK
              v.main.count            := 0;
              v.ahb.req               := '0';
            end if;

          when SET_INTERFACE =>
            -- Only default interface supported
            v.main.state := usb_err;

          when SYNCH_FRAME =>
            -- This feature is not supported
            v.main.state := usb_err;

          when others =>
            -- Any other request is answered with an error
            v.main.state := usb_err;
        end case;

      when get_device_speed =>
        if ahb_done = '1' then
          v.ahb.req    := '0';
          v.main.state := send_desc;
          v.main.speed := ahb_read_data(14);
        end if;

      when set_addr =>
        -- Send ACK to indicate that the address has been updated
        if ahb_done = '1' then
          v.main.state := ep0_send;
          v.main.count := 0;
          v.ahb.req    := '0';
        end if;

      when send_desc           =>
        dcli.req                            := '1';
        dcli.write                          := '1';
        dcli.write_addr                     := EP0_IN(ADDR_BITS-1 downto 4) & conv_std_logic_vector(r.main.count, 4);
        case r.main.wValue(15 downto 8) is
          when DEVICE_T        =>
            dcli.write_data(31 downto 24)   := GRDD(r.main.count*4);
            dcli.write_data(23 downto 16)   := GRDD(1+r.main.count*4);
            dcli.write_data(15 downto 8)    := GRDD(2+r.main.count*4);
            dcli.write_data(7 downto 0)     := GRDD(3+r.main.count*4);
          when CONFIGURATION_T =>
            dcli.write_data(31 downto 24)   := GRCD(r.main.count*4);
            dcli.write_data(23 downto 16)   := GRCD(1+r.main.count*4);
            dcli.write_data(15 downto 8)    := GRCD(2+r.main.count*4);
            dcli.write_data(7 downto 0)     := GRCD(3+r.main.count*4);
          when OSCONF_T        =>
            dcli.write_data(31 downto 24)   := GRCD(r.main.count*4);
            dcli.write_data(23 downto 16)   := GRCD(1+r.main.count*4);
            dcli.write_data(15 downto 8)    := GRCD(2+r.main.count*4);
            dcli.write_data(7 downto 0)     := GRCD(3+r.main.count*4);
            if r.main.count = 0 then
              dcli.write_data(23 downto 16) := X"07";
            end if;
            if r.main.count = 7 and (r.main.speed = '0') then
              dcli.write_data(23 downto 16) := X"40";
              dcli.write_data(15 downto 8)  := X"00";
            end if;
            if r.main.count = 5 and (r.main.speed = '0') then
              dcli.write_data(15 downto 8)  := X"40";
              dcli.write_data(7 downto 0)   := X"00";
            end if;
          when others          =>       -- DEVICE QUALIFIER
            if r.main.count = 0 then
              dcli.write_data(31 downto 24) := X"0A";
              dcli.write_data(23 downto 16) := X"06";
              dcli.write_data(15 downto 8)  := GRDD(2+r.main.count*4);
              dcli.write_data(7 downto 0)   := GRDD(3+r.main.count*4);
            elsif r.main.count = 1 then
              dcli.write_data(31 downto 24) := GRDD(r.main.count*4);
              dcli.write_data(23 downto 16) := GRDD(1+r.main.count*4);
              dcli.write_data(15 downto 8)  := GRDD(2+r.main.count*4);
              dcli.write_data(7 downto 0)   := GRDD(3+r.main.count*4);
            else
              dcli.write_data(31 downto 24) := X"01";
              dcli.write_data(23 downto 16) := X"00";
            end if;
        end case;
        if r.mem_write.dcl_grant = '1' then
          v.main.count                      := r.main.count + 1;
        end if;
        -- The configuration has been written to the buffer
        if v.main.count*4 >= conv_integer(r.main.wLength) then
          v.main.state                      := ep0_send;
          v.main.count                      := conv_integer(r.main.wLength);
        end if;
        -- This is a fix, since we are sending a zero length packet we
        -- need to wait for an ACK. Zero length packets are commonly
        -- used to identify that we are sending the ACK
        if r.main.wLength = X"0000" then
          v.main.wait_for_ack               := '1';
        end if;

      when enable_ep1 =>
        -- ep1 has been enabled
        if ahb_done = '1' and r.main.count = 5 then
          v.main.state := ep0_send;     -- Send 0 length packet as ACK
          v.main.count := 0;
          v.ahb.req    := '0';
        elsif ahb_done = '1' then
          v.main.count := r.main.count + 1;
          v.ahb.addr   := ENABLE_EP1_ADDR(v.main.count);
          v.ahb.data   := ENABLE_EP1_DATA(v.main.count);
        end if;

      when disable_ep1 =>
        v.ahb.req      := '1';
        v.ahb.write    := '1';
        v.ahb.data     := USB_EP1_OUT_CTRL(31 downto 1) & '0';
        v.ahb.addr     := USB_EP_OUT_ADDR(31 downto 8) & X"10";
        if ahb_done = '1' then
          v.main.state := disable_ep1_IN;
          v.ahb.addr   := USB_EP_IN_ADDR(31 downto 8) & X"10";
        end if;

      when disable_ep1_IN =>
        if ahb_done = '1' then
          v.main.state := ep0_send;     -- Send 0 length packet as ACK
          v.main.count := 0;
          v.ahb.req    := '0';
        end if;

      when reenable_ep1 =>
        v.ahb.req      := '1';
        v.ahb.write    := '1';
        v.ahb.data     := USB_EP1_OUT_CTRL(31 downto 1) & '0';
        v.ahb.addr     := USB_EP_OUT_ADDR(31 downto 8) & X"10";
        if ahb_done = '1' then
          v.main.state := reenable_ep1_2;
          v.ahb.data   := USB_EP1_OUT_CTRL(31 downto 1) & '1';
        end if;

      when reenable_ep1_2 =>
        if ahb_done = '1' then
          v.main.state := reenable_ep1_IN;   
          v.ahb.data   := USB_EP1_OUT_CTRL(31 downto 1) & '0';
          v.ahb.addr   := USB_EP_IN_ADDR(31 downto 8) & X"10";
        end if;

      when reenable_ep1_IN =>
        if ahb_done = '1' then
          v.main.state := reenable_ep1_IN_2;   
          v.ahb.data   := USB_EP1_OUT_CTRL(31 downto 1) & '1';
          v.ahb.addr   := USB_EP_IN_ADDR(31 downto 8) & X"10";
        end if;
        
      when reenable_ep1_IN_2 =>
        if ahb_done = '1' then
          v.main.state := ep0_send;
          v.main.count := 0;
          v.ahb.req    := '0';
        end if;
        
      when ep0_send =>
        -- Enable ep0 IN buffer by updating the descriptor
        dcli.req        := '1';
        dcli.write      := '1';
        dcli.write_addr := DESC_EP0_IN(ADDR_BITS-1 downto 0);
        dcli.write_data := EP0_IN_CTRL(31 downto 14) & '1' & conv_std_logic_vector(r.main.count, 13);

        if r.mem_write.dcl_grant = '1' then
          v.main.state     := ep0_send2;
          desc.ep0_written := '1';      -- Notify the descriptor state tracker
                                        -- that buffer has been written to
          -- Write to ep0 IN DMA control register telling descriptor available (DA=1)
          v.ahb.req        := '1';
          v.ahb.write      := '1';
          v.ahb.addr       := USB_EP_IN_ADDR(31 downto 4) & X"4";
          v.ahb.data       := USB_EP0_IN_DMA_CTRL(31 downto 1) & '1';
        end if;

      when ep0_send2 =>
        if ahb_done = '1' then
          v.ahb.req             := '0';
          -- If count = 0 then a ACK has been sent and we are done
          if r.main.count = 0 and r.main.wait_for_ack = '0' then
            v.main.state        := idle;
            -- Else data has been sent to host and we need to wait for an ACK
          else
            v.main.state        := wait_for_ack;
            v.main.wait_for_ack := '0';
          end if;
        end if;

      when wait_for_ack =>
        dcli.req       := r.desc.ep0_out;
        dcli.read_addr := DESC_EP0_OUT(ADDR_BITS-1 downto 0);
        -- Incoming packet on ep0
        if r.mem_read.dcl_grant = '1' then
          v.main.state := validate_ack;
        end if;

      when validate_ack =>
        v.main.state   := clear_ack;
        -- Setup packet of 0 bytes length
        if dclo.read_data(17) = '1' or dclo.read_data(12 downto 0)/='0'&X"000" then
          v.main.error := '1';
        end if;
        -- Enable ep0 OUT descriptor, since ACK has been read

      when clear_ack =>
        dcli.req        := '1';
        dcli.write      := '1';
        dcli.write_addr := DESC_EP0_OUT(ADDR_BITS-1 downto 0);
        dcli.write_data := EP0_OUT_CTRL(31 downto 14) & "10" & X"000";
        if r.mem_write.dcl_grant = '1' then
          v.main.state  := clear_ack2;
          desc.ep0_read := '1';         -- Notify the descriptor state tracker
                                        -- that buffer has been read
          -- Write to ep0 OUT DMA control register telling descriptor available (DA=1)
          v.ahb.req     := '1';
          v.ahb.addr    := USB_EP_OUT_ADDR(31 downto 4) & X"4";
          v.ahb.data    := USB_EP0_OUT_DMA_CTRL(31 downto 1) & '1';
        end if;

      when clear_ack2 =>
        if ahb_done = '1' then
          v.ahb.req      := '0';
          if r.main.error = '0' then
            v.main.state := idle;
          else
            v.main.state := usb_err;
          end if;
        end if;

      when usb_err =>
        v.ahb.req  := '1';
        v.ahb.addr := USB_EP_IN_ADDR;
        v.ahb.data := USB_EP0_IN_CTRL(31 downto 19) & '1' & USB_EP0_OUT_CTRL(17 downto 0);

        if ahb_done = '1' then
          v.main.state := idle;
          v.main.error := '0';
          v.ahb.req    := '0';
        end if;

      -------------------------------------------------------------------------
      -- DCL packet received
      -------------------------------------------------------------------------
      -- NOTE
      -- Accesses made on the AHB bus wrapps at 1KB bounderies. It is up to the
      -- DCL user to make sure that a packet wont cross these bounderies
      -------------------------------------------------------------------------
      when dcl_get_req =>
        v.main.state    := dcl_get_req2;
        v.main.dcl_addr := dclo.read_data;
        dcli.req        := '1';
        dcli.read_addr  := r.desc.ep1_out_buff(ADDR_BITS-1 downto 1) & '1';

      when dcl_get_req2 =>
        v.main.dcl_write  := dclo.read_data(31);
        v.main.dcl_length := dclo.read_data(14 downto 2);
        v.main.count      := 0;
        -- Zero length write access - do nothing
        if v.main.dcl_length = '0'&X"000" and v.main.dcl_write = '1' then
          v.main.state    := clear_ep1_OUT;
          -- Zero length read access - send 0 length packet
        elsif v.main.dcl_length = '0'&X"000" and v.main.dcl_write = '0' then
          v.main.state    := dcl_send_packet;
          -- DCL read
        elsif v.main.dcl_write = '0' then
          v.main.state    := dcl_read_init;
          -- DCL write
        else
          v.main.state    := dcl_write;
          dcli.req        := '1';
        end if;

      when dcl_read_init =>
        -- Buffer available
        if r.desc.ep1_in_A = '0' or r.desc.ep1_in_B = '0' then
          -- Making sure that we are granted access to the memory by
          -- writing anything to the first location of the buffer
          dcli.req        := '1';
          dcli.write      := '1';
          dcli.write_addr := r.desc.ep1_in_buff(ADDR_BITS-1 downto 7) & conv_std_logic_vector(r.main.count, 7);
          dcli.write_data := dmao.rdata;
        end if;
        -- Write access to the buffers
        if r.mem_write.dcl_grant = '1' then
          v.main.state    := dcl_read;
        end if;

      -- Read data from AHB and write it to buffer
      when dcl_read      =>
        -- Write received data to buffer
        dcli.req          := '1';
        dcli.write        := '1';
        dcli.write_addr   := r.desc.ep1_in_buff(ADDR_BITS-1 downto 7) & conv_std_logic_vector(r.main.count, 7);
        dcli.write_data   := dmao.rdata;

        if conv_integer(r.main.dcl_length) > 1 then
          dmai.burst := '1';
        end if;
        dmai.start   := '1';
        dmai.address := r.main.dcl_addr;

        if dmao.ready = '1' then
          v.main.count    := r.main.count + 1;
          v.main.dcl_addr := r.main.dcl_addr + 4; --(31 downto ADDR_BITS) & dmao.haddr;
          if r.main.dcl_addr(9 downto 2) = X"FF" then
            dmai.start    := '0';
          end if;
          if r.main.count = conv_integer(r.main.dcl_length(12 downto 0)) then
            v.main.state  := dcl_send_packet;
            dmai.start    := '0';
          end if;
        end if;
      
      -- Read data from buffer and write it on AHB
      when dcl_write =>
        dmai.start        := '1';
        dmai.write        := '1';
        dmai.address      := r.main.dcl_addr;
        if conv_integer(r.main.dcl_length) > 1 then
          dmai.burst      := '1';
        end if;
        dcli.req          := '1';
        if dmao.ready = '1' then
          v.main.count    := r.main.count + 1;
          v.main.dcl_addr := r.main.dcl_addr + 4; --(31 downto ADDR_BITS) & dmao.haddr;
          if r.main.dcl_addr(9 downto 2) = X"FF" then
            dmai.start    := '0';
          end if;
          if v.main.count = conv_integer(r.main.dcl_length(12 downto 0)) then
            v.main.state  := clear_ep1_OUT;
            dcli.req      := '0';
            dmai.start    := '0';
          end if;
        end if;
        dcli.read_addr    := r.desc.ep1_out_buff(ADDR_BITS-1 downto 7) & conv_std_logic_vector(v.main.count + 2, 7);

      when dcl_send_packet =>
        -- Enable ep1 IN buffer by updating the descriptor
        dcli.req        := '1';
        dcli.write      := '1';
        dcli.write_addr := r.desc.ep1_in_desc;
        dcli.write_data := EP1_IN_CTRL(31 downto 14) & '1' & r.main.dcl_length(10 downto 0) & "00";

        if r.mem_write.dcl_grant = '1' then
          v.main.state     := dcl_send_packet2;
          desc.ep1_written := '1';      -- Notify the descriptor state tracker
                                        -- that buffer has been written to
          -- Write to ep1 IN DMA control register telling descriptor available (DA=1)
          v.ahb.req        := '1';
          v.ahb.addr       := USB_EP_IN_ADDR(31 downto 8) & X"14";
          v.ahb.data       := USB_EP1_IN_DMA_CTRL(31 downto 1) & '1';
        end if;

      when dcl_send_packet2 =>
        if ahb_done = '1' then
          v.main.state := clear_ep1_OUT;
          v.ahb.req    := '0';
        end if;
        -- Enable ep1 OUT descriptor, since it's been read

      when clear_ep1_OUT =>
        dcli.req        := '1';
        dcli.write      := '1';
        dcli.write_addr := r.desc.ep1_out_desc;
        dcli.write_data := EP1_OUT_CTRL(31 downto 14) & "10" & X"000";

        if r.mem_write.dcl_grant = '1' then
          v.main.state  := clear_ep1_OUT2;
          desc.ep1_read := '1';         -- Notify the descriptor state tracker
                                        -- that buffer had been read
          -- Write to ep1 OUT DMA control register telling descriptor available (DA=1)
          v.ahb.req     := '1';
          v.ahb.addr    := USB_EP_OUT_ADDR(31 downto 8) & X"14";
          v.ahb.data    := USB_EP1_OUT_DMA_CTRL(31 downto 1) & '1';
        end if;

      when clear_ep1_OUT2 =>
        if ahb_done = '1' then
          v.main.state := idle;
          v.ahb.req    := '0';
        end if;
      when others         => null;
    end case;
  end;

-------------------------------------------------------------------------------
-- Memory read arbiter
-- usb_ahbmo - USB memory requests
-- dcli      - main FSM memory requests
-------------------------------------------------------------------------------
  procedure mem_read_arbiter(
           r           : in    all_reg_type;          -- Current state
           v           : inout all_reg_type;          -- Updated state
           mem_read    : out   mem_read_signal_type;
           usb_ahbmo   : in    ahb_mst_out_type;
           dcli        : in    dcl_memory_in_type;    -- Request memory accesses
           read_data   : in    std_logic_vector(31 downto 0);
           usb_ahbmi   : out   ahb_mst_in_type;
    signal dclo        : out   dcl_memory_out_type) is
  begin
    case r.mem_read.state is
      when idle =>
        -- The DCL is given higher priority
        if (dcli.req = '1') and (dcli.write = '0') then
          v.mem_read.state     := dcl_read;
          v.mem_read.dcl_grant := '1';
        elsif (usb_ahbmo.hbusreq = '1') and (usb_ahbmo.hwrite = '0') then
          v.mem_read.state     := ahb_read;
          v.mem_read.ahb_grant := '1';
        end if;
      -- The DCL accesses the memory directly,
      -- without any involvement of this FSM
      when dcl_read =>
        if dcli.req = '0' then
          v.mem_read.state     := idle;
          v.mem_read.dcl_grant := '0';
        end if;
      -- The USBCTRL accesses the memory through AHB accesses
      -- Since the memory will output data for a specific address the cycle
      -- after we can directly allow haddr to be connected to the address port
      -- and hrdata to the data port
      -- No error checking, assuming correct AHB behaviour of the USBCTRL
      when ahb_read =>
        -- End of transaction
        if (usb_ahbmo.hbusreq = '0') or (usb_ahbmo.htrans = "00") then
          v.mem_read.state     := idle;
          v.mem_read.ahb_grant := '0';
        end if;
      when others => null;
    end case;

    -- Read MUX
    if r.mem_read.ahb_grant = '1' then
      mem_read.read_addr := usb_ahbmo.haddr(ADDR_BITS+1 downto 2);
    else
      mem_read.read_addr := dcli.read_addr;
    end if;
    mem_read.read_enable := r.mem_read.ahb_grant or r.mem_read.dcl_grant;
    usb_ahbmi.hrdata     := read_data;
    dclo.read_data       <= read_data;
  end;

-------------------------------------------------------------------------------
-- Memory write arbiter
-- usb_ahbmo - USB memory requests
-- dcli      - main FSM memory requests
-------------------------------------------------------------------------------
  procedure mem_write_arbiter(
    r         : in    all_reg_type;          -- Current state
    v         : inout all_reg_type;          -- Updated state
    mem_write : out   mem_write_signal_type;
    usb_ahbmo : in    ahb_mst_out_type;
    dcli      : in    dcl_memory_in_type) is -- Request memory accesses
  begin
    v.mem_write.write := (others => '0');
    case r.mem_write.state is
      when idle   =>
        -- The DCL is given higher priority
        if (dcli.req='1') and (dcli.write='1') then
          v.mem_write.state     := dcl_write;
          v.mem_write.dcl_grant := '1';
        elsif (usb_ahbmo.hbusreq='1') and (usb_ahbmo.hwrite='1') then
          v.mem_write.state     := ahb_write_addr;
          v.mem_write.ahb_grant := '1';
        end if;
      -- The DCL accesses the memory directly,
      -- without any involvement of this FSM
      when dcl_write =>
        if dcli.req = '0' then
          v.mem_write.state     := idle;
          v.mem_write.dcl_grant := '0';
        end if;
      -- The USBCTRL accesses the memory through AHB accesses,
      -- so we have to act as a slave interface
      -- No error checking, assuming correct AHB behaviour of the USBCTRL
      when ahb_write_addr =>
        -- Get the first address
        if usb_ahbmo.htrans = "10" then
          v.mem_write.state := ahb_write;
          v.mem_write.addr  := usb_ahbmo.haddr(ADDR_BITS+1 downto 2);
          -- Check if a byte access is being made
          if usb_ahbmo.hsize = "000" then
            case usb_ahbmo.haddr(1 downto 0) is
              when "00" =>
                v.mem_write.write(3) := '1';
              when "01" =>
                v.mem_write.write(2) := '1';
              when "10" =>
                v.mem_write.write(1) := '1';
              when others => 
                v.mem_write.write(0) := '1';
            end case;
          else
            v.mem_write.write := (others => '1');
          end if;
        end if;
      when ahb_write =>
        -- 11 = more data
        -- 00 or hbusreq=0 end of transaction
        if usb_ahbmo.htrans = "11" then
          v.mem_write.addr  := usb_ahbmo.haddr(ADDR_BITS+1 downto 2);
          -- Check if a byte access is being made
          if usb_ahbmo.hsize = "000" then
            case usb_ahbmo.haddr(1 downto 0) is
              when "00" =>
                v.mem_write.write(3) := '1';
              when "01" =>
                v.mem_write.write(2) := '1';
              when "10" =>
                v.mem_write.write(1) := '1';
              when others => 
                v.mem_write.write(0) := '1';
            end case;
          else
            v.mem_write.write := (others => '1');
          end if;
        elsif (usb_ahbmo.hbusreq = '0') or (usb_ahbmo.htrans = "00") then
          v.mem_write.state     := idle;
          v.mem_write.ahb_grant := '0';
        end if;
      when others => null;
    end case;

    -- Write MUXes
    mem_write.write_enable   := (others => '0');
    mem_write.write_addr     := dcli.write_addr;
    mem_write.write_data     := dcli.write_data;
    if r.mem_write.ahb_grant = '1' then
      mem_write.write_enable := r.mem_write.write;
      mem_write.write_addr   := r.mem_write.addr;
      mem_write.write_data   := usb_ahbmo.hwdata;
    elsif r.mem_write.dcl_grant = '1' then
      mem_write.write_enable := (others => '1');
    end if;
  end;
  
-------------------------------------------------------------------------------
-- Descriptor state tracker
-- Keeps track of which DMA buffers that contains data. It uses the IRQ and
-- last write address to identify what end-points the USBDCTRL has accessed
--
-- usb_ahbso - Listens to the IRQ to know when packets been sent/received
-- mem_write - The address of the last write access is stored
-- desc      - Used by the main FSM to notify when packets been read/written
-------------------------------------------------------------------------------
  procedure descriptor_state_fsm(
    r            : in    all_reg_type;          -- Current state
    v            : inout all_reg_type;          -- Updated state
    usb_ahbso    : in    ahb_slv_out_type;
    mem_write    : in    mem_write_signal_type;
    desc         : in    desc_signals_type) is
  begin
    -- The last USB write tells us which descriptor is updated
    if mem_write.write_enable(0) = '1' and r.mem_write.ahb_grant = '1' then
      v.desc.last_write_addr(ADDR_BITS-1 downto 0) := mem_write.write_addr;
    end if;

    -- The interrupts tells us that something has happend and the
    -- address tells us the endpoint
    if usb_ahbso.hirq(2) = '1' then
      case v.desc.last_write_addr is
        -- New packets arrived, data in buffer
        when DESC_EP0_OUT   =>
          v.desc.ep0_out   := '1';
        when DESC_EP1_OUT_A =>
          v.desc.ep1_out_A := '1';
        when DESC_EP1_OUT_B =>
          v.desc.ep1_out_B := '1';
        when others         => null;
      end case;
    end if;
    if usb_ahbso.hirq(1) = '1' then
      case v.desc.last_write_addr is
          -- Packet sent, no data in buffer
        when DESC_EP0_IN   =>
          v.desc.ep0_in   := '0';
        when DESC_EP1_IN_A =>
          v.desc.ep1_in_A := '0';
        when DESC_EP1_IN_B =>
          v.desc.ep1_in_B := '0';
        when others        => null;
      end case;
    end if;

    -- Update the state when one of the buffers have been read or
    -- written
    if desc.ep0_read = '1' then
      v.desc.ep0_out        := '0';     -- Buffer is read, empty
    end if;
    if desc.ep0_written = '1' then
      v.desc.ep0_in         := '1';     -- Buffer contains data
    end if;
    if desc.ep1_read = '1' then
      if r.desc.ep1_out = '0' then
        v.desc.ep1_out_A    := '0';     -- Buffer A has been read, empty
        v.desc.ep1_out      := '1';     -- Next buffer to read from is B
        v.desc.ep1_out_desc := DESC_EP1_OUT_B(ADDR_BITS-1 downto 0);
        v.desc.ep1_out_buff := EP1_OUT_B(ADDR_BITS-1 downto 0);
      else
        v.desc.ep1_out_B    := '0';     -- Buffer B has been read, empty
        v.desc.ep1_out      := '0';     -- Next buffer to read from is A
        v.desc.ep1_out_desc := DESC_EP1_OUT_A(ADDR_BITS-1 downto 0);
        v.desc.ep1_out_buff := EP1_OUT_A(ADDR_BITS-1 downto 0);
      end if;
    end if;
    if desc.ep1_written = '1' then
      if r.desc.ep1_in = '0' then
        v.desc.ep1_in_A     := '1';     -- Buffer A has been written
        v.desc.ep1_in       := '1';     -- Next buffer to write to is B
        v.desc.ep1_in_desc  := DESC_EP1_IN_B(ADDR_BITS-1 downto 0);
        v.desc.ep1_in_buff  := EP1_IN_B(ADDR_BITS-1 downto 0);
      else
        v.desc.ep1_in_B     := '1';     -- Buffer B has been written
        v.desc.ep1_in       := '0';     -- Next buffer to write to is A
        v.desc.ep1_in_desc  := DESC_EP1_IN_A(ADDR_BITS-1 downto 0);
        v.desc.ep1_in_buff  := EP1_IN_A(ADDR_BITS-1 downto 0);
      end if;
    end if;
  end;

-------------------------------------------------------------------------------
-- Internal AHB master interface
-- Directly connected to the AHB slave interface of the USBDCTRL.
-- Very simple, no error checking, assuming that HRESP is always OKAY
-- No arbitration since point-to-point link
-------------------------------------------------------------------------------
  procedure ahb_mst_fsm(
           r             : in    all_reg_type;          -- Current state
           v             : inout all_reg_type;          -- Updated state
           usb_ahbso     : in    ahb_slv_out_type;
           usb_ahbsi     : out   ahb_slv_in_type;
    signal ahb_done      : out   std_ulogic;
    signal ahb_read_data : out   std_logic_vector(31 downto 0)) is
  begin
    usb_ahbsi.hsel      := (others => '1');  -- USBDCTRL is always selected
    usb_ahbsi.hsize     := "010";            -- Word
    usb_ahbsi.htrans    := "00";             -- Idle
    usb_ahbsi.hburst    := "000";            -- Always single access
    usb_ahbsi.hprot     := (others => '0');  -- Not using any protocol
    usb_ahbsi.hready    := '0';
    usb_ahbsi.hmaster   := (others => '0');  -- Always master 0
    usb_ahbsi.hmastlock := '0';              -- No locked accesses
    usb_ahbsi.hcache    := '0';              -- No cachable
    usb_ahbsi.hmbsel    := (others => '0');  -- Bank 0 selected
    usb_ahbsi.hirq      := (others => '0');  -- No IRQ used
    usb_ahbsi.haddr     := (others => '0');  -- To avoid latches
    usb_ahbsi.hwdata    := (others => '0');  -- To avoid latches
    usb_ahbsi.hwrite    := '0';              -- Not writing as default
    ahb_read_data       <= usb_ahbso.hrdata; -- Data read from USBDCTRL
    ahb_done            <= '0';              -- No AHB write have been done
    case r.usb_ahb is
      when idle =>
        if r.ahb.req = '1' then
          v.usb_ahb        := write;
          usb_ahbsi.hready := '1';
          usb_ahbsi.htrans := "10";          -- NONSEQ
          usb_ahbsi.hwrite := r.ahb.write;
          usb_ahbsi.haddr  := r.ahb.addr;
        end if;
      when others =>
        usb_ahbsi.hwdata := r.ahb.data;
        if usb_ahbso.hready = '1' then
          v.usb_ahb        := idle;
          usb_ahbsi.hready := '1';           -- Transfer completed
          ahb_done         <= '1';           -- AHB request done 
        end if;
    end case;
  end;

-------------------------------------------------------------------------------
-- Check for interrupts indicating that the GRUSBDCTRL got an USB reset or VBUS
-- was lost. If so set everything to a default state.
-------------------------------------------------------------------------------
  procedure reset_or_vbus_irq(
    v            : inout all_reg_type;          -- Updated state
    usb_ahbso    : in    ahb_slv_out_type) is
  begin
    if usb_ahbso.hirq(0)='1' then
      v.main.state           := reset;
      v.main.error           := '0';
      v.main.address_set     := '0';
      v.main.config_done     := '0';
      v.main.ep1_out_halted  := '0';
      v.main.ep1_in_halted   := '0';
      v.main.wait_for_ack    := '0';
      v.ahb.req              := '0';
      v.desc.ep0_out         := '0';
      v.desc.ep1_out_A       := '0';
      v.desc.ep1_out_B       := '0';
      v.desc.ep1_out         := '0';
      v.desc.ep0_in          := '0';
      v.desc.ep1_in_A        := '0';
      v.desc.ep1_in_B        := '0';
      v.desc.ep1_in          := '0';      
      v.desc.ep1_in_desc     := DESC_EP1_IN_A(ADDR_BITS-1 downto 0);
      v.desc.ep1_in_buff     := EP1_IN_A(ADDR_BITS-1 downto 0);
      v.desc.ep1_out_desc    := DESC_EP1_OUT_A(ADDR_BITS-1 downto 0);
      v.desc.ep1_out_buff    := EP1_OUT_A(ADDR_BITS-1 downto 0);
      v.desc.last_write_addr := (others => '0');
    end if;
  end;
    
begin

  -- USB Device Controller
  usbdctrl0 : usbdctrl
    generic map (
      hsindex  => 0,
      hirq     => 0,
      haddr    => 0,
      hmask    => 16#FFF#,
      hmindex  => 0,
      aiface   => 1,
      memtech  => memtech,
      uiface   => uiface,
      dwidth   => dwidth,
      nepi     => 2,
      nepo     => 2,
      i0       => 64,
      i1       => 512,
      o0       => 64,
      o1       => 512,
      oepol    => oepol,
      syncprst => syncprst,
      prsttime => prsttime,
      sysfreq  => sysfreq,
      keepclk  => keepclk,
      sepirq   => 1,
      irqi     => 1,
      irqo     => 2)
    port map (
      uclk     => uclk,
      usbi     => usbi,
      usbo     => usbo,
      hclk     => hclk,
      hrst     => hrst,
      ahbmi    => usb_ahbmi,
      ahbmo    => usb_ahbmo,
      ahbsi    => usb_ahbsi,
      ahbso    => usb_ahbso);

  -- AHB master interface
  ahbmaster0: ahbmst
    generic map (
        hindex  => hindex,
        venid   => VENDOR_GAISLER,
        devid   => GAISLER_USBDCL,
        version => 0,
        incaddr => 1)
    port map (
        rst     => hrst,
        clk     => hclk,
        dmai    => dmai,
        dmao    => dmao,
        ahbi    => ahbi,
        ahbo    => ahbo);

  -- Memory for storing packets used in DMA transfers
  ra : for i in 0 to 3 generate
    ram : syncram_2p
      generic map (memtech, ADDR_BITS, 8, 0)
      port map (hclk, mem_read.read_enable,        mem_read.read_addr,   read_data(i*8+7 downto i*8),
                hclk, mem_write.write_enable(3-i), mem_write.write_addr, mem_write.write_data(i*8+7 downto i*8));
  end generate;

  
  usbdcl_proc: process (hrst, r, usb_ahbmo, usb_ahbso, dmao, dclo, ahb_done, read_data, ahb_read_data)
    variable v           : all_reg_type;
    variable v_dcli      : dcl_memory_in_type;
    variable v_dmai      : ahb_dma_in_type;
    variable v_desc      : desc_signals_type;
    variable v_mem_read  : mem_read_signal_type;
    variable v_mem_write : mem_write_signal_type;
    variable v_usb_ahbsi : ahb_slv_in_type;
    variable v_usb_ahbmi : ahb_mst_in_type;
  begin
    v := r;
   
    main_fsm(r, v, dmao, ahb_done, ahb_read_data, v_dmai, dclo, v_dcli, v_desc);
    mem_read_arbiter(r, v, v_mem_read, usb_ahbmo, v_dcli, read_data, v_usb_ahbmi, dclo);
    mem_write_arbiter(r, v, v_mem_write, usb_ahbmo, v_dcli);
    descriptor_state_fsm(r, v, usb_ahbso, v_mem_write, v_desc);
    ahb_mst_fsm(r, v, usb_ahbso, v_usb_ahbsi, ahb_done, ahb_read_data);
    reset_or_vbus_irq(v, usb_ahbso);
      
    -- All AHB transactions granted access will complete succesfully
    -- and without any delay
    v_usb_ahbmi.hresp     := "00";      -- OKAY
    v_usb_ahbmi.hready    := '1';
    v_usb_ahbmi.hgrant(0) := r.mem_read.ahb_grant or r.mem_write.ahb_grant;

    dmai      <= v_dmai;
    mem_read  <= v_mem_read;
    mem_write <= v_mem_write;
    usb_ahbsi <= v_usb_ahbsi;
    usb_ahbmi <= v_usb_ahbmi;

    r_in      <= v;
  end process usbdcl_proc;

-------------------------------------------------------------------------------
-- Clocked registers
-------------------------------------------------------------------------------  
  clock : process (hclk)
  begin
    if rising_edge(hclk) then
      r <= r_in;
      if hrst = '0' then
        r.mem_read.state       <= idle;
        r.mem_read.ahb_grant   <= '0';
        r.mem_read.dcl_grant   <= '0';
        r.mem_write.state      <= idle;
        r.mem_write.ahb_grant  <= '0';
        r.mem_write.dcl_grant  <= '0';
        r.main.state           <= reset;
        r.main.error           <= '0';
        r.main.address_set     <= '0';
        r.main.config_done     <= '0';
        r.main.ep1_out_halted  <= '0';
        r.main.ep1_in_halted   <= '0';
        r.main.wait_for_ack    <= '0';
        r.ahb.req              <= '0';
        r.usb_ahb              <= idle;
        r.desc.ep0_out         <= '0';
        r.desc.ep1_out_A       <= '0';
        r.desc.ep1_out_B       <= '0';
        r.desc.ep1_out         <= '0';
        r.desc.ep0_in          <= '0';
        r.desc.ep1_in_A        <= '0';
        r.desc.ep1_in_B        <= '0';
        r.desc.ep1_in          <= '0';
        r.desc.ep1_in_desc     <= DESC_EP1_IN_A(ADDR_BITS-1 downto 0);
        r.desc.ep1_in_buff     <= EP1_IN_A(ADDR_BITS-1 downto 0);
        r.desc.ep1_out_desc    <= DESC_EP1_OUT_A(ADDR_BITS-1 downto 0);
        r.desc.ep1_out_buff    <= EP1_OUT_A(ADDR_BITS-1 downto 0);
        r.desc.last_write_addr <= (others => '0');
      end if;
    end if;
  end process clock;
end;
