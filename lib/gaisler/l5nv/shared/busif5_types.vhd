
library ieee;
use ieee.std_logic_1164.all;

package busif5_types is

  -- Encoded so that all operations that actually cause bus access
  -- have bit 3 set to 1.
  constant BIFOP_NOP   : std_logic_vector(3 downto 0) := "0000";  -- No op / Release lock.
  constant BIFOP_DTAGW : std_logic_vector(3 downto 0) := "0001";  -- Dtag diag write in dtagconf=0 mode
  constant BIFOP_STAGR : std_logic_vector(3 downto 0) := "0011";  -- Stag diag read
  constant BIFOP_STAGW : std_logic_vector(3 downto 0) := "0010";  -- Stag diag write
  constant BIFOP_LOCK  : std_logic_vector(3 downto 0) := "0100";  -- No op / Acquire lock
  constant BIFOP_FLUSH : std_logic_vector(3 downto 0) := "0101";  -- Flush STAG and DTAG
  constant BIFOP_DPASS : std_logic_vector(3 downto 0) := "0110";  -- Data pass-through stdata->rdbuf
  constant BIFOP_STAGRX: std_logic_vector(3 downto 0) := "0111";  -- 64-bit stag diag read
  constant BIFOP_STORE : std_logic_vector(3 downto 0) := "1000";  -- Store
  constant BIFOP_SMFET : std_logic_vector(3 downto 0) := "1001";  -- Small fetch
  constant BIFOP_DLFET : std_logic_vector(3 downto 0) := "1010";  -- DLine fetch
  constant BIFOP_ILFET : std_logic_vector(3 downto 0) := "1011";  -- ILine fetch
  constant BIFOP_RESV1 : std_logic_vector(3 downto 0) := "1100";
  constant BIFOP_FFLUSH: std_logic_vector(3 downto 0) := "1101";  -- Full flush of STAG and DTAG
  constant BIFOP_AREGW : std_logic_vector(3 downto 0) := "1110";  -- AHB status register write
  constant BIFOP_AREGR : std_logic_vector(3 downto 0) := "1111";  -- AHB status register read

  type busif_in_type5 is record
    -- opcode
    bifop        : std_logic_vector(3 downto 0);
    -- clear read buffer valid
    clrrdbuf     : std_ulogic;
    -- address and metadata for address
    busaddr      : std_logic_vector(46 downto 0);
    busid        : std_logic_vector(2 downto 0);
    widebus      : std_ulogic;
    -- for store and single load
    size         : std_logic_vector(1 downto 0);
    -- store data and metadata for store
    stdata       : std_logic_vector(63 downto 0);
    nosnoop      : std_ulogic;
    su           : std_ulogic;
    mmuacc       : std_ulogic;          -- 0=regular, 1=PTE
    wcomb        : std_ulogic;          -- potential write combining
    -- Signaling for write error handling. This marks all currently
    -- queued writes (not including one queued up on the same cycle as
    -- this signaling is asserted) as "masked" so they will signal any
    -- store error as a "masked" error (using sterr bits 3:2) instead
    -- of a "regular" error using sterr bits 1:0. The purpose is to track
    -- which stores should cause a trap.
    maskwerr     : std_logic_vector(1 downto 0);
    -- replaced way for data line fetch operation
    -- this signal must be valid 2 cycles after the DLFET bifop has been given
    -- in order to determine which snoop tag set to write the new tag into
    dlfway       : std_logic_vector(0 to 3);
    -- configuration
    snoopen      : std_ulogic;
    -- NW FIXME: atomic operations
    lr_set       : std_ulogic;
    lr_clr       : std_ulogic;
    --lr_addr      : std_logic_vector(47 downto 0);
  end record;

  constant busif_in_type5_none : busif_in_type5 := (
    "0000", '0', (others => '0'), "000", '0', "00", (others => '0'), '0','0','0','0',"00","0000",'0'
    ,'0','0' --, (others => '0')
      );

  type busif_in_vector is array(natural range <>) of busif_in_type5;

  type busif_status_type5 is record
    --
    ready  : std_ulogic;
    -- no AHB access in progress
    idle   : std_ulogic;
    --
    -- High for one cycle to indicate that a store failed.
    --   Bit 0 for regular stores
    --   Bit 1 for MMU stores (with mmuacc=0)
    --   Bit 3:2 for stores that have been "masked" with the maskwerr signal
    sterr  : std_logic_vector(3 downto 0);
    -- Signal that bus is locked and no access in progress
    locked : std_ulogic;
    -- NW FIXME: atomic operations 
    lr_valid : std_ulogic;
  end record;
  constant busif_status_type5_none : busif_status_type5 := (
    '0','0',"0000",'0', '0'
    );

  type busif_status_vector is array(natural range <>) of busif_status_type5;

  type busif_rdbufr_type5 is record
    buf  : std_logic_vector(511 downto 0);
    bufv : std_logic_vector(15 downto 0);
    bufe : std_logic_vector(15 downto 0);
    started : std_ulogic;
    done : std_ulogic;
    err  : std_ulogic;
  end record;
  constant busif_rdbufr_type5_none : busif_rdbufr_type5 := (
    (others => '0'), (others => '0'), (others => '0'), '0', '0', '0'
    );

  constant UTAGMAX : integer := 32;
  constant UIDXMAX : integer := 16;

  type busif_dtagupd_type5 is record
    upd  : std_logic_vector(0 to 3);
    uval : std_logic_vector(UTAGMAX-3 downto 0);
    umsb : std_logic_vector(7 downto 0);
    uidx : std_logic_vector(UIDXMAX-1 downto 0);
    utype: std_logic_vector(1 downto 0);  -- 00=snoop, 01=flush, 10=dline fetch, 11=dtag write
  end record;
  constant busif_dtagupd_type5_none : busif_dtagupd_type5 := (
    "0000", (others => '0'), "00000000", (others => '0'), "00"
    );

  type busif_snoopport_type is record
    snhit: std_logic_vector(0 to 3);
    snidx: std_logic_vector(UIDXMAX-1 downto 0);
  end record;
  type busif_snoopport_array is array(natural range <>) of busif_snoopport_type;

  type busif_out_type5 is record
    -- Status and flow control
    stat     : busif_status_type5;
    -- Read data buffer
    rdb      : busif_rdbufr_type5;
    -- DTag update signals
    dtu      : busif_dtagupd_type5;
    snports  : busif_snoopport_array(0 to 3);
  end record;

  constant busif_out_type5_none : busif_out_type5 := (
    busif_status_type5_none,
    busif_rdbufr_type5_none,
    busif_dtagupd_type5_none
    , (others => ("0000", (others => '0')))
    );

  type busif_out_vector is array(natural range <>) of busif_out_type5;

  -- Read buffer write port (before register)
  type busif_rdbufu_type5 is record
    bufw: std_logic_vector(15 downto 0);
    bufwd: std_logic_vector(127 downto 0);
    sete: std_logic_vector(15 downto 0);
    setdone: std_ulogic;
    setstarted: std_ulogic;
    errclr: std_logic_vector(1 downto 0);
  end record;
  constant busif_rdbufu_type5_none : busif_rdbufu_type5 := (
    (others => '0'), (others => '0'), (others => '0'), '0', '0', "00"
    );
  type busif_rdbufu_array_type is array(natural range <>) of busif_rdbufu_type5;


end package;
