library ieee;
use ieee.std_logic_1164.all;
library gaisler;
use gaisler.misc.all;
use gaisler.net.all;
library grlib;
use grlib.stdlib.all;

-- pragma translate_off
library unisim;
use unisim.BUFG;
use unisim.DCM;
-- pragma translate_on

library techmap;
use techmap.gencomp.all;

entity rgmii is
  
  generic (
    tech    : integer := 0;
    rxclk   : integer := 0;
    gmii    : integer := 0;
    odelen  : integer := 0
    );
  port (
    rstn        : in  std_ulogic;
    clk50       : in  std_ulogic;
    gmiii	: out eth_in_type;
    gmiio	: in  eth_out_type;
    rgmiii	: in  eth_in_type;
    rgmiio	: out eth_out_type
    );
  
end ;

architecture rtl of rgmii is

  component BUFG port (O : out std_logic; I : in std_logic); end component;

  component BUFGMUX port ( O : out std_ulogic; I0 : in std_ulogic;
                           I1 : in std_ulogic; S : in std_ulogic);
  end component;
                    
component DCM
  generic (
     CLKDV_DIVIDE : real := 2.0;
     CLKFX_DIVIDE : integer := 1;
     CLKFX_MULTIPLY : integer := 4;
     CLKIN_DIVIDE_BY_2 : boolean := false;
     CLKIN_PERIOD : real := 10.0;
     CLKOUT_PHASE_SHIFT : string := "NONE";
     CLK_FEEDBACK : string := "1X";
     DESKEW_ADJUST : string := "SYSTEM_SYNCHRONOUS";
     DFS_FREQUENCY_MODE : string := "LOW";
     DLL_FREQUENCY_MODE : string := "LOW";
     DSS_MODE : string := "NONE";
     DUTY_CYCLE_CORRECTION : boolean := true;
     FACTORY_JF : bit_vector := X"C080";
     PHASE_SHIFT : integer := 0;
     SIM_MODE : string := "SAFE";
     STARTUP_WAIT : boolean := false
  );
  port (
     CLK0 : out std_ulogic := '0';
     CLK180 : out std_ulogic := '0';
     CLK270 : out std_ulogic := '0';
     CLK2X : out std_ulogic := '0';
     CLK2X180 : out std_ulogic := '0';
     CLK90 : out std_ulogic := '0';
     CLKDV : out std_ulogic := '0';
     CLKFX : out std_ulogic := '0';
     CLKFX180 : out std_ulogic := '0';
     LOCKED : out std_ulogic := '0';
     PSDONE : out std_ulogic := '0';
     STATUS : out std_logic_vector(7 downto 0) := "00000000";
     CLKFB : in std_ulogic := '0';
     CLKIN : in std_ulogic := '0';
     DSSEN : in std_ulogic := '0';
     PSCLK : in std_ulogic := '0';
     PSEN : in std_ulogic := '0';
     PSINCDEC : in std_ulogic := '0';
     RST : in std_ulogic := '0'
  );
end component;

component ODDR2
  generic (
     DDR_ALIGNMENT : string := "NONE";
     INIT : bit := '0';
     SRTYPE : string := "SYNC"
  );
  port (
     Q : out std_ulogic;
     C0 : in std_ulogic;
     C1 : in std_ulogic;
     CE : in std_ulogic := 'H';
     D0 : in std_ulogic;
     D1 : in std_ulogic;
     R : in std_ulogic := 'L';
     S : in std_ulogic := 'L'
  );
end component;

component FDDRRSE
  generic (
     INIT : bit := '0'
  );
  port (
     Q : out std_ulogic;
     C0 : in std_ulogic;
     C1 : in std_ulogic;
     CE : in std_ulogic;
     D0 : in std_ulogic;
     D1 : in std_ulogic;
     R : in std_ulogic;
     S : in std_ulogic
  );
end component;

component IDDR2
  generic (
     DDR_ALIGNMENT : string := "NONE";
     INIT_Q0 : bit := '0';
     INIT_Q1 : bit := '0';
     SRTYPE : string := "SYNC"
  );
  port (
     Q0 : out std_ulogic;
     Q1 : out std_ulogic;
     C0 : in std_ulogic;
     C1 : in std_ulogic;
     CE : in std_ulogic := 'H';
     D : in std_ulogic;
     R : in std_ulogic := 'L';
     S : in std_ulogic := 'L'
  );
end component;

component IODELAY2
  generic (
     COUNTER_WRAPAROUND : string := "WRAPAROUND";
     DATA_RATE : string := "SDR";
     DELAY_SRC : string := "IO";
     IDELAY2_VALUE : integer := 0;
     IDELAY_MODE : string := "NORMAL";
     IDELAY_TYPE : string := "DEFAULT";
     IDELAY_VALUE : integer := 0;
     ODELAY_VALUE : integer := 0;
     SERDES_MODE : string := "NONE";
     SIM_TAPDELAY_VALUE : integer := 75
  );
  port (
     BUSY : out std_ulogic;
     DATAOUT : out std_ulogic;
     DATAOUT2 : out std_ulogic;
     DOUT : out std_ulogic;
     TOUT : out std_ulogic;
     CAL : in std_ulogic;
     CE : in std_ulogic;
     CLK : in std_ulogic;
     IDATAIN : in std_ulogic;
     INC : in std_ulogic;
     IOCLK0 : in std_ulogic;
     IOCLK1 : in std_ulogic;
     ODATAIN : in std_ulogic;
     RST : in std_ulogic;
     T : in std_ulogic
  );
end component;

  constant VERSION : integer := 1;
  constant CLKIN_PERIOD_ST : string := "8.0";

  signal vcc, gnd : std_ulogic;
  signal tx_en, tx_ctlp, tx_ctl : std_ulogic;
  signal txd, txd1 : std_logic_vector(7 downto 0);
  signal rxd1, rxd2, rxd3, rxd4 : std_logic_vector(7 downto 0);
  signal rx_clk, nrx_clk : std_ulogic;
  signal rx_ctlp, rx_ctln : std_logic_vector(1 to 4);
  signal clk125, nclk125, uclk125, clk125i, clk125ii : std_ulogic;
  signal clk125_90, nclk125_90, uclk125_90, clk125_90i : std_ulogic;
  signal clk25, clk25i : std_ulogic;
  signal txp, txn, tx_clk : std_ulogic;
  
begin  -- rtl

  vcc <= '1'; gnd <= '0';
  txp <= '1' when gmii = 1 else '0';
  txn <= '0' when gmii = 1 else '1';

  g1 : if gmii = 1 generate
    r0 : if rxclk = 0 generate
      clk125 <= clk125i;
      nclk125 <= not clk125i;
      clk125_90 <= clk125_90i;
      nclk125_90 <= not clk125_90i;
      gmiii.gtx_clk <= clk125i;
      gmiii.tx_clk <= clk125i;
    end generate;
    r1 : if rxclk = 1 generate
      clk125 <= rgmiii.rx_clk;
      nclk125 <= not rgmiii.rx_clk;
      clk125_90 <= rgmiii.rx_clk;
      nclk125_90 <= not rgmiii.rx_clk;
      gmiii.gtx_clk <= rgmiii.rx_clk;
      gmiii.tx_clk <= rgmiii.rx_clk;
    end generate;
    r2 : if rxclk = 2 generate
      clk125 <= clk125i;
      nclk125 <= not clk125i;
      clk125_90 <= clk125i;
      nclk125_90 <= not clk125i;
      gmiii.gtx_clk <= clk125i;
      gmiii.tx_clk <= clk125i;
    end generate;
  end generate;

  g0 : if gmii = 0 generate
      clk125 <= clk25;
      nclk125 <= not clk25;
      clk125_90 <= clk25;
      nclk125_90 <= not clk25;
      gmiii.gtx_clk <= clk25;
      gmiii.tx_clk <= clk25;
  end generate;

  gmiii.mdint <= rgmiii.mdint;
  gmiii.mdio_i <= rgmiii.mdio_i;
  rgmiio.mdio_o <= gmiio.mdio_o;
  rgmiio.mdio_oe <= gmiio.mdio_oe;
  rgmiio.mdc <= gmiio.mdc;

-- TX path

  rgmii_txd : for i in 0 to 3 generate
      ddr_oreg0 : FDDRRSE
        port map (q => rgmiio.txd(i), c0 => clk125, c1 => nclk125, ce => vcc,
                  d0 => txd(i), d1 => txd1(i+4), r => gnd, s => gnd);
  end generate;

  
  rgmii_tx_ctl : FDDRRSE
        port map (q => rgmiio.tx_en, c0 => clk125, c1 => nclk125, ce => vcc,
                  d0 => tx_en, d1 => tx_ctl, r => gnd, s => gnd);
  rgmii_tx_clk : FDDRRSE 
        port map (q =>tx_clk, c0 => clk125_90, c1 => nclk125_90, ce => vcc,
                  d0 => txp, d1 => txn, r => gnd, s => gnd);
  
  d1 : if odelen = 1 generate
    txclk_del : IODELAY2
    generic map (
      DATA_RATE                => "SDR",
      ODELAY_VALUE             => 75,
      COUNTER_WRAPAROUND       => "STAY_AT_LIMIT",
      DELAY_SRC                => "ODATAIN",
      SERDES_MODE              => "NONE",
      SIM_TAPDELAY_VALUE       => 75)
    port map (
      -- required datapath
      T                      => '0',
      DOUT                   => rgmiio.tx_er,
      ODATAIN                => tx_clk,
      -- inactive data connections
      IDATAIN                => '0',
      TOUT                   => open,
      DATAOUT                => open,
      DATAOUT2               => open,
       -- connect up the clocks
      IOCLK0                => '0',                 -- No calibration needed
      IOCLK1                => '0',                 -- No calibration needed
      -- Tie of the variable delay programming
      CLK                   => '0',
      CAL                   => '0',
      INC                   => '0',
      CE                    => '0',
      BUSY                  => open,
      RST                   => '0');
  end generate;
  d0 : if odelen = 0 generate
      rgmiio.tx_er <= tx_clk;
  end generate;

  process (clk125)
  begin  -- process
    if rising_edge(clk125) then
      txd(7 downto 0) <= gmiio.txd(7 downto 0);
      tx_en <= gmiio.tx_en;
      tx_ctlp <= gmiio.tx_en xor gmiio.tx_er;
    end if;
  end process;
  
  process (nclk125)
  begin  -- process
    if rising_edge(nclk125) then
      if gmii = 1 then
        txd1(7 downto 4) <= txd(7 downto 4);
      else
        txd1(7 downto 4) <= txd(3 downto 0);
      end if;
      tx_ctl <= tx_ctlp;
    end if;
  end process;
  
  process (clk50)
  begin  -- process
    if rising_edge(clk50) then
      clk25i <= not clk25i;
      if rstn = '0' then clk25i <= '0'; end if;
    end if;
  end process;
  bufg02 : BUFG port map (I => clk25i, O => clk25);
  

-- RX path

  rx_clk <= rgmiii.rx_clk;
  nrx_clk <= not rgmiii.rx_clk;

  gmiii.rxd <= rxd4;
  gmiii.rx_dv <= rx_ctlp(4);
  gmiii.rx_er <= rx_ctln(4);
  gmiii.rx_clk <= rgmiii.rx_clk;
  gmiii.rx_col <= '0';
  gmiii.rx_crs <= rx_ctlp(4);

  rgmii_rxd : for i in 0 to 3 generate
      ddr_ireg0 : ddr_ireg generic map (tech)
        port map (q1 => rxd1(i), q2 => rxd1(i+4), c1 => rx_clk, c2 => nrx_clk,
	 ce => vcc, d => rgmiii.rxd(i), r => gnd, s => gnd);
  end generate;
  ddr_ireg0 : ddr_ireg generic map (tech)
     port map (q1 => rx_ctlp(1), q2 => rx_ctln(1), c1 => rx_clk, c2 => nrx_clk,
	 ce => vcc, d => rgmiii.rx_dv, r => gnd, s => gnd);


  process (rx_clk)
  begin  -- process
    if rising_edge(rx_clk) then
      rx_ctlp(2) <= rx_ctlp(1);
      rx_ctlp(3) <= rx_ctlp(2);
      rx_ctlp(4) <= rx_ctlp(3);
      rx_ctln(3) <= rx_ctln(2);
      rx_ctln(4) <= rx_ctln(3) xor rx_ctlp(3);
      rxd2(3 downto 0) <= rxd1(3 downto 0);
      rxd3 <= rxd2;
      rxd4 <= rxd3;
    end if;
  end process;
  
  process (nrx_clk)
  begin  -- process
    if rising_edge(nrx_clk) then
      rx_ctln(2) <= rx_ctln(1);
      rxd2(7 downto 4) <= rxd1(7 downto 4);
    end if;
  end process;
  
  r2 : if rxclk = 2 generate
    clk125i <= rgmiii.gtx_clk;
  end generate;
  rz : if rxclk = 0 generate
--    clk125i <= rgmiii.gtx_clk;
--    bufg00 : BUFG port map (I => uclk125, O => clk125_90i);
    bufg00 : BUFG port map (I => uclk125, O => clk125i);
    bufg01 : BUFG port map (I => uclk125_90, O => clk125_90i);
    txdll : DCM 
      generic map (CLKFX_MULTIPLY => 2, CLKFX_DIVIDE => 2,
        DFS_FREQUENCY_MODE => "LOW", DLL_FREQUENCY_MODE => "LOW", 
--	CLKOUT_PHASE_SHIFT => "FIXED", PHASE_SHIFT => 64,
	CLKIN_PERIOD => 8.0)
--      port map ( CLKIN => rgmiii.gtx_clk, CLKFB => clk125_90i,
      port map ( CLKIN => rgmiii.gtx_clk, CLKFB => clk125i,
               CLK0 => uclk125, clk90 => uclk125_90);
--               CLK0 => uclk125);
  end generate;
  
end rtl;
