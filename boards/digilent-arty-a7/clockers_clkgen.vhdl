library ieee;
use ieee.std_logic_1164.all;

library techmap;
use techmap.gencomp.all;
use techmap.allclkgen.all;

entity clockers_clkgen is
  generic (
    clktech     : integer;
    -- clkin frequency in KHz
    freq        : integer;
    mul         : integer;
    div         : integer
  );
  port (
    -- async reset
    rstn        : in    std_logic;
    clkin       : in    std_logic;
    clkm        : out   std_logic;
    eth_ref     : out   std_logic;
    locked      : out   std_logic
  );
end;

architecture impl of clockers_clkgen is
  signal cgi0 : clkgen_in_type;
  signal cgo0 : clkgen_out_type;
  signal cgi1 : clkgen_in_type;
  signal cgo1 : clkgen_out_type;
begin
  locked <= cgo0.clklock and cgo1.clklock;

  cgi0.pllctrl <= "00";
  cgi0.pllrst <= rstn;
  cgi0.pllref <= '0';

  clkgen0 : clkgen
  generic map (
    tech    => clktech,
    clk_mul => mul,
    clk_div => div,
    freq    => freq
  )
  port map (clkin, '0', clkm, open, open, open, open, cgi0, cgo0, open, open, open);

  -- Generate the eth_ref_clk
  cgi1.pllctrl <= "00";
  cgi1.pllrst <= rstn;
  cgi1.pllref <= '0';


  clkgen2 : clkgen
  generic map (
    tech    => clktech,
    clk_mul => 1*8,
    clk_div => 4*8,
    freq    => freq
  )
  port map (clkin, '0', eth_ref, open, open, open, open, cgi1, cgo1, open, open, open);

end;

