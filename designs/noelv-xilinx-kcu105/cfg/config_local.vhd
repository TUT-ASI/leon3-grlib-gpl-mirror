library techmap;
use techmap.gencomp.all;

use work.config.all;

package config_local is
-- NOEL-V processor core
  constant CFG_LOCAL_NOELV    : integer := CFG_NOELV;
  constant CFG_LOCAL_NCPU     : integer := CFG_NCPU;
  constant CFG_LOCAL_CFG      : integer := CFG_CFG;
  constant CFG_LOCAL_NODBUS   : integer := CFG_NODBUS;
  constant CFG_LOCAL_DISAS    : integer := CFG_DISAS;
  constant CFG_LOCAL_ETH_IPL  : integer := CFG_ETH_IPL;
  constant CFG_LOCAL_ETH_ENL  : integer := CFG_ETH_ENL;
end;
