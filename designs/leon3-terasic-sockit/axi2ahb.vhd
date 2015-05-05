------------------------------------------------------------------------------
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 
-------------------------------------------------------------------------------
-- Entity:      axi2ahb
-- File:        axi2ahb.vhd
-- Author:      Martin George
--
-- AXI/AHB bridge allowing Altera HPS to access LEON3 bus.
-- AHB master interface currently only supports OKAY response from slave.
-- AXI slave only supports incrementing bursts of length 1-16 transfers.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;

Entity axi2ahb is
	generic(
		hindex			: integer := 0;
		idsize			: integer := 6;
		lensize			: integer := 4;
		fifo_depth		: integer := 16
		);
	port(
		ahb_clk			: in  std_logic;
		axi_clk 		: in  std_logic;
		resetn			: in  std_logic;
		ahbi    		: in  ahb_mst_in_type;
    	ahbo    		: out ahb_mst_out_type;
		s_axi_araddr    : in  std_logic_vector ( 31 downto 0 );
		s_axi_arburst   : in  std_logic_vector ( 1 downto 0 );
		s_axi_arcache   : in  std_logic_vector ( 3 downto 0 );
		s_axi_arid      : in  std_logic_vector ( idsize-1 downto 0 );
		s_axi_arlen     : in  std_logic_vector ( lensize-1 downto 0 );
		s_axi_arlock    : in  std_logic_vector (1 downto 0);
		s_axi_arprot    : in  std_logic_vector ( 2 downto 0 );
		s_axi_arqos     : in  std_logic_vector ( 3 downto 0 );
		s_axi_arready   : out std_logic;
		s_axi_arsize    : in  std_logic_vector ( 2 downto 0 );
		s_axi_arvalid   : in  std_logic;
		s_axi_awaddr    : in  std_logic_vector ( 31 downto 0 );
		s_axi_awburst   : in  std_logic_vector ( 1 downto 0 );
		s_axi_awcache   : in  std_logic_vector ( 3 downto 0 );
		s_axi_awid      : in  std_logic_vector ( idsize-1 downto 0 );
		s_axi_awlen     : in  std_logic_vector ( lensize-1 downto 0 );
		s_axi_awlock    : in  std_logic_vector (1 downto 0);
		s_axi_awprot    : in  std_logic_vector ( 2 downto 0 );
		s_axi_awqos     : in  std_logic_vector ( 3 downto 0 );
		s_axi_awready   : out std_logic;
		s_axi_awsize    : in  std_logic_vector ( 2 downto 0 );
		s_axi_awvalid   : in  std_logic;
		s_axi_bid       : out std_logic_vector ( idsize-1 downto 0 );
		s_axi_bready    : in  std_logic;
		s_axi_bresp     : out std_logic_vector ( 1 downto 0 );
		s_axi_bvalid    : out std_logic;
		s_axi_rdata     : out std_logic_vector ( 31 downto 0 );
		s_axi_rid       : out std_logic_vector ( idsize-1 downto 0 );
		s_axi_rlast     : out std_logic;
		s_axi_rready    : in  std_logic;
		s_axi_rresp     : out std_logic_vector ( 1 downto 0 );
		s_axi_rvalid    : out std_logic;
		s_axi_wdata     : in  std_logic_vector ( 31 downto 0 );
		s_axi_wid       : in  std_logic_vector ( idsize-1 downto 0 );
		s_axi_wlast     : in  std_logic;
		s_axi_wready    : out std_logic;
		s_axi_wstrb     : in  std_logic_vector ( 3 downto 0 );
		s_axi_wvalid    : in  std_logic
		);
end;

architecture rtl of axi2ahb is

	constant hconfig : ahb_config_type := (
		0 => ahb_device_reg ( VENDOR_GAISLER, GAISLER_AXI2AHB, 0, 0, 0),
		others => zero32);
	
	type axi_w_state_type is (w_start, w_wait, w_data_fifo, w_ahb, w_done);
	type axi_r_state_type is (r_start, r_wait, r_data_fifo, r_done);
	type ahb_rw_state_type is (idle, w_req, w_first_addr, w_data_addr, w_done, r_req, 
							r_first_addr, r_data_addr, r_done);

	type fifo is array (fifo_depth-1 downto 0) of std_logic_vector(31 downto 0);

	type ahb_record is record
		--States--
		ahb_rw_state		: ahb_rw_state_type;
		--Outputs--
		hwrite				: std_logic;
		hbusreq				: std_logic;
		hlock				: std_logic;
		hsize				: std_logic_vector(2 downto 0);
		htrans				: std_logic_vector(1 downto 0);
		hwdata				: std_logic_vector(31 downto 0);
		haddr				: std_logic_vector(31 downto 0);
		hwaddr				: std_logic_vector(9 downto 0);
		hraddr				: std_logic_vector(9 downto 0);
		hburst				: std_logic_vector(2 downto 0);
		inc_sel				: std_logic_vector(2 downto 0);
		--FIFO signals--
		rfifo 				: fifo;
		rfifo_w_ptr			: integer range 0 to fifo_depth-1;
		wfifo_r_ptr			: integer range 0 to fifo_depth-1;
		--Control signals--
		ahb_haddr_stop		: std_logic;
		ahb_w_en_ack		: std_logic;
		ahb_r_done			: std_logic;
		ahb_w_done			: std_logic;
		addr_incr			: integer range 0 to 15;
	end record;

	type axi_record is record
		--States--
		axi_w_state 		: axi_w_state_type;
		axi_r_state 		: axi_r_state_type;
		--Outputs--
	    arready  			: std_logic;
		awready  			: std_logic;
		bvalid   			: std_logic;
		rdata    			: std_logic_vector ( 31 downto 0 );
		rlast    			: std_logic;
		rvalid   			: std_logic;
		wready   			: std_logic;
	    --FIFO signals--
	    wfifo 				: fifo;
	    wfifo_w_ptr			: integer range 0 to fifo_depth-1;
	    rfifo_r_ptr			: integer range 0 to fifo_depth-1;
	    --Control signals--
	    --Write--
	    awaddr 				: std_logic_vector(31 downto 0);
	    awburst 			: std_logic_vector(1 downto 0);
	    awlen 				: std_logic_vector(lensize-1 downto 0);
	    awsize 				: std_logic_vector(2 downto 0);
	    awid 				: std_logic_vector(idsize-1 downto 0);
	    --Read--
	    arid 				: std_logic_vector(idsize-1 downto 0);
	    araddr 				: std_logic_vector(31 downto 0);
	    arburst 			: std_logic_vector(1 downto 0);
	    arlen 				: std_logic_vector(lensize-1 downto 0);
	    arsize 				: std_logic_vector(2 downto 0);
	    --AHB--
	    ahb_r_en 			: std_logic;
	    ahb_w_en 			: std_logic;
	end record; 

	signal h, hin 		: ahb_record;
	signal x, xin		: axi_record;

begin

	comb: process(resetn, ahbi, x, h, s_axi_araddr, s_axi_arburst, 
					s_axi_arcache, s_axi_arid, s_axi_arlen, s_axi_arlock, 
					s_axi_arprot, s_axi_arqos, s_axi_arsize, s_axi_arvalid, 
					s_axi_awaddr, s_axi_awburst, s_axi_awcache, s_axi_awid, 
					s_axi_awlen, s_axi_awlock, s_axi_awprot, s_axi_awqos,
					s_axi_awsize, s_axi_awvalid, s_axi_bready, s_axi_rready,
					s_axi_wdata, s_axi_wid,	s_axi_wlast, s_axi_wstrb, s_axi_wvalid)
	variable vx  		: axi_record;
	variable vh  		: ahb_record;
	begin
		vx := x;
		vh := h;

	--	AXI WRITE STATES
		case x.axi_w_state is

			when w_start =>
				vx.awready := '1';
				vx.wready := '0';
				vx.ahb_w_en := '0';
				vx.bvalid := '0';
				if s_axi_awvalid = '1' then
					vx.axi_w_state := w_wait;
					vx.awready := '0';
					vx.awlen := s_axi_awlen;
					vx.awburst := s_axi_awburst;
					vx.awsize := s_axi_awsize;
					vx.awaddr := s_axi_awaddr;
					vx.awid := s_axi_awid;
				end if;

			when w_wait =>
				vx.awready := '0';
				if h.ahb_w_done = '1' then
					vx.wfifo_w_ptr := 0;
					vx.axi_w_state := w_data_fifo;
				end if;

			when w_data_fifo =>
				vx.awready := '0';
				vx.wfifo_w_ptr := x.wfifo_w_ptr;
				vx.wready := '0';
				if s_axi_wvalid = '1' then
					vx.wready := '1';
					if s_axi_wlast = '1' then
						vx.axi_w_state := w_ahb;
					else
						vx.wfifo_w_ptr := x.wfifo_w_ptr + 1;
					end if;
				end if;

			when w_ahb =>
				vx.wready := '0';
				vx.ahb_w_en := '1';
				if h.ahb_w_en_ack = '1' then
					vx.ahb_w_en := '0';
					vx.bvalid := '1';
					vx.axi_w_state := w_done;
				end if;

			when w_done =>
				if s_axi_bready = '1' then
					vx.bvalid := '0';
					vx.axi_w_state := w_start;
				else
				end if;
				
		end case;

	--	AXI READ STATES
		case x.axi_r_state is

			when r_start =>
				vx.arready := '1';
				vx.rvalid := '0';
				vx.rfifo_r_ptr := 0;
				vx.rlast := '0';
				if s_axi_arvalid = '1' then
					vx.arready := '0';
					vx.ahb_r_en := '1';
					vx.arlen := s_axi_arlen;
					vx.arburst := s_axi_arburst;
					vx.arsize := s_axi_arsize;
					vx.araddr := s_axi_araddr;
					vx.arid := s_axi_arid;
					vx.axi_r_state := r_wait;
				end if;

			when r_wait =>
				vx.arready := '0';
				if h.ahb_r_done = '1' then
					vx.ahb_r_en := '0';
					vx.axi_r_state := r_data_fifo;
				end if;

			when r_data_fifo =>
				vx.rdata := h.rfifo(x.rfifo_r_ptr);
				vx.rvalid := '1';
				vx.rfifo_r_ptr := x.rfifo_r_ptr;
			--	if x.rfifo_r_ptr = conv_integer(x.arlen) then
				if x.rfifo_r_ptr = h.rfifo_w_ptr then
					vx.rlast := '1';
					vx.axi_r_state := r_done;
				elsif s_axi_rready = '1' then
					vx.rfifo_r_ptr := x.rfifo_r_ptr + 1;
				end if;

			when r_done =>
				vx.rvalid := '1';
				if s_axi_rready = '1' then
					vx.rvalid 		:= '0';
					vx.rfifo_r_ptr 	:= 0;
					vx.rlast 		:= '0';
					vx.axi_r_state 	:= r_start;
				else
				end if;

		end case;

	--	AHB READ/WRITE STATES	
		case h.ahb_rw_state is

			when idle =>
				vh.ahb_w_en_ack 	:= '0';
				vh.ahb_r_done 		:= '0';
				vh.htrans 			:= "00";
				if x.ahb_w_en = '1' then
					vh.ahb_w_done 		:= '0';
					vh.ahb_rw_state 	:= w_req;
					vh.hsize 			:= x.awsize;
					vh.inc_sel 			:= x.awsize;
				elsif x.ahb_r_en = '1' then
					vh.ahb_r_done 		:= '0';
					vh.ahb_rw_state 	:= r_req;
					vh.hsize 			:= "010";
					vh.inc_sel 			:= x.arsize;
				else
				end if;

		--	WRITE STATES
			when w_req =>
				vh.ahb_w_en_ack := '1';
				vh.hbusreq 		:= '1';
				vh.hlock 		:= '1';
				vh.hwrite 		:= '1';
				if conv_integer(x.awlen) /= 0 then
					vh.hburst 			:= "001";
				else
					vh.hburst 			:= "000";
				end if;
				if (ahbi.hgrant(hindex) and ahbi.hready) = '1' then
					vh.ahb_rw_state 	:= w_first_addr;
				else
				end if;

			when w_first_addr =>
				vh.htrans 		:= "10";
				vh.hwaddr		:= x.awaddr(9 downto 0);
				vh.haddr 		:= x.awaddr;
				case h.hsize is
					when "000" =>
						vh.haddr(1 downto 0) := not x.awaddr(1 downto 0);
					when "001" =>
						vh.haddr(1) 		 := not x.awaddr(1);
					when others =>
				end case;
				vh.ahb_rw_state := w_data_addr;

			when w_data_addr =>
				vh.htrans := "11";
				vh.hwdata := x.wfifo(h.wfifo_r_ptr);
				if h.wfifo_r_ptr = x.wfifo_w_ptr then
					vh.htrans 				:= "00";
					vh.ahb_rw_state 		:= w_done;
				elsif ahbi.hready = '1' then
					vh.hwaddr 				:= h.hwaddr + h.addr_incr;
					vh.haddr(9 downto 0)	:= vh.hwaddr;
					case h.hsize is
						when "000" =>
							vh.haddr(1 downto 0) := not vh.hwaddr(1 downto 0);
						when "001" =>
							vh.haddr(1) 		 := not vh.hwaddr(1);
						when others =>
					end case;
					vh.wfifo_r_ptr 			:= h.wfifo_r_ptr + 1;	
				end if;	

			when w_done =>
				if ahbi.hready = '1' then
					vh.ahb_haddr_stop 	:= '0';
					vh.htrans 			:= "00";
					vh.wfifo_r_ptr 		:= 0;
					vh.ahb_w_en_ack 	:= '0';
					vh.ahb_w_done 		:= '1';
					vh.hbusreq 			:= '0';
					vh.hlock 			:= '0';
					vh.ahb_rw_state 	:= idle;
				else
				end if;

		--	READ STATES
			when r_req =>
				vh.rfifo_w_ptr 	:= 0;
				vh.hbusreq 		:= '1';
				vh.hlock 		:= '1';
				vh.hwrite 		:= '0';
				if conv_integer(x.arlen) /= 0 then
					vh.hburst := "001";
				else
					vh.hburst := "000";
				end if;
				if (ahbi.hgrant(hindex) and ahbi.hready) = '1' then
					vh.ahb_rw_state := r_first_addr;
					vh.htrans 		:= "10";
					vh.haddr 		:= x.araddr;
					vh.hraddr 		:= x.araddr(9 downto 0);
 				else
				end if;

			when r_first_addr =>				
				if ahbi.hready = '1' then
					if h.rfifo_w_ptr /= conv_integer(x.arlen) then
						vh.hraddr				:= h.hraddr + h.addr_incr;
						vh.haddr(9 downto 0) 	:= vh.hraddr(9 downto 2) & "00";
					end if;
					vh.ahb_rw_state := r_data_addr;
				end if;

			when r_data_addr =>
				if ahbi.hready = '1' then
					vh.rfifo(h.rfifo_w_ptr) := ahbi.hrdata;
					if h.rfifo_w_ptr = conv_integer(x.arlen) then
						vh.htrans 		:= "00";
						vh.ahb_rw_state := r_done;
					else
						vh.htrans 		:= "11";
						vh.rfifo_w_ptr 	:= h.rfifo_w_ptr + 1;
						vh.hraddr				:= h.hraddr + h.addr_incr;
						vh.haddr(9 downto 0) 	:= vh.hraddr(9 downto 2) & "00";
					end if;
				else
				end if;

			when r_done =>
				vh.htrans 		:= "00";
				vh.ahb_r_done 	:= '1';
				vh.hbusreq 		:= '0';
				vh.hlock 		:= '0';
				vx.ahb_r_en 	:= '0';
				vh.ahb_rw_state := idle;

		end case;

		-- WDATA muxing
		if (s_axi_wvalid and h.ahb_w_done) = '1' then
			case s_axi_wstrb is

				when "0001" =>
					vx.wfifo(x.wfifo_w_ptr) := s_axi_wdata(7 downto 0)
											& s_axi_wdata(7 downto 0)
											& s_axi_wdata(7 downto 0)
											& s_axi_wdata(7 downto 0);
				when "0010" =>
					vx.wfifo(x.wfifo_w_ptr) := s_axi_wdata(15 downto 8)
											& s_axi_wdata(15 downto 8)
											& s_axi_wdata(15 downto 8)
											& s_axi_wdata(15 downto 8);
				when "0100" =>
					vx.wfifo(x.wfifo_w_ptr) := s_axi_wdata(23 downto 16)
											& s_axi_wdata(23 downto 16)
											& s_axi_wdata(23 downto 16)
											& s_axi_wdata(23 downto 16);
				when "1000" =>
					vx.wfifo(x.wfifo_w_ptr) := s_axi_wdata(31 downto 24)
											& s_axi_wdata(31 downto 24)
											& s_axi_wdata(31 downto 24)
											& s_axi_wdata(31 downto 24);
				when "0011" =>
					vx.wfifo(x.wfifo_w_ptr) := s_axi_wdata(15 downto 0)
											& s_axi_wdata(15 downto 0);
				when "1100" =>
					vx.wfifo(x.wfifo_w_ptr) := s_axi_wdata(31 downto 16)
											& s_axi_wdata(31 downto 16);
				when "1111" =>
					vx.wfifo(x.wfifo_w_ptr) := s_axi_wdata;
				when others =>

			end case;
		end if;

		-- HADDR increment
		case h.inc_sel is
			when "000" =>
				vh.addr_incr := 1;
			when "001" =>
				vh.addr_incr := 2;	
			when others =>
				vh.addr_incr := 4;
		end case;
		

		if resetn = '0' then
			vx.axi_w_state 		:= w_start;
			vx.axi_r_state 		:= r_start;
			vh.ahb_rw_state 	:= idle;
			vh.rfifo 			:= (others => (others => '0'));
			vx.wfifo 			:= (others => (others => '0'));
			vh.hbusreq 			:= '0';
			vh.hlock 			:= '0';
			vh.hwdata 			:= (others => '0');
			vh.haddr 			:= (others => '0');
			vx.awlen 			:= (others => '0');
			vx.awburst 			:= (others => '0');
			vx.awsize 			:= (others => '0');
			vx.awaddr 			:= (others => '0');
			vx.awid 			:= (others => '0');
			vx.wready 			:= '0';
			vx.arready 			:= '0';
			vx.awready 			:= '0';
			vx.rdata  			:= (others => '0');
			vx.araddr 			:= (others => '0');
			vx.arburst 			:= (others => '0');
			vx.arlen 			:= (others => '0');
			vx.arid 			:= (others => '0');
			vx.bvalid 			:= '0';
			vx.rlast 			:= '0';
			vx.rvalid 			:= '0';
			vx.wready 			:= '0';
			vh.ahb_r_done 		:= '0';
			vx.ahb_r_en 		:= '0';
			vx.ahb_w_en 		:= '0';
			vh.hwrite 			:= '0';
			vh.hsize 			:= (others => '0');
			vh.ahb_w_done 		:= '1';
			vx.arsize 			:= (others => '0');
			vh.hburst 			:= (others => '0');
		end if;

		xin <= vx;
		hin <= vh;

	end process;

	ahbo.hconfig	<= hconfig;
	ahbo.hindex		<= hindex;
	ahbo.hirq		<= (others => '0');

	ahbo.haddr 		<= h.haddr;
	ahbo.htrans		<= h.htrans;
	ahbo.hprot		<= "0011";
	ahbo.hburst		<= h.hburst;
	ahbo.hbusreq	<= h.hbusreq;
	ahbo.hwrite		<= h.hwrite;
	ahbo.hwdata		<= h.hwdata;
	ahbo.hlock		<= h.hlock;
	ahbo.hsize		<= h.hsize;

	s_axi_bid 		<= x.awid;
	s_axi_rid 		<= x.arid;
	s_axi_arready 	<= x.arready;
	s_axi_awready	<= x.awready;
	s_axi_bresp 	<= "00";
	s_axi_bvalid 	<= x.bvalid;
	s_axi_rdata 	<= x.rdata;
	s_axi_rlast 	<= x.rlast;
	s_axi_rresp 	<= "00";
	s_axi_rvalid 	<= x.rvalid;
	s_axi_wready 	<= x.wready;

	--AXI synchronous--
	axi_sync: process(axi_clk)
	begin
		if rising_edge(axi_clk) then
			x <= xin;
		end if;
	end process;

	--AHB synchronous--
	ahb_sync: process(ahb_clk)
	begin
		if rising_edge(ahb_clk) then
			h <= hin;
		end if;
	end process;

end;
	
