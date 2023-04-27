
        .global wcomb_test_main

wcomb_test_main:
        save %sp, -96, %sp
        ! Init buffer using 32-bit stores to avoid write combining
        ! Note bufptr[len] also written here to check for over-bursting
        ! so buffer must have 8 bytes more space than specified length
        set 0x55555555, %l0
        mov %i0, %l1
        set 0, %l2
1:      st %l0, [%l1]
        st %l0, [%l1+4]
        add %l2, 1, %l2
        cmp %l2, %i1
        ble 1b
        add %l1, 8, %l1
        ! Setup data to write
        set 1, %l7
        set 2, %l6
        set 3, %l5
        set 4, %l4
        set 5, %l3
        set 6, %l2
        set 7, %l1
        set 8, %l0
        set 9, %o5
        set 10, %o4
        set 11, %o3
        set 12, %o2
        set 13, %o1
        set 14, %o0
        set 15, %i5
        set 16, %i4
        ! Adjust buffer pointer to point to end of buffer
        sll %i1, 3, %i1 ! i1 = ndwords * 8 = nbytes
        add %i0, %i1, %i2
        ! Calculate where in std sequence below to jump in
        set 1f, %i3
        srl %i1, 1, %i1 ! i1 = ndwords * 4
        sub %i3, %i1, %i3
        ! Do the jump
        jmp %i3
        nop
        std %i4, [%i2-64]
        std %o0, [%i2-56]
        std %o2, [%i2-48]
        std %o4, [%i2-40]
        std %l0, [%i2-32]
        std %l2, [%i2-24]
        std %l4, [%i2-16]
        std %l6, [%i2-8]
1:
        ! Now do some loads with forced cache miss to pull the data back into
        ! cache from the AHB bus
        lda [%i0] 1, %g0
        add %i0, 32, %i2
        lda [%i2] 1, %g0
        ! Check output values
        srl %i1, 1, %i1 ! i1 = ndwords * 2 = nwords
3:      ld [%i0], %i2
        cmp %i2, %i1
        bne,a 2f
        mov 1, %i0
        subcc %i1, 1, %i1
        bnz 3b
        add %i0, 4, %i0
        ! Check that nothing was written past buffer end
        ld [%i0], %i2
        set 0x55555555, %l0
        cmp %i2, %l0
        bne,a 2f
        mov 1, %i0
        mov 0, %i0
2:      ret
        restore
