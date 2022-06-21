-- NOEL-V processor core
  constant CFG_NOELV  	        : integer := CONFIG_NOELV;
  constant CFG_NOELV_XLEN       : integer := CONFIG_NOELV_XLEN;
  constant CFG_NCPU             : integer := CONFIG_PROC_NUM;
  constant CFG_CFG              : integer := CONFIG_PROC_TYP*256 + CONFIG_PROC_LITE*128 + CONFIG_PROC_NOFPU*2 + CONFIG_PROC_S;
  constant CFG_NODBUS           : integer := CONFIG_PROC_NODBUS;
  constant CFG_DISAS            : integer := 3*CONFIG_IU_DISAS;

