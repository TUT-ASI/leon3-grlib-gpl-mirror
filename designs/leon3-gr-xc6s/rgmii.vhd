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
use techmap.allclkgen.all;

entity rgmii is
  
  generic (
    tech    : integer := 0;
    gmii    : integer := 0;
    extclk  : integer := 0
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

  attribute keep : boolean;
  attribute syn_keep : boolean;
  attribute syn_preserve : boolean;


  signal vcc, gnd : std_ulogic;
  signal tx_en, tx_ctlp, tx_ctl : std_ulogic;
  signal txd, txd1 : std_logic_vector(7 downto 0);
  signal rxd1, rxd2, rxd3, rxd4 : std_logic_vector(7 downto 0);
  signal rx_clk, nrx_clk : std_ulogic;
  signal rx_ctlp, rx_ctln : std_logic_vector(1 to 4);
  signal clk25, clk25i, clk125i, clk2_5i : std_ulogic;
  signal txp, txn, tx_clk_ddr, tx_clk, tx_clki, ntx_clk : std_ulogic;
  signal cnt2_5 : std_logic_vector(3 downto 0);
  attribute syn_preserve of tx_clk : signal is true;
  attribute syn_keep of tx_clk : signal is true;
  attribute keep of tx_clk : signal is true;
  
begin  -- rtl

  vcc <= '1'; gnd <= '0';
  txp <= '1'; txn <= '0';

  g1 : if (extclk = 0) and (gmii = 1) generate
    x0 : clkmul_virtex2 generic map (5, 2) port map (rstn, clk50, clk125i);
  end generate;
  g2 : if not ((extclk = 0) and (gmii = 1)) generate
    clk125i <=  rgmiii.gtx_clk;
  end generate;

  tx_clki <= clk125i when (gmii = 1) and (gmiio.gbit = '1') else 
    clk25i when gmiio.speed = '1' else clk2_5i;
  
  bufg02 : BUFG port map (I => tx_clki, O => tx_clk);

  ntx_clk <= not tx_clk;
  gmiii.gtx_clk <= tx_clk;
  gmiii.tx_clk <= tx_clk;
  gmiii.mdint <= rgmiii.mdint;
  gmiii.mdio_i <= rgmiii.mdio_i;
  rgmiio.mdio_o <= gmiio.mdio_o;
  rgmiio.mdio_oe <= gmiio.mdio_oe;
  rgmiio.mdc <= gmiio.mdc;

-- TX path

  rgmii_txd : for i in 0 to 3 generate
      ddr_oreg0 : FDDRRSE
        port map (q => rgmiio.txd(i), c0 => tx_clk, c1 => ntx_clk, ce => vcc,
                  d0 => txd(i), d1 => txd1(i+4), r => gnd, s => gnd);
  end generate;
  rgmii_tx_ctl : FDDRRSE
        port map (q => rgmiio.tx_en, c0 => tx_clk, c1 => ntx_clk, ce => vcc,
                  d0 => tx_en, d1 => tx_ctl, r => gnd, s => gnd);
  rgmii_tx_clk : FDDRRSE 
        port map (q =>tx_clk_ddr, c0 => tx_clk, c1 => ntx_clk, ce => vcc,
                  d0 => txp, d1 => txn, r => gnd, s => gnd);
  
  rgmiio.tx_er <= tx_clk_ddr;
  rgmiio.reset <= '0';
  rgmiio.gbit <= '0';
  rgmiio.speed <= '0';
  rgmiio.txd(7 downto 4) <= (others => '0');

  process (tx_clk)
  begin  -- process
    if rising_edge(tx_clk) then
      txd(7 downto 0) <= gmiio.txd(7 downto 0);
      tx_en <= gmiio.tx_en;
      tx_ctlp <= gmiio.tx_en xor gmiio.tx_er;
    end if;
  end process;
  
  process (ntx_clk)
  begin  -- process
    if rising_edge(ntx_clk) then
      txd1(7 downto 4) <= txd(7 downto 4);
      tx_ctl <= tx_ctlp;
    end if;
  end process;
  
  process (clk50)
  begin  -- process
    if rising_edge(clk50) then
      clk25i <= not clk25i;
      if cnt2_5 = "1001" then cnt2_5 <= "0000"; clk2_5i <= not clk2_5i;
      else cnt2_5 <= cnt2_5 + 1; end if;
      if rstn = '0' then clk25i <= '0'; clk2_5i <= '0'; cnt2_5 <= "0000"; end if;
    end if;
  end process;

-- RX path

  rx_clk <= rgmiii.rx_clk;
  nrx_clk <= not rgmiii.rx_clk;

  gmiii.rxd <= rxd4;
  gmiii.rx_dv <= rx_ctlp(4);
  gmiii.rx_er <= rx_ctln(4);
  gmiii.rx_clk <= rgmiii.rx_clk;
  gmiii.rx_col <= '0';
  gmiii.rx_crs <= rx_ctlp(4);
  gmiii.rmii_clk <= '0';
  gmiii.edclsepahb <= '0';
  gmiii.edcldisable <= '0';
  gmiii.phyrstaddr <= (others => '0');
  gmiii.edcladdr <= (others => '0');

  rgmii_rxd : for i in 0 to 3 generate
      ddr_ireg0 : ddr_ireg generic map (tech)
        port map (q1 => rxd1(i), q2 => rxd1(i+4), c1 => rx_clk, c2 => nrx_clk,
	 ce => vcc, d => rgmiii.rxd(i), r => gnd, s => gnd);
  end generate;
  ddr_ireg0 : ddr_ireg generic map (tech)
     port map (q1 => rx_ctlp(1), q2 => rx_ctln(1), c1 => rx_clk, c2 => nrx_clk,
	 ce => vcc, d => rgmiii.rx_dv, r => gnd, s => gnd);

  process (rx_clk)
  begin
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
  begin
    if rising_edge(nrx_clk) then
      rx_ctln(2) <= rx_ctln(1);
      rxd2(7 downto 4) <= rxd1(7 downto 4);
    end if;
  end process;
  
end rtl;
