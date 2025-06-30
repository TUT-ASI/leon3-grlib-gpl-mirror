/*
 * System test software for GRGPIO core
 * 
 * Copyright (C) 2005 - 2008, Gaisler Research
 * Copyright (C) 2008 - 2013, Aeroflex Gaisler
 *
 * This file contains two test functions:
 *
 * gpio_test() is the simple traditional system test
 *
 * gpio_test_irq() also tests interrupt generation 
 *
 */

#include <bcc/bcc.h>
#include <inthelper.h>
#include <isrhelper.h>
#include "testmod.h"

volatile unsigned int *pio;

/*
 * pio[0] = din
 * pio[1] = dout
 * pio[2] = dir
 * pio[3] = imask
 * pio[4] = level
 * pio[5] = edge
 * pio[6] = bypass
 * pio[7] = reserved
 * pio[8] = irqmap
 */


int gpio_test(uintptr_t addr)
{
        unsigned int mask;
        int width;
        int capwidth;
        
        pio = (unsigned int *) addr;

	report_device(0x0101a000);
        pio[3] = 0; 
        pio[2] = 0;
        pio[1] = 0;  
  
        pio[2] = 0xFFFFFFFF;
      
        report_subtest(1);

        /* determine port width and mask */
        mask = 0;
        width = 0;
        
        while( ((pio[2] >> width) & 1) && (width < 32)) {
                mask = mask | (1 << width);
                width++;
        }
        
        pio[2] = mask;
        if( (pio[0] & mask) != 0) fail(1);  
        pio[1] = 0x89ABCDEF;
        if( (pio[0] & mask) != (0x89ABCDEF & mask)) fail(2);
        pio[2] = 0;

        capwidth = (pio[7] & 0x1f) + 1;
        if (capwidth != width) {
                /* Mismatch between probed and announced width */
                fail(3);
        }

        return width;
}

static volatile int irqtbl[32+1];

static void gpio_irqhandler(int irq)
{
        irqtbl[irqtbl[0]] = irq + 0x10;
        irqtbl[0]++;

        /* Drive no line */
        pio[2] = 0;
}


/*
 * gpio_test_ext():
 *
 * addr   - core address
 * irqgen - value of irqgen generic
 *
 * This test requires that the GPIO lines have external pull-ups
 *
 */
int gpio_test_irq_mask(uintptr_t addr, int pirq, unsigned int iomask)
{
        unsigned int cap;
        unsigned int imask;
        int irqgen;
        int width, k, i, numirq;

        report_subtest(2);

        /* Initialize interrupts */
        mask_all_interrupts();
        clear_all_interrupts();

        pio = (unsigned int *) addr;
        cap = pio[7];
        width = (cap & 0x1f) + 1;
        irqgen = (cap >> 8) & 0x1f;
        if (cap & (1U<<16)) {
                imask = pio[16];
        } else {
                pio[3] = 0xffffffffu;
                imask = pio[3];
                pio[3] = 0;
        }

        /* Set up interrupt handler */
        if (irqgen == 0) {
                /* Fixed mapping IO[i] = interrupt pirq + i */
                for (i=pirq ? 1 : 0; i <width; i++) {
                        if ((iomask & (1 << i)) == 0) continue;
                        if ((pirq+i) < 32) {
                                catch_interrupt(gpio_irqhandler, pirq+i);
                                /* Enable interrupt */
                                bcc_int_unmask(pirq+i);
                        }
                }
        } else if (irqgen == 1) {
                /* One shared interrupt pirq */
                catch_interrupt(gpio_irqhandler, pirq);
                /* Enable interrupt */
                bcc_int_unmask(pirq);

        } else {
                /* Core can map lines to irqgen interrupt lines */
                for (i=0; i < irqgen; i++) {
                        if ((pirq+i) < 32) {
                                catch_interrupt(gpio_irqhandler, pirq+i);
                                /* Enable interrupt */
                                bcc_int_unmask(pirq+i);
                        }
                }
        }

        pio[1] = 0; /* Prepare to drive all lines low */
        pio[4] = 0;  /* Interrupt level = low */
        pio[5] = -1; /* Edge */
        pio[3] = (-1) & iomask; /* Enable all interrupts */

        /* Iterate once for irqgen = 0, 1 and irqgen times for other values */
        for (k = 0; k < (irqgen ? irqgen : 1); k++) {

                /* Possibly remap interrupts */
                for (i = 0; (irqgen > 1) && (i < ((width+3)/4)); i++) {
                        pio[8+i] = (k << 24) | (k << 16) | (k << 8) | k;
                }

                /* Initialize interrupt counting */
                irqtbl[0] = 1;
                numirq = 0;

                /* Assert interrupts */
                for (i = (irqgen != 0 || pirq != 0) ? 0 : 1; i < width; i++) {

                        if ((iomask & (1 << i)) == 0) continue;

                        /* Drive line i low */
                        pio[2] = (1 << i);
                
                        /* 
                         * Wait for interrupt, or skip to next if interrupt is masked. 
                         * Test may lock here if imask is wrong or core/connection is 
                         * bad.
                         */
                        while((imask & (1 << i)) && pio[2]);
                }
                pio[2] = 0;

        
                /* Check interrupts */
                for (i = (irqgen != 0 || pirq != 0) ? 0 : 1; i < width; i++) {
                        /* Skip lines that cannot generate irqs */
                        if ((iomask & (1 << i)) == 0) continue;
                        if ((imask & (1 << i)) == 0)
                                continue;
                        numirq++;
                
                        /* 
                         * With irqgen = 0 the interrupt asserted should equal the
                         * io line plus pirq offset. For the other modes, pirq+k should
                         * have been asserted
                         */
                        if (((irqgen == 0) && (irqtbl[numirq] != (pirq+i+0x10))) ||
                            ((irqgen != 0) && (irqtbl[numirq] != (pirq+k+0x10))))
                                fail(4+i+32*k);                
                }
                /*
                 *  The number of expected interrupts in all cases is the same as
                 *  the number of I/O lines with interrupt generation capabilities
                 */
                if ((irqtbl[0] - numirq) != 1) fail(3);
        }
        pio[3] = 0; /* Mask all interrupts on GRGPIO */

        mask_all_interrupts();
        clear_all_interrupts();

        return 0;
}

int gpio_test_irq(uintptr_t addr, int pirq)
{
  return gpio_test_irq_mask(addr,pirq,0xffffffffu);
}
