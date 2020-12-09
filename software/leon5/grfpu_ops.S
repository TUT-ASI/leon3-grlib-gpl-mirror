/**********************************************************************/
/*  This file is a part of the GRFPU IP core testbench                */
/*  Copyright (C) 2004-2008  Gaisler Research AB                      */
/*  Copyright (C) 2008-2009  Aeroflex Gaisler AB                      */
/*  ALL RIGHTS RESERVED                                               */
/*                                                                    */
/**********************************************************************/

/* #include leon */
	
	
!  %i0  : operand 1
!  %i1  : operand 1
!  %i2  : result
!  %o0  : 0 - OK, 1 - error	 	

	.text
	.align 4	
	.global grfpu_fdivs, grfpu_fdivd, grfpu_sqrtd, grfpu_ttrap
	.global divident, divromtst
	.global grfpu_faddd
	.global grfpu_fmuld
	.global grfpu_fsmuld
	.global grfpu_fstoi, grfpu_fdtoi, grfpu_fitos, grfpu_fitod
	.global grfpu_fstod, grfpu_fdtos
	.global grfpu_fnegs, grfpu_fmovs, grfpu_fabss
	.global grfpu_fcmpd, grfpu_fcmped, grfpu_fcmps, grfpu_fcmpes
	.global grfpu_fsubd, grfpu_fadds, grfpu_fsubs, grfpu_fmuls
	.global	grfpu_fdivs, grfpu_fsqrts, initfpreg
	.global grfpc_dpdep_tst, grfpc_spdep_tst, grfpc_spdep_tst2
	.global grfpc_spdpdep_tst
	.global get_tbr, fptrap
	.global test_pl1
        .global fpu5_trapcycle_setup, fpu5_trapcycle, fpu5_multidfq

	
test_pl1:
	mov	%o0, %o4
	set	0x40080000, %o0
	mov	0x00000000, %o1
	set	0x3fddb3d7, %o2	
	std 	%o0, [%o4]
	st	%o2, [%o4+8]
	ldd	[%o4], %f0
	ld	[%o4+8], %f2	
	fmuls   %f2, %f2, %f3
	/* Nop needed, otherwise both fmuls gets reordered ahead of
	 * fsqrtd */
	nop 
	fsqrtd  %f0, %f4
	fmuls   %f2, %f2, %f6
	fcmps   %f3, %f6
	nop
	fbe,a   comp_eq
	mov     0, %o0
	mov	1, %o0
comp_eq:
	retl
	nop

	
grfpu_faddd:
	ldd	[%o0], %f0
	ldd	[%o1], %f2
	faddd	%f0, %f2, %f4
	retl		
	std	%f4, [%o2]


grfpu_fmuld:
	ldd	[%o0], %f0
	ldd	[%o1], %f2
	fmuld	%f0, %f2, %f4
	retl
	std	%f4, [%o2]		

grfpu_fsmuld:
	st	%o0, [%o3]
	st	%o1, [%o3+4]
	ld	[%o3], %f0
	ld	[%o3+4], %f1
	fsmuld  %f0, %f1, %f2
	retl
	std	%f2, [%o2]
	
grfpu_fdivd:	
	ldd  [%o0], %f0
	ldd  [%o1], %f2
	fdivd %f0, %f2, %f4		
	std  %f4, [%o2]		
	retl 
	nop

grfpu_sqrtd:	
	ldd [%o0], %f0	
	fsqrtd %f0, %f2
	std %f2, [%o1]
	retl
	nop

grfpu_ttrap:	
        nop; nop; nop; nop; nop; nop; nop; nop;
        nop; nop; nop; nop; nop; nop; nop; nop;
        nop; nop; nop; nop; nop; nop; nop; nop;
        nop; nop; nop; nop; nop; nop; nop; nop;
        fmovs %f0, %f0
	retl
	nop
		
divident:	
	ldd  [%o0], %f0		
	retl
	nop					

divromtst:	
	ldd	[%o0], %f2
	fdivd	%f0, %f2, %f4
	std	%f4, [%o1]		
	retl
	nop
			
	
grfpu_fitod:
	st	%o0, [%o1]
	ld	[%o1], %f0
	fitod	%f0, %f2
	std	%f2, [%o1]
	retl
	ldd	[%o1], %o0

grfpu_fitos:
	st	%o0, [%o1]
	ld	[%o1], %f0
	fitos	%f0, %f2
	st	%f2, [%o1]
	retl
	ld	[%o1], %o0	

grfpu_fdtoi:	
	std	%o0, [%o2]
	ldd	[%o2], %f0
	fdtoi	%f0, %f2
	st	%f2, [%o2]
	retl	
	ld	[%o2], %o0
			
grfpu_fstoi:	
	st	%o0, [%o1]
	ld	[%o1], %f0
	fstoi	%f0, %f2
	st	%f2, [%o1]
	retl	
	ld	[%o1], %o0

grfpu_fstod:	
	st	%o0, [%o1]
	ld	[%o1], %f0
	fstod	%f0, %f0
	std	%f0, [%o1]
	retl
	ldd	[%o1], %o0				

grfpu_fdtos:	
	std	%o0, [%o2]
	ldd	[%o2], %f0
	fdtos	%f0, %f0
	st	%f0, [%o2]
	retl
	ld	[%o2], %o0							

grfpu_fmovs:
	st	%o0, [%o1]
	ld	[%o1], %f5
	fmovs	%f5, %f6
	st	%f6, [%o1]
	retl
	ld	[%o1], %o0			


grfpu_fnegs:
	st	%o0, [%o1]
	ld	[%o1], %f5
	fnegs	%f5, %f6
	st	%f6, [%o1]
	retl
	ld	[%o1], %o0

grfpu_fabss:
	st	%o0, [%o1]
	ld	[%o1], %f5
	fabss	%f5, %f6
	st	%f6, [%o1]
	retl
	ld	[%o1], %o0				

grfpu_fcmpd:	
	std	%o0, [%o4]
	std	%o2, [%o4+8]
	ldd	[%o4], %f0
	ldd	[%o4+8], %f2
	fcmpd	%f0, %f2
	nop
	fbe,a	cmpd_end
	mov	0, %o0
	fbl,a	cmpd_end
	mov	1, %o0
	fbg,a	cmpd_end
	mov	2, %o0
	fbu,a	cmpd_end
	mov	3, %o0
	ta	0x0	!error
cmpd_end:
	retl
	nop


grfpu_fcmped:	
	std	%o0, [%o4]
	std	%o2, [%o4+8]
	ldd	[%o4], %f0
	ldd	[%o4+8], %f2
	fcmped	%f0, %f2
	nop
	fbe,a	cmpd_end
	mov	0, %o0
	fbl,a	cmpd_end
	mov	1, %o0
	fbg,a	cmpd_end
	mov	2, %o0
	fbu,a	cmpd_end
	mov	3, %o0
	ta	0x0	!error
							

grfpu_fcmps:	
	st	%o0, [%o2]
	st	%o1, [%o2+8]
	ld	[%o2], %f0
	ld	[%o2+8], %f1
	fcmps	%f0, %f1
	nop
	fbe,a	cmpd_end
	mov	0, %o0
	fbl,a	cmpd_end
	mov	1, %o0
	fbg,a	cmpd_end
	mov	2, %o0
	fbu,a	cmpd_end
	mov	3, %o0
	ta	0x0	!error

grfpu_fcmpes:	
	st	%o0, [%o2]
	st	%o1, [%o2+8]
	ld	[%o2], %f0
	ld	[%o2+8], %f1
	fcmpes	%f0, %f1
	nop
	fbe,a	cmpd_end
	mov	0, %o0
	fbl,a	cmpd_end
	mov	1, %o0
	fbg,a	cmpd_end
	mov	2, %o0
	fbu,a	cmpd_end
	mov	3, %o0
	ta	0x0	!error	
	
grfpu_fsubd:	
	std	%o0, [%o4]
	std	%o2, [%o4+8]
	ldd	[%o4], %f0
	ldd	[%o4+8], %f2
	fsubd	%f0, %f2, %f4
	std	%f4, [%o4]
	retl
	ldd	[%o4], %o0
	
grfpu_fadds:	
	st	%o0, [%o2]
	st	%o1, [%o2+8]
	ld	[%o2], %f0
	ld	[%o2+8], %f1
	fadds	%f0, %f1, %f2
	st	%f2, [%o2]
	retl
	ld	[%o2], %o0
	
grfpu_fsubs:	
	st	%o0, [%o2]
	st	%o1, [%o2+8]
	ld	[%o2], %f0
	ld	[%o2+8], %f1
	fsubs	%f0, %f1, %f2
	st	%f2, [%o2]
	retl
	ld	[%o2], %o0

grfpu_fmuls:	
	st	%o0, [%o2]
	st	%o1, [%o2+8]
	ld	[%o2], %f0
	ld	[%o2+8], %f1
	fmuls	%f0, %f1, %f2
	st	%f2, [%o2]
	retl
	ld	[%o2], %o0			

grfpu_fdivs:	
	st	%o0, [%o2]
	st	%o1, [%o2+8]
	ld	[%o2], %f0
	ld	[%o2+8], %f1
	fdivs	%f0, %f1, %f2
	st	%f2, [%o2]
	retl
	ld	[%o2], %o0

grfpu_fsqrts:	
	st	%o0, [%o1]
	ld	[%o1], %f0
	fsqrts	%f0, %f1
	st	%f1, [%o1]
	retl
	ld	[%o1], %o0				

grfpc_dpdep_tst:	
	set	dpbuf, %o1
	ldd	[%o1+8], %f2
	ldd	[%o1], %f0
	faddd	%f0, %f0, %f4	! 1 + 1 = 2
	fsubd	%f4, %f2, %f8	! 2 - 3 = -1	
	fdivd	%f8, %f4, %f10  ! -1 / 2 = -0.5
	fmuld	%f10, %f2, %f10 ! -0.5 * 3 = -1.5         
        retl
	std	%f10, [%o0]

grfpc_spdep_tst:
	set	spbuf, %o1
	ld	[%o1], %f0
	ld	[%o1+4], %f1
	fadds	%f0, %f0, %f2	! 1 + 1 = 2
	fsubs	%f2, %f1, %f3   ! 2 - 3 = -1
	fdivs	%f3, %f2, %f4	! -1 / 2 = -0.5
	fmuls	%f4, %f1, %f4	! -0.5 * 3 = -1.5
	retl
        st      %f4, [%o0]

grfpc_spdep_tst2:
	set     2, %o3
	set	dpbuf, %o1
        set     dpbuf, %o2
grfpc_spdep_tst2_loop:     
	ld	[%o1], %f10
	ld	[%o2], %f11
	st      %f10, [%o0]
	ld      [%o0], %o4
	set	spbuf, %o1       ! change buffer for second run
	subcc   %o3, 1, %o3
	bne     grfpc_spdep_tst2_loop
	nop
	retl
	nop

grfpc_spdpdep_tst:
	set	dpbuf, %o1
	set	spbuf, %o2
	ld	[%o2], %f0
	ldd	[%o1+16], %f2			
	fadds	%f0, %f0, %f1	! 1 + 1 = 2
	fsubd	%f2, %f0, %f4	! 
	fdivs	%f4, %f1, %f5	! 
	fmuld	%f4, %f2, %f6	! 
        fmuls   %f5, %f6, %f7
        fsqrtd  %f6, %f8
	retl
        std     %f8, [%o0]

initfpreg:
        set zbuf, %o0
	ldd [%o0], %f0
	ldd [%o0], %f2
	ldd [%o0], %f4
	ldd [%o0], %f6
	ldd [%o0], %f8
	ldd [%o0], %f10							
	ldd [%o0], %f12
	ldd [%o0], %f14							
	ldd [%o0], %f16
	ldd [%o0], %f18							
	ldd [%o0], %f20
	ldd [%o0], %f22	
	ldd [%o0], %f24	
	ldd [%o0], %f26
	ldd [%o0], %f28
	ldd [%o0], %f30			
        retl 
        nop
	
fptrap:
	set	fsr1, %l4
	mov     %asr17, %l5
        srl     %l5, 28, %l5
        sll     %l5, 2, %l5
        add     %l4, %l5, %l4
	set	tfsr, %l3
        add     %l3, %l5, %l3
	st	%fsr, [%l3]
	ld	[%l3], %l3
	srl	%l3, 14, %l0
	and	%l0, 7, %l0
	subcc	%l0, 2, %l0	! %l0 = 0 if unfFPop trap, 1 otherwise
	set	0, %l7		! %l7 = nr of instr. in FQ		
	!be	_skip
	!nop			
	set	grfpufq-8, %l6
        sll     %l5, 2, %l5
        add     %l6, %l5, %l6
1:
	add	%l7, 1, %l7		
	add	%l6, 8, %l6
	std	%fq, [%l6]	
	st	%fsr, [%l4]
	ld	[%l4], %l5
	srl	%l5, 13, %l5
	andcc	%l5, 1, %l5
	bne	1b
	nop
	!std	%fq, [%l3]
	!jmpl	%l2, %g0
	!rett	%l2 + 4
	!subcc	%l0, %g0, %g0
	!be	_skip
	!nop
	
	addcc	%g0, %l0, %g0
	be	_skip		
	set	0xf07fffff, %l5
	and	%l3, %l5, %l3
	st	%l3, [%l4]
	ld	[%l4], %fsr	 ! disable exceptions		
	set	grfpufq, %l5
        mov     %asr17, %l0
        srl     %l0, 28, %l0
        sll     %l0, 4, %l0
        add     %l5, %l0, %l5
        ld      [%l5], %l5
2:	dec	%l7
        jmpl    %l5+%g0, %l6
        jmpl    %l6+8, %g0
3:      subcc	%l7, %g0, %g0
	bne	2b
	add	%l5, 8, %l5
	st	%fsr, [%l4]
	ld	[%l4], %l3
	set	0x0f000000, %l5
	or	%l3, %l5, %l3
	st	%l3, [%l4]
	ld	[%l4], %fsr	! enable exceptions
	jmpl	%l1, %g0
	rett	%l2		
	nop
_skip:
	jmpl	%l2, %g0
	rett	%l2 + 4 
	nop
	nop	
	
get_tbr:	
	retl
	mov %tbr, %o0				
		
	.data
	.align 8
	.global tfsr, grfpufq
	
zbuf:	.word 0
	.word 0		

dpbuf:	.word 0x3ff00000 
        .word 0x00000000
	.word 0x40080000 
	.word 0x00000000
	.word 0x3ff00000 
	.word 0x40000000
	.word 0x0        
	.word 0x0
spbuf:	.word 0x3f800000
	.word 0x40400000
	.word 0x0
	.word 0x0

tfsr:	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
grfpufq:
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0

	.text
	.align 8
	.global fpu_pipe, fsr1, f1x, fmin1, ftest


fpu_pipe:
	set	fsr1, %o0	! check ldfsr/stfsr interlock
	ld	[%o0], %fsr
	st	%g0, [%o0]
	ld	[%o0], %fsr
	st	%fsr, [%o0]
	ld	[%o0], %o2
	set	0x000E0000, %o1
	andn	%o2, %o1, %o2
	subcc	%g0, %o2, %g0
	bne,a	8f
	mov	3, %o0

	set 0x0f800000, %o1	! check ldfsr/fpop interlock
	st	%o1, [%sp-96]
	st	%g0, [%sp-92]
	ld	[%sp-96], %fsr
	st	%g0, [%sp-96]
	set	f1x, %o2
	ld	[%o2], %f0
	nop; nop
	ld	[%sp-96], %fsr
	ld	[%sp-92], %fsr
	fsqrts	%f0, %f1
	st	%fsr, [%sp-96]
	ld	[%sp-96], %o0
	andcc	%o0, 0x200, %g0
	be,a	8f
	mov	4, %o0


	mov	0, %o0

1:
	set ftest, %o2
	ld [%o2], %f2
	ld [%o2+8], %f4
	ld [%o2+12], %f8
	set f1x, %o1
	ld [%o1], %f3
	fmuld %f2, %f4, %f6
	fcmped %f6, %f8
	nop
	fbne 3f
	nop
	set 1, %o0
	ba  8f
	nop
3:
	ld [%o2], %f2
	ld [%o2+8], %f4
	ld [%o2+12], %f8
	set f1x, %o1
	ld [%o1], %f5
	fmuld %f2, %f4, %f6
	fcmped %f6, %f8
	nop
	fbne 4f
	nop
	set 1, %o0
	ba  8f
	nop
4:
	set fmin1, %l2
	ldd [%l2], %f0
	ldd [%l2], %f2
	subcc %g0, %g0, %g0
	bne,a  5f
	fsubd %f0, %f0, %f2
	fcmped %f0, %f2
	nop
	fbe   6f
	nop
5:
	set 5, %o0
6:
	nop
	set fmin1, %l2
	ldd [%l2], %f0
	ldd [%l2], %f2
	subcc %g0, %g0, %g0
	nop
	bne,a  7f
	fsubd %f0, %f0, %f2
	fcmped %f0, %f2
	nop
	fbe   8f
	nop
7:
	set 7, %o0
8:
	nop
	retl
	nop


	.data         
	.global a1, c2
	.global b1,c1
	.align 8
a1:	.word 0x48000001
	.word 0
b1:	.word 0x48000000
	.word 0
c1:	.word 0x46c00000
	.word 0
c2:    .word 0x3ff00000
       .word 0 
       .word 0x40000000
       .word 0 
       .word 0x40080000
       .word 0 
       .word 0x3f800000

	.text         
	.align 4      
	.global fpu_chkft
	              
fpu_chkft:           
       set     1, %o0                 
       mov     %asr16, %o2            
       srl     %o2, 30, %o2           
       and     %o2, 3, %o2                  ! %o2 = fpft 
       cmp     %o2, %g0               
       beq     1f                     
       mov     0, %o0                 
       cmp     %o2, 2                 
       bge     1f                     
 	set	c2, %o1                      
	ldd	[%o1], %f0             
	ldd	[%o1 + 8], %f2         
       ld      [%o1 + 0x18], %f30           ! f30 = 1.0    
       fmovs   %f30, %f10             
       fmovs   %f30, %f12             
       fmovs   %f30, %f14             
	set	0x030078, %o3                ! 4-bit error DP ram 0 
	mov	%o3, %asr16            
	nop; nop; nop; nop; nop; nop;  
	fmovs   %f0, %f0               
	fmovs   %f1, %f1               
	fmovs   %f10, %f10             
       fmovs   %f12, %f12             
       fmovs   %f14, %f14             
	set	0x03007c, %o3                ! 4-bit error DP ram 1 
	mov	%o3, %asr16            
	nop; nop; nop; nop; nop; nop;  
       fmovs   %f2, %f2               
       fmovs   %f3, %f3               
	mov     %g0, %asr16            
	nop; nop; nop; nop; nop; nop;  
       faddd   %f0, %f2, %f4                ! should correct 4 errors 
       fadds   %f10, %f30, %f20             ! should correct 1 error  
       std     %f12, [%o1]                  ! should correct 1 error  
       st      %f14, [%o1]                  ! should correct 1 error  
       ldd     [%o1 + 0x10], %f6            ! %f6 = 2.0 (DP) 
       ld      [%o1 + 0x8], %f8             ! %f8 = 2.0 (SP) 
       fcmpd   %f4, %f6               
       nop                            
       fbne    1f                     
       fcmps    %f20, %f8             
       nop                            
       fbne    1f                     
       mov     %asr16, %o1            
       srl     %o1, 27, %o1           
       and     %o1, 7, %o1                 ! error counter 
       mov     0, %o0                 
       cmp     %o2, 1                 
       beq     1f                     
       sub     %o1, 7, %o0                 ! should be 7 for fpft = 1  
       sub     %o1, 4, %o0                 ! should be 4 for fpft = 2  
1:     retl                            
       nop                              

	.text
	.align 4
	.global set_fsr, get_fsr
get_fsr: 
	st	%fsr, [%sp-96]
	retl
	ld	[%sp-96], %o0
set_fsr: 
	st	%o0, [%sp-96]
	retl
	ld	[%sp-96], %fsr


fpu5_trapcycle_setup:
        /* Flush cache */
        flush
        /* Install jmpl,rett pair as trap handler for ftt_exception */
        mov %tbr, %o0
        andn %o0, 0xFFF, %o0
        set 0x88012001, %o1 ! inc %g4
        st %o1, [%o0+0x80]
        set 0x81c48000, %o1 ! jmp %l2
        st %o1, [%o0+0x84]
        set 0x81cca004, %o1 ! rett %l2+4
        st %o1, [%o0+0x88]
        /* Setup FSR */
        st %fsr, [%sp-96]
        ld [%sp-96], %o0
        set (0x1f << 23), %o1
        or %o0, %o1, %o0
        st %o0, [%sp-96]
        ld [%sp-96], %fsr
        set 0x3f800000, %o0
        /* Setup FP regs */
        st %o0, [%sp-96]
        ld [%sp-96], %f0
        set 0, %o0
        st %o0, [%sp-96]
        ld [%sp-96], %f1
        ld [%sp-96], %f2
        retl
        ld [%sp-96], %f3

fpu5_trapcycle:
        set 0, %g4
        /* First step - generate trap */
        andcc %o0, 1, %g0
        bne,a 1f
9:      fdivs %f0, %f1, %f2
        ! fake with ASR 0x20 if
        set 0x94, %o1
        set 0x5, %o2
        sta %o2, [%o1] 0x20
        set 0x98, %o3
        set 9b, %o2
        sta %o2, [%o3] 0x20
        set 0x9C, %o3
        ld [%o2], %o2
        sta %o2, [%o3] 0x20
        set 0x24, %o2
        sta %o2, [%o1] 0x20
1:      /* Now trap is pending, step 2 trigger trap */
        st %g0, [%sp-96]
        andcc %o0, 2, %g0
        bne,a 2f
        st %fsr, [%sp-96]
        ! fake trigger trap with ASR 0x20 if
        set 0x94, %o1
        set 7, %o2
        sta %o2, [%o1] 0x20
        inc %g4
        ! we need a nop to ensure transition from pending -> trap is
        ! seen by iu before st %fsr below is in decode stage
        nop
2:      /* Now we're in exception state */
        /* Check that trap occurred */
        subcc %g4, 1, %g0
        bne 4f
        ld [%sp-96], %o1
        cmp %o1, %g0
        bne 4f
        /* Check FSR  */
        st %fsr, [%sp-96]
        ld [%sp-96], %o1
        and %o1, 0x1f, %o2 ! cexc
        cmp %o2, 2
        bne 4f
        srl %o1, 13, %o2 ! qne
        andcc %o2, 1, %g0
        be 4f
        srl %o1, 14, %o2 ! ftt
        and %o2, 7, %o2
        cmp %o2, 1
        bne 4f
        /* Step 3 store DFQ */
        andcc %o0, 4, %g0
        bne,a 3f
        std %fq, [%sp-96]
        ! fake store DFQ using ASR 0x20
        set 0x88, %o1
        ldda [%o1] 0x20, %o2
        std %o2, [%sp-96]
        set 0x94, %o1
        set 0x40, %o2
        sta %o2, [%o1] 0x20
3:      /* Check DFQ entry */
        ldd [%sp-96], %o2
        set 9b, %o1
        cmp %o1, %o2
        bne 4f
        ld  [%o2], %o2
        cmp %o2, %o3
        bne 4f
        /* Check FSR */
        st %fsr, [%sp-96]
        ld [%sp-96], %o1
        srl %o1, 13, %o2 ! qne
        andcc %o2, 1, %g0
        bne 4f
        srl %o1, 14, %o2 ! ftt
        and %o2, 7, %o2
        cmp %o2, 0
        bne 4f
        nop
        retl
        set 0, %o0
4:      retl
        set 1, %o0

fpu5_multidfq:
        save %sp, -96, %sp
        set 0x94, %l0 ! (ASI 0x20) FSR/DFQ mod register
        set 0x98, %l1 ! (ASI 0x20) New DFQ entry register
        set 0x88, %l2 ! (ASI 0x20) DFQ entry readout register
        set 0x80, %l6 ! (ASI 0x20) FSR shadow copy
        ! Set grfpu5 to trap pending state
        set 0x5, %l3
        sta %l3, [%l0] 0x20
        ! load in DFQ entries (# of entries in i0)
        mov %i0, %l3
        set 3, %l4
        set 7, %l5
        set 0x24, %o0
1:      stda %l4, [%l1] 0x20
        sta %o0, [%l0] 0x20
        subcc %l3, 1, %l3
        add %l4, 3, %l4
        bne 1b
        add %l5, 7, %l5
        ! trigger trap using fpop or via debug if (depends on i1 bit 0)
        set 0, %g4
        st %g0, [%sp]
        andcc %i1, 1, %g0
        bne,a 2f
        st %fsr, [%sp-96] ! trigger trap with stfsr
        ! fake trigger trap with ASR 0x20 if
        set 7, %l3
        sta %l3, [%l0] 0x20
        inc %g4
        ! we need a nop to ensure transition from pending -> trap is
        ! seen by iu before st %fsr below is in decode stage
        nop
2:      /* Now we're in exception state */
        /* Check that trap occurred */
        subcc %g4, 1, %g0
        bne 9f
        ld [%sp], %l3
        cmp %l3, %g0
        bne 9f
        /* Check FSR  */
        st %fsr, [%sp]
        ld [%sp], %l3
        and %l3, 0x1f, %l4 ! cexc
        cmp %l4, 2
        bne 9f
        srl %l3, 13, %l4 ! qne
        andcc %l4, 1, %g0
        be 9f
        srl %l3, 14, %l4 ! ftt
        and %l4, 7, %l4
        cmp %l4, 1
        bne 9f
        ! read DFQ entries using stdfq or debug if (depends on i1 bit 1)
        andcc %i1, 2, %g0
        bne 4f
        set 8, %l3
        ! use debug i/f
3:      ldda [%l2] 0x20, %l4
        std %l4, [%sp+%l3]
        set 0x40, %l4
        sta %l4, [%l0] 0x20
        lda [%l6] 0x20, %l4
        srl %l4, 13, %l4
        andcc %l4, 1, %g0
        bne 3b
        add %l3, 8, %l3
        b,a 5f
4:      ! use stdfq
        std %fq, [%sp+%l3]
        st %fsr, [%sp]
        ld [%sp], %l4
        srl %l4, 13, %l4
        andcc %l4, 1, %g0
        bne 4b
        add %l3, 8, %l3
5:      ! done reading out DFQ entries
        ! check end pointer
        sub %l3, 8, %l3
        srl %l3, 3, %l3
        subcc %l3, %i0, %g0
        bne 9f
        ! verify DFQ entries
        set 3, %l4
        set 7, %l5
        set 8, %l3
        mov %i0, %l7
6:      ldd [%sp+%l3], %o2
        cmp %o2, %l4
        bne 9f
        cmp %o3, %l5
        bne 9f
        add %l4, 3, %l4
        add %l5, 7, %l5
        subcc %l7, 1, %l7
        bne 6b
        add %l3, 8, %l3
        ! success
        set 0, %i0
        ret
        restore
9:      ! failure
        set 1, %i0
        ret
        restore
