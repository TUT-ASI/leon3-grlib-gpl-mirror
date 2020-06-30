library ieee;
use ieee.std_logic_1164.all;
library unisim;
use unisim.vcomponents.all;

entity clockers_mig is
  port (
    -- async reset
    rstn        : in    std_logic;
    clkin       : in    std_logic;
    mig_clkref  : out   std_logic;
    mig_clk     : out   std_logic;
    eth_ref     : out   std_logic;
    clkm        : out   std_logic;
    locked      : out   std_logic
  );
end;

architecture impl of clockers_mig is
  signal clkfbout_clockers    : std_logic;
  signal eth_ref_clockers     : std_logic;
  signal clkm_clockers        : std_logic;
  signal mig_clk_clockers     : std_logic;
  signal mig_clkref_clockers  : std_logic;
  signal reset                : std_ulogic;
begin
  reset <= not rstn;
clkout1_buf: unisim.vcomponents.BUFG
     port map (
      I => mig_clkref_clockers,
      O => mig_clkref
    );
clkout2_buf: unisim.vcomponents.BUFG
     port map (
      I => mig_clk_clockers,
      O => mig_clk
    );
clkout3_buf: unisim.vcomponents.BUFG
     port map (
      I => eth_ref_clockers,
      O => eth_ref
    );
clkout4_buf: unisim.vcomponents.BUFG
     port map (
      I => clkm_clockers,
      O => clkm
    );
plle2_adv_inst: unisim.vcomponents.PLLE2_ADV
    generic map(
      BANDWIDTH => "OPTIMIZED",
      CLKFBOUT_MULT => 10,
      CLKFBOUT_PHASE => 0.000000,
      CLKIN1_PERIOD => 10.000000,
      CLKIN2_PERIOD => 0.000000,
      CLKOUT0_DIVIDE => 5,
      CLKOUT0_DUTY_CYCLE => 0.500000,
      CLKOUT0_PHASE => 0.000000,
      CLKOUT1_DIVIDE => 6,
      CLKOUT1_DUTY_CYCLE => 0.500000,
      CLKOUT1_PHASE => 0.000000,
      CLKOUT2_DIVIDE => 40,
      CLKOUT2_DUTY_CYCLE => 0.500000,
      CLKOUT2_PHASE => 0.000000,
      CLKOUT3_DIVIDE => 25, --30 = 33 MHz 25 = 40 MHz 20 = 50 MHz
      CLKOUT3_DUTY_CYCLE => 0.500000,
      CLKOUT3_PHASE => 0.000000,
      CLKOUT4_DIVIDE => 1,
      CLKOUT4_DUTY_CYCLE => 0.500000,
      CLKOUT4_PHASE => 0.000000,
      CLKOUT5_DIVIDE => 1,
      CLKOUT5_DUTY_CYCLE => 0.500000,
      CLKOUT5_PHASE => 0.000000,
      COMPENSATION => "INTERNAL",
      DIVCLK_DIVIDE => 1,
      REF_JITTER1 => 0.010000,
      REF_JITTER2 => 0.010000,
      STARTUP_WAIT => "FALSE"
    )
    port map (
      CLKFBIN => clkfbout_clockers,
      CLKFBOUT => clkfbout_clockers,
      CLKIN1 => clkin,
      CLKIN2 => '0',
      CLKINSEL => '1',
      CLKOUT0 => mig_clkref_clockers,
      CLKOUT1 => mig_clk_clockers,
      CLKOUT2 => eth_ref_clockers,
      CLKOUT3 => clkm_clockers,
      CLKOUT4 => open,
      CLKOUT5 => open,
      DADDR => (others => '0'),
      DCLK => '0',
      DEN => '0',
      DI => (others => '0'),
      DO => open,
      DRDY => open,
      DWE => '0',
      LOCKED => locked,
      PWRDWN => '0',
      RST => reset
    );
end;

