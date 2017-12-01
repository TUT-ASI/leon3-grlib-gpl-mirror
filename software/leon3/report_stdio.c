#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "report.h"
#include "grcommon.h"

enum {
        REPORT_DEBUG = 0
};
#define DBG(...) if (REPORT_DEBUG) { \
        printf("%s:%d: ", __func__, __LINE__); \
        printf(__VA_ARGS__); \
}

static const char *dev_to_string(unsigned int dev);
static const char *subtest_to_string(unsigned int dev, int subtest);

static unsigned int curdev = 0;

int report_start(void)
{
        /* Only CPU allowed here. */
        if (get_pid()) {
                return 0;
        }

        puts("");
        puts("**** GRLIB system test starting ****");
        return(0);
}

int report_end(void)
{
        puts("**** GRLIB system test end ****");
        return(0);
}

int report_device(unsigned int dev)
{
        DBG("dev=0x%08x\n", dev);
        const char *desc;

        curdev = dev;
        desc = dev_to_string(dev);
        puts(desc);
        return 1;
}

int report_subtest(int subtest)
{
        DBG("subtest=%d\n", subtest);
        const char *desc;

        desc = subtest_to_string(curdev, subtest);
        printf("  %s\n", desc);
        return 0;
}

void report_mem_test(void)
{
        DBG("entry\n");
        puts("Basic memory test");
}

int fail(int id)
{
        DBG("id=%d\n", id);
        printf("    test failed at %d\n", id);
        exit(1);
        return(0);
}

/* Reference: lib/gaisler/sim/sim.vhd */
static const char *dev_to_string(unsigned int dev)
{
        switch (dev >> 24) {
        case 1:
                switch ((dev >> 12) & 0x0fff) {
                case GAISLER_LEON3:
                        return ("LEON3 SPARC V8 Processor");
                case GAISLER_ETHMAC:
                        return ("GR Ethernet MAC");
                case GAISLER_PCIFBRG:
                        return ("Fast 32-bit PCI Bridge");
                case GAISLER_LEON3FT:
                        return ("LEON3FT V8 Processor");
                case GAISLER_GPTIMER:
                        return ("Modular Timer Unit");
                case GAISLER_IRQMP:
                        return ("Multi-processor Interrupt Ctrl.");
                case GAISLER_APBUART:
                        return ("Generic UART");
                case GAISLER_CANAHB:
                        return ("OC CAN AHB interface");
                case GAISLER_GRGPIO:
                        return ("General Purpose I/O port");
                case GAISLER_FTMCTRL:
                        return ("PROM/SRAM/SDRAM Memory controller with EDAC");
                case GAISLER_FTAHBRAM:
                        return ("Generic FT AHB SRAM module");
                case GAISLER_FTSRCTRL:
                        return ("Simple FT SRAM Controller");
                case GAISLER_SPW:
                        return ("SpaceWire Serial Link");
                case GAISLER_SPICTRL:
                        return ("SPI controller");
                case GAISLER_I2CMST:
                        return ("I2C master");
                default:
                        return ("Unknown device");
                }
                break;
        case 4:
                switch ((dev >> 12) & 0x0fff) {
                case ESA_LEON2:
                        return ("Leon2 SPARC V8 Processor");
                case ESA_MCTRL:
                        return ("Leon2 Memory Controller");
                case ESA_L2IRQ:
                        return ("Leon2 Interrupt Controller");
                default:
                        return ("Unknown device");
                }
                break;
        default:
                return ("Unknown vendor");
        }
}

static const char *subtest_to_string(unsigned int dev, int test)
{
        static char buf[24];
        switch (dev >> 24) {
        case VENDOR_GAISLER:
                switch ((dev >> 12) & 0x0fff) {
                case GAISLER_LEON3:
                case GAISLER_LEON3FT:
                case ESA_LEON2:
                        switch (test) {
                        case 3:
                                return ("register file");
                        case 4:
                                return ("multiplier");
                        case 5:
                                return ("radix-2 divider");
                        case 6:
                                return ("cache system");
                        case 7:
                                return ("multi-processing");
                        case 8:
                                return ("floating-point unit");
                        case 9:
                                return ("itag cache ram");
                        case 10:
                                return ("dtag cache ram");
                        case 11:
                                return ("idata cache ram");
                        case 12:
                                return ("ddata cache ram");
                        case 13:
                                return ("GRFPU test");
                        case 14:
                                return ("memory management unit");
                        }
                case GAISLER_GPTIMER:
                        switch (test) {
                        case 0:
                                return ("timer 1");
                        case 1:
                                return ("timer 2");
                        case 2:
                                return ("timer 3");
                        case 3:
                                return ("timer 4");
                        case 4:
                                return ("timer 5");
                        case 5:
                                return ("timer 6");
                        case 6:
                                return ("timer 7");
                        case 8:
                                return ("chain mode");
                        }
                case GAISLER_GRGPIO:
                        switch (test) {
                        case 1:
                                return ("IN, OUT and DIR registers");
                        case 2:
                                return ("Interrupt generation");
                        }
                }
        }
        /* Create a generic string if no match default */
        snprintf(&buf[0], sizeof(buf)/sizeof(buf[0]), "sub-system test %-4d", test);
        return &buf[0];
}

