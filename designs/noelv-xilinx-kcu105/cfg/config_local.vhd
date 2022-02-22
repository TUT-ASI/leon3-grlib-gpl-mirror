library techmap;
use techmap.gencomp.all;

library grlib;
use grlib.amba.AHBDW;

use work.config.all;

package config_local is
-- NOEL-V processor core
  constant CFG_LOCAL_NOELV        : integer := CFG_NOELV;
  constant CFG_LOCAL_NCPU         : integer := CFG_NCPU;
  constant CFG_LOCAL_CFG          : integer := CFG_CFG;
  constant CFG_LOCAL_NODBUS       : integer := CFG_NODBUS;
  constant CFG_LOCAL_DISAS        : integer := CFG_DISAS;
  constant CFG_LOCAL_ETH_IPL      : integer := CFG_ETH_IPL;
  constant CFG_LOCAL_ETH_ENL      : integer := CFG_ETH_ENL;
  constant CFG_LOCAL_ETH_GMII     : integer := 1;
  constant CFG_LOCAL_WBMASK       : integer := 16#50FF#; 
  constant CFG_LOCAL_CMEMCONF     : integer := 0; 
  constant CFG_LOCAL_FPUCONF      : integer := 0; 
  constant CFG_LOCAL_RFCONF       : integer := 0; 
  constant CFG_LOCAL_TCMCONF      : integer := 0; 
  constant CFG_LOCAL_MULCONF      : integer := 0;
  constant CFG_LOCAL_JTAG_NSYNC   : integer := 1; 
  constant CFG_LOCAL_JTAG_AINST   : integer := 2; 
  constant CFG_LOCAL_JTAG_DINST   : integer := 3; 
  constant CFG_LOCAL_JTAG_VERSEL  : integer := 1; 
  constant CFG_LOCAL_L2C_BBWIDTH  : integer := AHBDW; 
end;
