------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2024, Frontgrade Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; version 2.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 
-----------------------------------------------------------------------------
-- Entity:      uart
-- File:        uart.vhd
-- Authors:     Jiri Gaisler, Marko Isomaki and Francisco Bas
-- Description: Asynchronous UART implementing 16550 UART interface. 
--              This UART is based on the older APBUART which is modified 
--              to achieve a UART compliant with the 16550 UART interface
--              for RISC-V platforms.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library grlib;
use grlib.config_types.all;
use grlib.config.all;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library gaisler;
use gaisler.uart.all;
--pragma translate_off
use std.textio.all;
--pragma translate_on

entity apbuart_16550 is
  generic (
    pindex   : integer := 0;
    paddr    : integer := 0;
    pmask    : integer := 16#fff#;
    console  : integer := 0;
    pirq     : integer := 0;
    flow     : integer := 1;
    fifomode : integer := 1;
    abits    : integer := 6;
    sbits    : integer range 12 to 16 := 16);
  port (
    rst    : in  std_ulogic;
    clk    : in  std_ulogic;
    apbi   : in  apb_slv_in_type;
    apbo   : out apb_slv_out_type;
    uarti  : in  uart_in_type;
    uarto  : out uart_out_type);
end;

architecture rtl of apbuart_16550 is

constant REVISION : integer := 1;
constant fifosize : integer := 1+15*fifomode;

constant pconfig : apb_config_type := (
  0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_APBUART_16550, 0, REVISION, pirq),
  1 => apb_iobar(paddr, pmask));

type rxfsmtype is (idle, startbit, data, cparity, stopbit);
type txfsmtype is (idle, data, cparity, stopbit);

type fifo is array (0 to fifosize - 1) of std_logic_vector(7 downto 0);
type fifoerr is array (0 to fifosize - 1) of std_logic_vector(2 downto 0);

type uartregs is record
  rxen          :  std_ulogic;  -- receiver enabled     
  txen          :  std_ulogic;  -- transmitter enabled  
  rirqen        :  std_ulogic;  -- receiver irq enable
  tirqen        :  std_ulogic;  -- transmitter irq enable
  parsel        :  std_ulogic;  -- parity select
  paren         :  std_ulogic;  -- parity enable
  loopb         :  std_ulogic;  -- loop back mode enable
  debug         :  std_ulogic;  -- debug mode enable
  rsempty       :  std_ulogic;  -- receiver shift register empty (internal)
  tsempty       :  std_ulogic;  -- transmitter shift register empty
  stop          :  std_ulogic;  -- 0: one stop bit, 1: two stop bits 
  break         :  std_ulogic;  -- break detected
  ovf           :  std_ulogic;  -- receiver overflow
  parerr        :  std_ulogic;  -- parity error
  frame         :  std_ulogic;  -- framing error
  ctsn          :  std_logic_vector(1 downto 0); -- clear to send
  dcts          :  std_ulogic;  -- Delta clear to send
  rts           :  std_ulogic;  -- request to send
  extclken      :  std_ulogic;  -- use external baud rate clock
  extclk        :  std_ulogic;  -- rising edge detect register
  rhold         :  fifo;
  rshift        :  std_logic_vector(7 downto 0);
  rshifterr     :  std_logic_vector(2 downto 0);
  rfifoerr      :  fifoerr;    -- indicates if the data triggered an error
  pendfifoerr   :  std_ulogic; -- set to 1 if the receiver FIFO contains an error
  tshift        :  std_logic_vector(9 downto 0);
  thold         :  fifo;
  irq           :  std_ulogic;  -- tx/rx interrupt (internal)
  irqpend       :  std_ulogic;  -- pending irq for delayed rx irq
  tpar          :  std_ulogic;  -- tx data parity (internal)
  txstate       :  txfsmtype;
  txclk         :  std_logic_vector(3 downto 0);  -- tx clock divider
  txtick        :  std_ulogic;  -- tx clock (internal)
  rxstate       :  rxfsmtype;
  rxclk         :  std_logic_vector(3 downto 0); -- rx clock divider
  rxdb          :  std_logic_vector(1 downto 0);  -- rx delay
  dpar          :  std_ulogic;  -- rx data parity (internal)
  rxtick        :  std_ulogic;  -- rx clock (internal)
  tick          :  std_ulogic;  -- rx clock (internal)
  scaler        :  std_logic_vector(sbits-1 downto 0);
  brate         :  std_logic_vector(sbits-1 downto 0);
  rxf           :  std_logic_vector(4 downto 0); --  rx data filtering buffer
  txd           :  std_ulogic;  -- transmitter data
  --
  enfifo        :  std_ulogic;  -- enables FIFO mode 
  triglvl       :  std_logic_vector(1 downto 0); -- FIFO trigger level to rise an interrupt
  thempty       :  std_ulogic;  -- transmmiter holding register/FIFO empty
  timeoutcnt    :  std_logic_vector(5 downto 0); -- to rise timeout interrupt
  dlab          :  std_ulogic;  
  genbreak      :  std_ulogic;  -- generate break 
  rlsirqen      :  std_ulogic;  -- receiver line status interrupt enable
  modirqen      :  std_ulogic;  -- modem interrupt enable
  irqcause      :  std_logic_vector(1 downto 0);   
  thirqpend     :  std_ulogic;
  irqtimeout    :  std_ulogic;
  scratch       :  std_logic_vector(7 downto 0); -- Scratch register
 --fifo counters
  rwaddr        :  std_logic_vector(log2x(fifosize) - 1 downto 0);
  rraddr        :  std_logic_vector(log2x(fifosize) - 1 downto 0);
  traddr        :  std_logic_vector(log2x(fifosize) - 1 downto 0);
  twaddr        :  std_logic_vector(log2x(fifosize) - 1 downto 0);
  rcnt          :  std_logic_vector(log2x(fifosize) downto 0);
  tcnt          :  std_logic_vector(log2x(fifosize) downto 0);
end record;

constant rcntzero : std_logic_vector(log2x(fifosize) downto 0) := (others => '0');
constant addrzero : std_logic_vector(log2x(fifosize)-1 downto 0) := (others => '0');
constant sbitszero : std_logic_vector(sbits-1 downto 0) := (others => '0');
constant fifozero : fifo := (others => (others => '0'));
constant fifoerrzero : fifoerr := (others => (others => '0'));

constant RESET_ALL : boolean := GRLIB_CONFIG_ARRAY(grlib_sync_reset_enable_all) = 1;

constant RES : uartregs :=
  (rxen => '1', txen => '1', rirqen => '0', tirqen => '0', parsel => '1',
   paren => '0', loopb => '0', debug => '0', rsempty => '1',
   tsempty => '1', stop => '0', break => '0', 
   ovf => '0', parerr => '0', frame => '0', ctsn => (others => '0'),
   rts => '0', extclken => '0', extclk => '0', rhold => fifozero,
   rshift => (others => '0'), tshift => (others => '1'), thold => fifozero,
   irq => '0',  tpar => '0', txstate => idle,
   txclk => (others => '0'), txtick => '0', rxstate => idle,
   rxclk => (others => '0'), rxdb => (others => '0'), dpar => '0',rxtick => '0',
   tick => '0', scaler => sbitszero, brate => sbitszero, rxf => (others => '0'),
   txd => '1', 
   rwaddr => addrzero, rraddr => addrzero, traddr => addrzero, twaddr => addrzero,
   rcnt => rcntzero, tcnt => rcntzero,
   -- 16550 signals
   enfifo => '0', triglvl => "00", dlab => '0', genbreak => '0', rlsirqen => '0',
   rfifoerr => fifoerrzero, pendfifoerr => '0', rshifterr => "000", irqcause => "00",
   thempty => '1', thirqpend => '0', irqtimeout => '0', timeoutcnt => (others => '0'),
   scratch => (others => '0'), dcts => '0', irqpend => '0', modirqen => '0' 
   );
signal r, rin : uartregs;


begin
  uartop : process(rst, r, apbi, uarti )
  variable rdata : std_logic_vector(31 downto 0);
  variable scaler : std_logic_vector(sbits-1 downto 0);
  variable rxclk, txclk : std_logic_vector(3 downto 0);
  variable rxd : std_ulogic;
  variable irq : std_logic_vector(NAHBIRQ-1 downto 0);
  variable paddress : std_logic_vector(abits-1 downto 2);
  variable v : uartregs;
  variable rfull : std_ulogic;
  variable tfull : std_ulogic;
  variable dready : std_ulogic;
  variable thempty : std_ulogic;
  variable clrrfifo : std_ulogic; 
  variable clrtfifo : std_ulogic; 
  variable rtrigfull : std_ulogic;
  variable lvlmask : std_logic_vector(log2x(fifosize) downto 0);
  variable maxtimeout : std_logic_vector(5 downto 0);
--pragma translate_off
  variable L1 : line;
  variable CH : character;
  variable FIRST : boolean := true;
  variable pt : time := 0 ns;
--pragma translate_on

  begin

    v := r; irq := (others => '0'); irq(pirq) := r.irq;
    v.irq := '0'; v.txtick := '0'; v.rxtick := '0'; v.tick := '0';
    rdata := (others => '0'); v.rxdb(1) := r.rxdb(0);
    dready := '0'; thempty := '1'; 
    v.ctsn := r.ctsn(0) & uarti.ctsn;
    paddress := (others => '0');
    paddress(abits-1 downto 2) := apbi.paddr(abits-1 downto 2);
    clrrfifo := '0'; clrtfifo := '0';  
    rtrigfull := '0';
    v.irqcause := "00"; v.irqtimeout := '0';

    if r.enfifo = '0' then
      dready := r.rcnt(0); rfull := dready; tfull := r.tcnt(0);
      thempty := not tfull;
    else
      tfull := r.tcnt(log2x(fifosize)); rfull := r.rcnt(log2x(fifosize));
      lvlmask := (others => '0');
      if fifomode = 1 then
        case r.triglvl is
          when "00" =>
            lvlmask(log2x(fifosize) downto 0) := (others => '1');
          when "01" =>
            lvlmask(log2x(fifosize) downto 2) := (others => '1');
          when "10" =>
            lvlmask(log2x(fifosize) downto 3) := (others => '1');
          when others =>
        end case;
        if (r.triglvl(0) and r.triglvl(1)) = '1' then
          if unsigned(r.rcnt) >= 14 then
            rtrigfull := '1';
          end if;
        else
          if unsigned(r.rcnt and lvlmask) /= 0 then
            rtrigfull := '1';
          end if;
        end if;
      end if;
      if r.rcnt /= rcntzero then dready := '1'; end if;
      if r.tcnt /= rcntzero then thempty := '0'; end if;
    end if;

    -- Check if the data at the top of the receiver FIFO rose any error
    v.parerr := r.parerr or r.rfifoerr(conv_integer(r.rraddr))(0);
    v.frame  := r.frame  or r.rfifoerr(conv_integer(r.rraddr))(1);
    v.break  := r.break  or r.rfifoerr(conv_integer(r.rraddr))(2);

-- timeout interrupt

    if (r.stop and r.paren) = '1' then
      maxtimeout := conv_std_logic_vector(48, 6);
    elsif (r.stop or r.paren) = '1' then
      maxtimeout := conv_std_logic_vector(44, 6);
    else
      maxtimeout := conv_std_logic_vector(40, 6);
    end if;

    if (r.enfifo and r.rirqen and r.rxtick) = '1' and dready = '1' then
      if r.timeoutcnt /= maxtimeout then 
        v.timeoutcnt := r.timeoutcnt + 1;
      end if;
    end if;

-- scaler

    scaler := r.scaler - 1;
    if (r.rxen or r.txen) = '1' then
      v.scaler := scaler;
      v.tick := scaler(sbits-1) and not r.scaler(sbits-1);
      if v.tick = '1' then v.scaler := r.brate; end if;
    end if;

-- optional external uart clock
    v.extclk := uarti.extclk;
    if r.extclken = '1' then v.tick := r.extclk and not uarti.extclk; end if;


-- read/write registers

  if (apbi.psel(pindex) and apbi.penable and (not apbi.pwrite)) = '1' then
    case conv_integer(paddress(5 downto 2)) is
    when 0 => 
      if r.dlab = '0' then -- Receiver Buffer Register
        rdata(7 downto 0) := r.rhold(conv_integer(r.rraddr));
        v.rfifoerr(conv_integer(r.rraddr)) := "000";
        if r.enfifo = '0' then 
          v.rcnt(0) := '0';
        else
          if r.rcnt /= rcntzero then
            v.rraddr := r.rraddr + 1; v.rcnt := r.rcnt - 1;
            v.timeoutcnt := (others => '0');
          end if;
        end if;
      else                 -- Divisor Latch LS 
        rdata(7 downto 0) := r.brate(7 downto 0);
      end if;
    when 1 => 
      if r.dlab = '0' then -- Interrupt Enable Register (IER)
         rdata(3 downto 0) := r.modirqen & r.rlsirqen & r.tirqen & r.rirqen;
      else                 -- Divisor Latch MS (DL)
        rdata(sbits-8-1 downto 0) := r.brate(sbits-1 downto 8);
      end if;
    when 2 => -- Interrupt Identification Register (IIR)
      if r.enfifo = '1' then
        rdata(7 downto 6) := "11";
      end if;
      rdata(3 downto 0) := r.irqtimeout & r.irqcause & not(r.irqpend);
      -- Clear Transmitter Holding Register empty if IIR is read
      if r.irqcause & r.irqpend = "011" then
        v.thirqpend := '0';
      end if;
    when 3 => -- Line Control Register (LCR)
      rdata(7) := r.dlab;
      rdata(6) := r.genbreak;    
      rdata(5) := '0';           
      rdata(4) := not(r.parsel); 
      rdata(3) := r.paren; 
      rdata(2) := r.stop;
      rdata(1 downto 0) := "11";
    when 4 => -- MODEM Control Register (MCR) 
      rdata(4) := r.loopb;
      rdata(1) := r.rts;
    when 5 => -- Line Status Register (LSR)
      if r.enfifo = '1' then  
        rdata(7) := r.pendfifoerr;
      end if;
      rdata(6 downto 5) := (r.tsempty and thempty) & thempty;
      rdata(4 downto 1) := r.break & r.frame & r.parerr & r.ovf; 
      rdata(0) := dready; 
      -- Clear errors when read
      v.break := '0'; v.frame := '0'; v.parerr := '0'; v.ovf := '0';
      v.rfifoerr(conv_integer(r.rraddr)) := "000";
      v.pendfifoerr := '0';
    when 6 => -- MODEM Status Register 
      if r.loopb = '1' then
        rdata(4) := r.rts; 
      else
        rdata(4) := not(r.ctsn(1)); 
      end if;
      rdata(0) := r.dcts;
      v.dcts := '0';
    when 7 => -- Scratch register      
      rdata(7 downto 0) := r.scratch;
    when 8 => -- Custom control register
      rdata(2 downto 0) := r.extclken & r.txen & r.rxen;
    when 9 => -- Custom receiver FIFO count
      rdata(log2x(fifosize) downto 0) := r.rcnt;
    when 10 => -- Custom transmitter FIFO count
      rdata(log2x(fifosize) downto 0) := r.tcnt;
    when 11 => -- Debug mode register
      rdata(0) := r.debug;
    when 12 => -- Debug register
      -- Read TX FIFO.
      if r.debug = '1' and r.tcnt /= rcntzero then
          rdata(7 downto 0) := r.thold(conv_integer(r.traddr));
          if r.enfifo = '0' then
              v.tcnt(0) := '0';
          else
              v.traddr := r.traddr + 1;
              v.tcnt := r.tcnt - 1;
          end if;
      end if;
    when others => 
    end case;
  end if;

  if (apbi.psel(pindex) and apbi.penable and apbi.pwrite) = '1' then
    case conv_integer(paddress(5 downto 2)) is
    when 0 => 
      if r.dlab = '1' then -- Divisor Latch [LS] (DLL)
        v.brate(7 downto 0)  := apbi.pwdata(7 downto 0);
        v.scaler(7 downto 0) := apbi.pwdata(7 downto 0);
      end if;
    when 1 => 
      if r.dlab = '0' then -- Interrupt Enable Register (IER)
        v.modirqen := apbi.pwdata(3);
        v.rlsirqen := apbi.pwdata(2);
        v.tirqen := apbi.pwdata(1);
        v.rirqen := apbi.pwdata(0);
      else                 -- Divisor Latch [MS] (DLM)
        v.brate(sbits-1 downto 8)  := apbi.pwdata(sbits-8-1 downto 0);
        v.scaler(sbits-1 downto 8) := apbi.pwdata(sbits-8-1 downto 0);
      end if;
    when 2 => -- FIFO Control Register
      v.triglvl := apbi.pwdata(7 downto 6);      
      clrtfifo  := apbi.pwdata(2);
      clrrfifo  := apbi.pwdata(1);
      if fifomode = 1 then
        v.enfifo  := apbi.pwdata(0);
      else
        v.enfifo  := '0';
      end if;
    when 3 => -- Line Control Register (LCR)
      v.dlab     := apbi.pwdata(7);
      v.genbreak := apbi.pwdata(6);
      v.parsel   := not(apbi.pwdata(4));
      v.paren    := apbi.pwdata(3);
      v.stop     := apbi.pwdata(2);
    when 4 => -- MODEM Control Register (MCR)
      v.loopb    := apbi.pwdata(4);
      v.rts      := apbi.pwdata(1);
    -- Line Status Register (LSR) and
    -- MODEM Status Register (MSR) are read-only
    when 7 => -- Scratch register (SCR)
      v.scratch := apbi.pwdata(7 downto 0);
    when 8 => -- Custom control register
      v.extclken := apbi.pwdata(2);
      v.txen     := apbi.pwdata(1);
      v.rxen     := apbi.pwdata(0);
    -- Custom receiver FIFO count and Custom transmitter FIFO count
    -- are read-only registers
    when 11 => -- Debug mode register 
      v.debug    := apbi.pwdata(0);
    when 12 => -- Debug register 
      -- Write RX fifo and generate irq
      if flow /= 0 then
        v.rhold(conv_integer(r.rwaddr)) := apbi.pwdata(7 downto 0);
        if r.enfifo = '0' then 
          v.rcnt(0) := '1';
        else 
          v.rwaddr := r.rwaddr + 1; 
          v.rcnt := v.rcnt + 1; 
        end if;
        if r.debug = '1' then
            v.irq := v.irq or r.rirqen;
        end if;
      end if;
    when others =>
    end case;
  end if;


-- tx clock

    txclk := r.txclk + 1;
    if r.tick = '1' then
      v.txclk := txclk;
      v.txtick := r.txclk(3) and not txclk(3);
    end if;

-- rx clock

    rxclk := r.rxclk + 1;
    if r.tick = '1' then
      v.rxclk := rxclk;
      v.rxtick := r.rxclk(3) and not rxclk(3);
    end if;

-- filter rx data

--    v.rxf := r.rxf(6 downto 0) & uarti.rxd;
--    if ((r.rxf(7) & r.rxf(7) & r.rxf(7) & r.rxf(7) & r.rxf(7) & r.rxf(7) &
--       r.rxf(7)) = r.rxf(6 downto 0))
--    then v.rxdb(0) := r.rxf(7); end if;

    v.rxf(1 downto 0) := r.rxf(0) & uarti.rxd;  -- meta-stability filter
    if r.tick = '1' then
      v.rxf(4 downto 2) := r.rxf(3 downto 1);
    end if;
    v.rxdb(0) := (r.rxf(4) and r.rxf(3)) or (r.rxf(4) and r.rxf(2)) or 
                  (r.rxf(3) and r.rxf(2));


-- delta clear to send

    if (r.ctsn(1) xor r.ctsn(0)) = '1' and flow = 1 then
      v.dcts := '1';
    end if;

-- loop-back mode

    if r.loopb = '1' then
      v.rxdb(0) := r.tshift(0);
      v.ctsn := r.ctsn(0) & not(r.rts);
    end if;
    rxd := r.rxdb(0);

-- transmitter operation

    case r.txstate is
    when idle =>        -- idle and stopbit state
      if (r.txtick = '1') then v.tsempty := '1'; end if;
      
      if (not r.debug and r.txen and (not thempty) and r.txtick) = '1' then
          v.txstate := data;
          v.tpar := r.parsel; v.tsempty := '0';
          v.txclk := "000" & r.tick; v.txtick := '0';
          v.tshift := '0' & r.thold(conv_integer(r.traddr)) & '0';
          if r.enfifo = '0' then
              v.tcnt(0) := '0';
          else
              v.traddr := r.traddr + 1;
              v.tcnt := r.tcnt - 1;
          end if;
      end if;
    when data =>        -- transmit data frame
      if r.txtick = '1' then
        v.tpar := r.tpar xor r.tshift(1);
        v.tshift := '1' & r.tshift(9 downto 1);
        if r.tshift(9 downto 1) = "111111110" then
          if r.paren = '1' then
            v.tshift(0) := r.tpar; v.txstate := cparity;
          elsif r.stop = '1' then
            v.tshift(0) := '1'; v.txstate := stopbit;
          else
            v.tshift(0) := '1'; v.txstate := idle;
          end if;
        end if;
      end if;
    when cparity =>     -- transmit parity bit
      if r.txtick = '1' then
        v.tshift := '1' & r.tshift(9 downto 1);
        if r.stop = '1' then
          v.txstate := stopbit;
        else
          v.txstate := idle;
        end if;
      end if;
    when stopbit =>
      if r.txtick = '1' then
        v.txstate := idle;
      end if;
    end case;

-- writing of tx data register must be done after tx fsm to get correct
-- operation of thempty flag

    if (apbi.psel(pindex) and apbi.penable and apbi.pwrite) = '1' then
      if paddress(5 downto 2) = "0000" and r.dlab = '0' then
        if r.enfifo = '0' then
          v.thold(0) := apbi.pwdata(7 downto 0); v.tcnt(0) := '1';
        else
          v.thold(conv_integer(r.twaddr)) := apbi.pwdata(7 downto 0);
          if not (tfull = '1') then
            v.twaddr := r.twaddr + 1; v.tcnt :=  v.tcnt + 1;
          end if;
        end if;
--pragma translate_off
        if CONSOLE = 1 then
          if first then L1:= new string'(""); first := false; end if; --'
          if apbi.penable'event then    --'
            CH := character'val(conv_integer(apbi.pwdata(7 downto 0))); --'
            if CH  = CR then
              std.textio.writeline(OUTPUT, L1);
            elsif CH /= LF then
              std.textio.write(L1,CH);
            end if;
            pt := now;
          end if;
        end if;
--pragma translate_on
      end if;
    end if;


-- receiver operation

    case r.rxstate is
    when idle =>        -- wait for start bit
      if ((r.rsempty = '0') and not (rfull = '1')) then
          v.rsempty := '1';
          v.rhold(conv_integer(r.rwaddr)) := r.rshift;
          v.rfifoerr(conv_integer(r.rwaddr)) := r.rshifterr;
          v.rshifterr := "000";
          if r.enfifo = '0' then v.rcnt(0) := '1';
          else v.rwaddr := r.rwaddr + 1; v.rcnt := v.rcnt + 1; end if;
      end if;
      if (r.rxen and r.rxdb(1) and (not rxd)) = '1' then
        v.rxstate := startbit; v.rshift := (others => '1'); v.rxclk := "1000"; 
        v.rxtick := '0';
      end if;
    when startbit =>    -- check validity of start bit
      if r.rxtick = '1' then
        if rxd = '0' then
          v.rshift := rxd & r.rshift(7 downto 1); v.rxstate := data;
          v.dpar := r.parsel;
          if v.rsempty = '0' then v.ovf := '1'; end if;
          v.rsempty := '0'; 
        else
          v.rxstate := idle;
        end if;
      end if;
    when data =>        -- receive data frame
      if r.rxtick = '1' then
        v.dpar := r.dpar xor rxd;
        v.rshift := rxd & r.rshift(7 downto 1);
        if r.rshift(0) = '0' then
          if r.paren = '1' then v.rxstate := cparity;
          else v.rxstate := stopbit; v.dpar := '0'; end if;
        end if;
      end if;
    when cparity =>     -- receive parity bit
      if r.rxtick = '1' then
        v.dpar := r.dpar xor rxd; v.rxstate := stopbit;
      end if;
    when stopbit =>     -- receive stop bit
      if r.rxtick = '1' then
        if rxd = '1' then
          v.rshifterr(0) := r.dpar; v.rsempty := r.dpar; 
        else
          if r.rshift = "00000000" then
            v.rshifterr(2) := '1'; -- break error
          else v.rshifterr(1) := '1'; end if; -- frame error
          v.rsempty := '1';
        end if;
        if not (rfull = '1') then
          v.rsempty := '1';
          v.rhold(conv_integer(r.rwaddr)) := r.rshift;
          v.rfifoerr(conv_integer(r.rwaddr)) := v.rshifterr;
          v.rshifterr := "000";
          v.timeoutcnt := (others => '0');
          if r.enfifo = '0' then v.rcnt(0) := '1';
          else v.rwaddr := r.rwaddr + 1; v.rcnt := v.rcnt + 1; end if;
        end if;
        v.rxstate := idle;
      end if;
    end case;

    v.txd := r.tshift(0) or r.loopb;

    if v.rfifoerr /= fifoerrzero then
      v.pendfifoerr := '1';
    end if;


-- interrupts

    -- MODEM interrupts
    if (r.modirqen and r.dcts) = '1' then
      v.irq := '1';
      v.irqcause := "00";
    end if;

    -- Transmitter Holding register/FIFO empty
    v.thempty := thempty;
    if r.thempty = '0' and v.thempty = '1' and r.tirqen = '1' then
      v.thirqpend := '1';
    elsif r.thempty = '1' and v.thempty = '0' then
      v.thirqpend := '0';
    end if;
    
    if r.thirqpend = '1' then
      v.irq := '1';
      v.irqcause := "01";
    end if;

    -- Receiver interrupts (Data available/tigger level reached/Timeout)
    if r.enfifo = '1' then
      if (r.rirqen and rtrigfull) = '1' then
        v.irqcause := "10";
        v.irq := '1';
      end if;
      if r.rirqen = '1' and r.timeoutcnt = maxtimeout then
        v.irqcause := "10";
        v.irq := '1';
        v.irqtimeout := '1';
      end if;
    else
      if (dready and r.rirqen) = '1' then
        v.irqcause := "10";
        v.irq := '1';
      end if;
    end if;

    -- Receiver line status interrupts
    if ((v.break or v.frame or v.parerr or v.ovf) and r. rlsirqen) = '1' then
      v.irqcause := "11";
      v.irq := '1';
    end if;

    v.irqpend  := v.irq;



-- reset operation

    if (not RESET_ALL) and (rst = '0') then
    
-- Not reseted signals

      --  (rirqen => '0', tirqen => '0', parsel => '1',
      --   paren => '0', loopb => '0', debug => '0', 
      --   tsempty => '1'
      --    ctsn => (others => '0'),
      --   rts => '0',  extclk => '0', rhold => fifozero,
      --   rshift => (others => '0'), 
      --   irq => '0',  tpar => '0', 
      -- txtick => '0', 
      --   rxdb => (others => '0'), dpar => '0',rxtick => '0',
      --   tick => '0', scaler => sbitszero, brate => sbitszero, rxf => (others => '0'),
      --   txd => '1', 

-- Reseted old signals

      v.frame := RES.frame; v.rsempty := RES.rsempty;
      v.parerr := RES.parerr; v.ovf := RES.ovf; v.break := RES.break;
      v.tsempty := RES.tsempty; v.stop := RES.stop; v.txen := RES.txen; v.rxen := RES.rxen;
      v.txstate := RES.txstate; v.rxstate := RES.rxstate; v.tshift(0) := RES.tshift(0);
      v.extclken := RES.extclken; v.rts := RES.rts; 
      v.txclk := RES.txclk; v.rxclk := RES.rxclk;
      v.rcnt := RES.rcnt; v.tcnt := RES.tcnt;
      v.rwaddr := RES.rwaddr; v.twaddr := RES.twaddr;
      v.rraddr := RES.rraddr; v.traddr := RES.traddr;

    
-- New signals

      v.enfifo := RES.enfifo; v.triglvl := RES.triglvl; v.dlab := RES.dlab; v.genbreak := RES.genbreak; v.rlsirqen := RES.rlsirqen;
      v.rfifoerr := RES.rfifoerr; v.pendfifoerr := RES.pendfifoerr; v.rshifterr := RES.rshifterr; v.irqcause := RES.irqcause;  
      v.scratch := RES.scratch;
      v.thempty := RES.thempty; v.thirqpend := RES.thirqpend; v.irqtimeout := RES.irqtimeout; v.timeoutcnt := RES.timeoutcnt;
      v.scratch := RES.scratch; v.dcts := RES.dcts; v.irqpend := RES.irqpend; v.modirqen := RES.modirqen;  

-- pragma translate_off
      v := RES;
-- pragma translate_on
    end if;

-- Clear FIFOs content
    if clrrfifo = '1' or (v.enfifo xor r.enfifo) = '1' then
      v.rhold := fifozero; v.rfifoerr := fifoerrzero;
      v.rwaddr := addrzero; v.rraddr := addrzero;
      v.rcnt := rcntzero;
    end if;

    if clrtfifo = '1' or (v.enfifo xor r.enfifo) = '1' then
      v.thold := fifozero;
      v.traddr := addrzero; v.twaddr := addrzero;
      v.tcnt := rcntzero;
    end if;

-- update registers

    rin <= v;

-- if flow is not active

    if flow = 0 then
      v.ctsn := (others => '0');
      v.rts  := '1';
    end if;

-- drive outputs

    uarto.txd <= r.txd and not(r.genbreak); 
    uarto.rtsn <= not(r.rts) or r.loopb;
    uarto.scaler <= (others => '0');
    uarto.scaler(sbits-1 downto 0) <= r.scaler;
    apbo.prdata <= rdata; apbo.pirq <= irq;
    apbo.pindex <= pindex;
    uarto.txen <= r.txen; uarto.rxen <= r.rxen;
    uarto.flow <= std_logic(to_unsigned(flow, 1)(0));
    uarto.txtick <= r.txtick; uarto.rxtick <= r.rxtick;
  
  end process;

  apbo.pconfig <= pconfig;

  regs : process(clk)
  begin
    if rising_edge(clk) then
      r <= rin;
      if RESET_ALL and rst = '0' then
        r <= RES;
        -- Sync. registers not reset
        r.ctsn <= rin.ctsn;
        r.rxf <= rin.rxf;
      end if;
    end if;
  end process;

-- pragma translate_off
    bootmsg : report_version
    generic map ("apbuart" & tost(pindex) &
        ": Generic UART rev " & tost(REVISION) & ", fifo " & tost(fifosize) &
        ", irq " & tost(pirq) & ", scaler bits " & tost(sbits));
-- pragma translate_on

end;

