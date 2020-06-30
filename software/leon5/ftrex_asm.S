
#include "rexmacros.h"

        .text
        .global ftrex_testproc,ftrex_test

        .align 32
        .fill 24
ftrex_testproc:
        REX_FUNCSTART_LEAF
        R_SET32(0x12345678, R4o0)
        R_RETL
        REX_FUNCEND

ftrex_test:
        /* Loop over each byte in function (0..11) */
        /*   Run test func once to guarantee it's in cache */
        /*   Disable Icache */
        /*   Locate function cache line */
        /*   Inject bit error */
        /*   Re-enable Icache */
        /*   Run test func */
        /*   Check Icache error counter */
        save %sp, -96, %sp
        /* Check for FT and REX, enable REX if not enabled */
        /* Will fail if FT/REX are not present in HW */
        lda [%g0] 2, %l3 /* %l3 == Cache ctrl register value */
        set (3 << 19), %i0
        andcc %l3, %i0, %g0
        be,a 1f /* branch to return if no FT present */
         or %g0, 8, %i0
        mov %asr17, %i0
        set (3 << 23), %i1
        andcc %i0, %i1, %g0
        be,a 1f /* branch to return if no REX present */
         or %g0, 9, %i0
        set (3 << 21), %i1
        andn %i0, %i1, %i0
        mov %i0, %asr17 /* Enable REX */
        /* Init vars used in loop */
        set ftrex_testproc, %l0 /* %l0 == errinj address */
        set 0, %l1 /* %l1 == Loop counter */
        set 0x12345678, %l2 /* %l2 == Exp value form test func */
        set 8, %l4
        lda [%l4] 2, %l5
        srl %l5, 20, %l5
        and %l5, 15, %l5
        set 1024, %l4
        sll %l4, %l5, %l4 /* %l4 == way size in bytes */
        sub %l4, 1, %l5 /* %l5 == way mask (waysize-1) */
        /* Loop start
        /*   Run test func once to guarantee it's in cache */
3:      call ftrex_testproc
         mov %g0, %o0
        cmp %o0,%l2
        bne,a 1f
         or %g0, 1, %i0
#if 0
        /*   Disable Icache */
        and %l3, ~3, %l3
        sta %l3, [%g0] 2
#endif
        /* Locate function cache line */
        and %l0, %l5, %l6
        andn %l6, 3, %l6
2:      lda [%l6] 0xC, %l7 /* Icache tag diag ASI */
        andcc %l7, 0xFF, %g0
        be,a 2b /* No valid bit set, check next way */
         add %l6, %l4, %l6
        /* Check tag */
        xor %l7, %l0, %l7
        andncc %l7, %l5, %l7
        bne,a 2b /* Tag mismatch, check next */
         add %l6, %l4, %l6
        /* Inject error */
        lda [%l6] 0xD, %l7 /* l7 = Diag load data */
        and %l0, 3, %i0    /* l6 = byte to inject error in */
        set (1<<27), %i1
        srl %i1, %i0, %i1  /* i1 = bit to set in TB field in CCR */
        or  %l3, %i1, %i2
        sta %i2, [%g0] 2         /* - Enable err injection in parity bit */
        sll %i0, 3, %i0
        set 0x01000000, %i1
        srl %i1, %i0, %i1 /* i1 = bit to xor in data */
        xor %l7, %i1, %l7
        sta %l7, [%l6] 0xD   /* - Diag write data */
#if 0
        /* Re-enable Icache */
        or %l3, 3, %l3
        sta %l3, [%g0] 2
#endif
        /* NOPs to make sure diag write propagates before Icache fetch */
        nop
        nop
        nop
        nop
        nop
        /* Call test proc */
        call ftrex_testproc
         mov %g0, %o0
        cmp %o0,%l2
        bne 1f
         or %g0, 2, %i0
        /* Check Icache error counter */
        lda [%g0] 2, %l3 /* Cache ctrl register value */
        andcc %l3, (3<<10), %g0
        be,a 1f
         or %g0, 3, %i0
        andn %l3, (3<<10), %l3 /* Clear ITE and TB  */
        sta %l3, [%g0] 2
        /* Next loop iteration */
        add %l1, 1, %l1
        subcc %l1, 12, %g0
        bne 3b
         add %l0, 1, %l0
4:      ret
         restore
1:      call fail  /* tail recursion to fail proc (arg in %i0) */
         restore
