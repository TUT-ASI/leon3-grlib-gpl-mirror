
struct ftmctrl {
    volatile int memcfg1;
    volatile int memcfg2;
    volatile int memcfg3;
    volatile int memcfg4;
};


#define RAMEDAC_EN_BIT 9
#define RSEDAC_EN_BIT 28

extern ftinsdata(int data, int cb, int *addr);

