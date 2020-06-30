/******************************************************************************
 *Tests the on-chip ram and returns an error code if an error is detected.
 *Do not enable MULTIPLEERROR since it will halt the cpu unless a modified
 *traptable is used. AUTOSCRUB and ERRCNT must not be enabled unless EDACEN
 *is enabled
 ******************************************************************************/
#include "ftahbram.h"
#include "ftlib.h"
#include <stdio.h>

//Testcontrol 
#define AUTOSCRUB 1 //Autoscrubbing enabled
#define MULTIPLEERROR 0 //Do multiple error test (Requires modified traptable)

/* FTAHBRAM manual states that the core's ce output should not be connected
   to the AHBSTAT core if autoscrub is implemented. Define DOIRQTEST to 0
   if ce output is not connected, 1 if it is. */
#define DOIRQTEST 0

extern void *catch_interrupt(void func(int irq), int irq);

void irq_handler(int irq);

static volatile int irqcnt = 0;

static volatile int *regs;
static volatile int *ahbstat; 
static volatile int baddr;

int ftahbram_test(int ramaddr, int regaddr, int ahbstataddr, int irq) {
        volatile int *iram = (int *) ramaddr;
        volatile char *cram = (char *) ramaddr;
        volatile short int *sram = (short int *) ramaddr; 
        int size;
        int i;
        int j;
        int temp1;
        int temp4;
        int temp5;
        unsigned int temp6;
        int ctrl;
        int cachectrl;
        short int temp2;
        char temp3;
        int countmax; 

        report_device(0x01050000);
        
        regs = (int *) regaddr;
        ahbstat = (int *) ahbstataddr; 
        
        baddr = ramaddr;
        
        //initialization 
        *regs = (0xFF << 13);
        size = 1024 * pow2( (int)( (*regs >> 10) & 7) );

        if ((*regs & 0xFE3FF) != 0) 
                fail(1);
        
        //Disable caches
        cachectrl = cache_disable();
        
        i = 0;
        
        report_subtest(0);
        //Check various access types, one iteration without EDAC and one with.
        for (j = 0; j < 2; j++) {
                //test 128 memory locations with word accesses
                for(i = 0; i < 4; i++) {
                        *(iram + i) = i;
                }
                
                for(i = 0; i < 4; i++) {
                        if ( *(iram + i) != i ) {
                                //word has been read or written incorrectly
                                fail(2);
                        }
                }
        
                //test all memory locations with halfword accesses
                for(i = 0; i < 8; i++) {
                        *(sram + i) = i;
                }
        
                for(i = 0; i < 8 ; i++ ) {
                        if ( *(sram + i) != i ) {
                                //halfword has been read or written incorrectly
                                fail(3);
                        }
                }
        
                //test all memory locations with byte accesses
                for(i = 0; i < 16; i++) {
                        *(cram + i) = (char)i;
                }
        
                for(i = 0; i < 16 ; i++ ) {
                        if ( *(cram + i) != (char) i ) {
                                //halfword has been read or written incorrectly
                                fail(4);
                        }
                }
        
                for(i = 0; i < 4; i++) {
                        *(iram + i) = i;
                        temp1 = *(iram + i);
                        if (temp1 != i) {
                                //read after write error
                                fail(5);
                        }
                }
        
                for(i = 0; i < 8; i++) {
                        *(sram + i) = i;
                        temp2 = *(sram + i);
                        if (temp2 != i) {
                                //read after write error
                                fail(6);
                        }
                }
        
                for(i = 0; i < 16; i++) {
                        *(cram + i) = (char)i;
                        temp3 = *(cram + i);
                        if (temp3 != (char)i) {
                                //read after write error
                                fail(7);
                        }
                }
                *regs = *regs | (1 << 7);
        }

        //Single error tests

        report_subtest(1);        
        *regs = *regs | (1 << 8);

        /* //read bypass test */
        for(i = 0; i < 3; i++) {
                temp4 = 0x12345678;
                *iram = temp4;
                temp1 = *iram;
                temp1 = encode(temp4);
                ctrl = *regs;
                if( (ctrl & 0x7F) != temp1 ) {
                        //checkbit mismatch
                        fail(8);
                }
        }
        
        report_subtest(2);
        //Single error correction test 
        *regs = *regs  & ~(1 << 8);
        *regs = *regs | (1 << 9);
        temp1 = 0xdbac8754;
        temp4 = encode(temp1);
        for(i = 0; i < 4; i++) {
                *regs = *regs & ~(0x7F); 
                *regs = *regs | scramble(temp4, i, 0);
                *iram = temp1;
                temp5 = *iram;
                if(temp5 != (temp1 ^ (1 << i))) {
                        //data not corrected properly
                        fail(9);
                }
        }
        
        report_subtest(3);
        //Single error counter and interrupt tests
        temp1 = 0x9b304d24;
        temp4 = scramble(encode(temp1), 0, 0);
        *regs = *regs & ~(0x7F); 
        *regs = *regs | (0xFF << 13);
        *regs = *regs | temp4;

        *iram = temp1;
        temp5 = *iram;
        countmax = (*regs >> 13) & 0xFF;
        if (countmax != 1) {
                fail(10);
        }
        
        *regs = *regs | (0xFF << 13);
        
#if DOIRQTEST == 0
        report_subtest(4);
        //IRQ tests using AHB status register
        irqcnt = 0;
        clear_all_irq();
        
        if (ahbstataddr) {
                *ahbstat = 0;
                
                catch_interrupt(irq_handler, irq);
                enable_irq(irq);
                *iram = temp1;
                temp5 = *iram;
                while(!irqcnt) {}
                
                disable_irq(irq);
        }
        
        *iram = temp1;
        *regs = *regs & ~(1 << 9);
        *regs = *regs | (0xFF << 13);
        
        *cram = (char) 0x01;
        ctrl = *regs;
        if( ((ctrl >> 13) & 0xFF) != 1) {
                //Incorrect single error detection
                fail(13);
        }
        
        *regs = *regs;
#endif

#if MULTIPLEERROR == 1    
        //Multiple error tests
        report_subtest(5);
        *regs = *regs | (0xFF << 13) | (1 << 8);
        temp1 = 0x30a9c15b;
        temp4 = encode(temp1);
        for(i = 0; i < 88; i++) {
                *regs = *regs & ~(0xFF);
                *regs = *regs | scramble(temp4, i, 1);
                *iram = temp1;
                temp5 = *iram;
                ctrl = *regs;
                if(ctrl != 0) {
                        //Multiple error detected as single error
                        fail(15);
                }
        } 
#endif
        
        report_subtest(6);
        //Single error on checkbits test
        *regs = *regs | (1 << 9);
        temp1 = 0x1234567;
        for(i = 32; i < 34; i++) {
                temp4 = scramble(encode(temp1), i, 0);
                *regs = *regs & ~(0x7F);
                *regs = *regs | temp4;
                *iram = temp1;
                temp5 = *iram;
                ctrl = *regs;
                if(((ctrl >> 13) & 0xFF) != 1 || temp5 != temp1) {
                        //Incorrect checkbit error handling
                        fail(16);
                }
        }

        *regs = *regs & ~((1 << 9) | (1 << 8));
        *regs = *regs & ~(0xFF << 13);
        
        report_subtest(7);
        //Mixed size reads and writes
        *iram = 0xaabbccdd;
        *(cram + 2) = 0xee;
        temp1 = *iram;
        *(cram + 3) = 0xff;
        temp4 = *iram;
        *(iram + 1) = 0xffffeeee;
        *(sram + 2) = 0x1111;
        temp2 = *(sram + 2);
        *(cram + 6) = 0x22;
        temp3 = *(cram + 7);
        temp5 = (int)temp3;
        if( (temp1 != 0xaabbeedd) || (temp4 != 0xaabbeeff) || ( (temp5 & 0xff) != 0xee) ||
            (temp2 != 0x1111) ) {
                //Write error, read error 
                fail(17);
        }
        //Mixed size with single errors 
        report_subtest(8);
        temp1 = 0xaabbccdd;
        *regs = *regs & ~(0x7F);
        *regs = *regs | (1 << 9) | scramble(encode(temp1), 8, 0);
        *iram = temp1;
        *(iram + 1) = temp1;
        *(iram + 2) = temp1;
        *regs = *regs & ~(0x27F);
        *(cram + 1) = 0x22;
        temp4 = *iram;
        *(sram + 2) = 0x4455;
        temp2 = *(sram + 2);
        temp5 = *(iram + 2);
        temp3 = *(cram + 1);
        if( (temp2 != 0x4455) || (((int) temp3 & 0xFF) != 0x22) || (temp4 != 0xaa22cddd) ||
            (temp5 != 0xaabbcddd) ) {
                //Write error, read error
                fail(18);
        }

        
#if AUTOSCRUB == 1
        //test autoscrubbing
        
        report_subtest(7);        
        *regs = *regs | (0xFF << 13); /* clear error counter */
        *regs = *regs | (1 << 9); /* enable wrute bypass */

        //Single error correction test 
        temp1 = 0xdbac8754;
        temp4 = encode(temp1);
        for(i = 0; i < 4; i++) {
                *regs = *regs & ~(0x7F); 
                *regs = *regs | scramble(temp4, i, 0);
                *iram = temp1;
                temp5 = *iram;
                if(temp5 != (temp1 ^ (1 << i))) {
                        //data not corrected properly
                        fail(19);
                }
                countmax = (*regs >> 13) & 0xFF;
                if (countmax != 1) {
                        /* single error not detected*/
                        fail(20);
                }
                if(temp5 != (temp1 ^ (1 << i))) {
                        //data not corrected properly
                        fail(21);
                }
                countmax = (*regs >> 13) & 0xFF;
                if (countmax != 1) {
                        /* auto scrub did not correct word*/
                        fail(22);
                }
                *regs = *regs | (0xFF << 13); /* clear error counter */
        }
        
        *regs = *regs | (0xFF << 13);
#endif
        
        //Set caches to old state
        cache_reset(cachectrl);
        
        //no errors 
        return 0;
}

void irq_handler(int irq) {
        int ctrl;
        int temp;
        ctrl = *regs;
        if(((ctrl >> 13) & 0xFF) != 1) {
                fail(11);
        }
        *regs = *regs;
        temp = *(ahbstat + 1);
        if ( temp != baddr ) {
                //ahb stat error
                fail(12);
        } 
        *ahbstat = 0;
        irqcnt++;
}


