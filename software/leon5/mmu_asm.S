#include "leon3.h"
#include "testmod.h" 
#include "mmu.h"

#ifndef RAMSTART
#define RAMSTART 0x40000000
#endif	
 
	.seg	"text"
	.proc	0
	.align PAGE_SIZE_MAX
	.global mmu_func1
mmu_func1:
	save  %sp, -112, %sp
	ret 
 	restore 

	.align 4
	.global mmu_double
mmu_double:
        set     1<<14, %g1
1:      lda    [%g0] 2,%g2
        andcc   %g2, %g1, %g0
        bne     1b
        nop
	ldstub [%fp-8], %g2 	! locked acess with page fault
	save  %sp, -112, %sp
	save  %sp, -112, %sp
	save  %sp, -112, %sp
	save  %sp, -112, %sp
	save  %sp, -112, %sp
	save  %sp, -112, %sp
	set 0x11111111,%l0
	set 0x22222222,%l1
	set 0x33333333,%l2
	set 0x44444444,%l3
	set 0x55555555,%l4
	set 0x66666666,%l5
	set 0x77777777,%l6
	set 0x88888888,%l7
	set 0x40000000,%g0
	std %l0,[%fp-32]
	std %l2,[%fp-24]
	std %l4,[%fp-16]
	std %l6,[%fp-8]
	mov %fp,%g1
	sub %g1,32-4,%g1
	sta %g0, [%g1] 0xf
	sub %g1,8,%g1
	sta %g0, [%g1] 0xf
	sub %g1,8,%g1
	sta %g0, [%g1] 0xf
	sub %g1,8,%g1
	sta %g0, [%g1] 0xf
	
	sta %g0, [%g0] 0x11
	save  %sp, -112, %sp
	save  %sp, -112, %sp
	restore
	restore
	nop
	nop
	ldd [%fp-32],%l0
	ldd [%fp-24],%l2
	ldd [%fp-16],%l4
	ldd [%fp-8],%l6
	ldstub [%fp-8], %l6
	swap [%fp-8], %l6
	nop
	nop
	restore
	restore
	restore
	restore
	restore
	ret 
 	restore 

/* The caller returns in user mode. */
        .global         systest_enter_supervisor
systest_enter_supervisor:
        set     1, %o0
        ta      0x8F
        retl
         nop

/* The caller returns in supervisor mode. */
        .global         systest_enter_user
systest_enter_user:
        mov     %g0, %o0
        ta      0x8F
        retl
         nop

/*
 * Trap handler for chaning supervisor mode.
 *
 * IF %i0 is 0 on entry THEN
 *   set PSR.S
 * ELSE
 *   clear PSR.S
 * ENDIF
 */
        .global         systest_trap_set_supervisor
SPARC_PSR_PS = (1<<6)
systest_trap_set_supervisor:
        cmp     %i0, %g0
        beq     .Lunset
         andn   %l0, SPARC_PSR_PS, %l0
.Lset:
        or      %l0, SPARC_PSR_PS, %l0
.Lunset:
        wr      %l0, %psr
        nop
        nop
        nop
        jmp     %l2
         rett   %l2 + 4

/*
 * MMU related trap handlers
 * Register values on entry
 *
 * %l0 : %psr
 * %l1 = pc            :set by trap
 * %l2 = npc           :set by trap
 */
	.global systest_data_access_exception
	.global systest_instruction_access_exception
systest_data_access_exception:
systest_instruction_access_exception:
	mov	0x400, %l5
	mov	0x300, %l4
	lda	[%l5] ASI_M_MMUREGS, %l6	! read sfar first
	lda	[%l4] ASI_M_MMUREGS, %l5	! read sfsr last

	set	pth_addr,%l7			! repair pth
	ld    [%l7],%l7
	ld	[%l7],%l4
	ld	[%l7+4],%l5
	ld 	[%l7+8],%l6
	or    %l6,0x0,%l6				! one page
	sta   %g0, [%l6] ASI_M_FLUSH_PROBE

	st	%l5,[%l4]
	inc   12,%l7
	set	pth_addr,%l5
	st    %l7,[%l5]
	  
	jmp	%l1				! reexecute instruction
	 rett	%l2


	.section .data
	.align 8 
	.global pth_addr, pth_addr1
pth_addr:	.word 0
	.align 8 
pth_addr1:	.word 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
		
	.align 32 
	.global srmmu_set_mmureg_aligned


	.section .text
	.align 8
srmmu_set_mmureg_aligned:
	retl
	sta %o0, [%g0] 0x19
	nop
	nop
	nop
	nop
	nop
	nop

	.global casa_test

casa_test:
	
	save  %sp, -112, %sp

	st	%fp, [%fp]
	add	%fp, 1, %o0
	mov	%fp, %o2
	casa	[%fp] 0xB, %o2, %o0
	casa	[%fp] 0xB, %o2, %o0
	add	%o2, 1, %o2
	add	%o0, 1, %o0
	casa	[%fp] 0xB, %o2, %o0
	casa	[%fp] 0xB, %o2, %o0
	ld	[%fp], %o3
	sub	%o3, %fp, %o3
	subcc	%o3, 2, %i0
	bne	8f
	add	%g0, 1, %o0
        set 51, %l0
        set 34, %l1
        st %l0, [%fp]
        casa [%fp] 0xA, %l0, %l1
        ld [%fp], %l2
        cmp %l1, 51
        bne 8f
        add %g0, 2, %o0
        cmp %l2, 34
        bne 8f
        add %g0, 3, %o0
        b 9f
         nop
8:      call	fail
	nop
9:      ret
	restore

/* MMU tables */
	.section .bss

	.align PAGE_SIZE_MAX
	.global mmu_ctx_start
mmu_ctx_start:
        .skip SRMMU_PGD_TABLE_SIZE

	.align SRMMU_PGD_TABLE_SIZE
	.global mmu_pg0_start
mmu_pg0_start:
	.skip SRMMU_PGD_TABLE_SIZE

	.align SRMMU_PMD_TABLE_SIZE
	.global mmu_pm0_start
mmu_pm0_start:
	.skip SRMMU_PMD_TABLE_SIZE

	.align SRMMU_PTE_TABLE_SIZE
	.global mmu_pt0_start
mmu_pt0_start:
	.skip SRMMU_PTE_TABLE_SIZE

	.align PAGE_SIZE_MAX
	.global mmu_page0_start
mmu_page0_start:
	.skip PAGE_SIZE_MAX

	.global mmu_page1_start
mmu_page1_start:
	.skip PAGE_SIZE_MAX

	.global mmu_page2_start
mmu_page2_start:
	.skip (3*(PAGE_SIZE))

	.global mmu_page2_end
mmu_page2_end:

