

#ifndef CONFIG_PROC_NUM
#define CONFIG_PROC_NUM 1
#endif

#if defined CONFIG_FPU_GRFPU5
#define CONFIG_FPU 1
#else
#define CONFIG_FPU 0
#endif

#if defined CONFIG_AHB_128BIT
#define CONFIG_AHBW 128
#elif defined CONFIG_AHB_64BIT
#define CONFIG_AHBW 64
#else
#define CONFIG_AHBW 32
#endif

#ifndef CONFIG_BWMASK
#define CONFIG_BWMASK 0
#endif

#ifndef CONFIG_CACHE_FIXED
#define CONFIG_CACHE_FIXED 0
#endif

