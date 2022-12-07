library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
--use grlib.stdlib.all;
use grlib.stdlib.tost;
use grlib.stdlib.tost_bits;
use grlib.stdlib.print;
use grlib.stdlib.log2;
use grlib.riscv.all;
--pragma translate_off
use grlib.riscv_disas.all;
--pragma translate_on


library gaisler;
use gaisler.noelv.all;
use gaisler.utilnv.all;
use gaisler.nvsupport.all;
use gaisler.noelvint.fpu5_out_type;
use gaisler.noelvint.fpu5_out_none;
use gaisler.noelvint.fpu_id;
use gaisler.noelvint.trace_info;
use gaisler.noelvint.trace_info_none;

package rvvi is
end;



