
#ifndef LEON5_MEMMAP
#define LEON5_MEMMAP 0
#endif

base_test5()
{
        if (!get_pid()) mem_test();
#if LEON5_MEMMAP == 0
        leon5_test(1, 0x80000200, 0);
        irqtest(0x80000200);
        gptimer_test(0x80000300, 8);
        apbuart_test(0x80000100);
#else
        leon5_test(1, 0xff904000, 0);
        irqtest(0xff904000);
        gptimer_test(0xff908000, 8);
        apbuart_test(0xff900000);
#endif
}

