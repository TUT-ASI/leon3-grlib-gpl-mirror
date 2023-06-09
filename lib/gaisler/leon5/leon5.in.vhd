--LEON5 processor system
  constant CFG_NCPU     : integer := CONFIG_PROC_NUM;
  constant CFG_FPUTYPE  : integer := CONFIG_FPU;
  constant CFG_PERFCFG  : integer := CONFIG_LEON5_PERFCFG;
  constant CFG_RFCONF   : integer := CONFIG_LEON5_RFCFG + CONFIG_LEON5_RF_FTCFG;
  constant CFG_CMEMCONF : integer := CONFIG_LEON5_CMCFG_TAG + CONFIG_LEON5_CMCFG_DATA + CONFIG_LEON5_CACHE_FTCFG;
  constant CFG_AHBW     : integer := CONFIG_AHBW;
  constant CFG_BWMASK   : integer := 16#CONFIG_BWMASK#;
  constant CFG_DFIXED   : integer := 16#CONFIG_CACHE_FIXED#;

