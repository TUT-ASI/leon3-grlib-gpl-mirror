/*======================================================================*/
/* Proxy kernel linker script                                           */
/*======================================================================*/
/* This is the linker script used when building the proxy kernel. */

/*----------------------------------------------------------------------*/
/* Setup                                                                */
/*----------------------------------------------------------------------*/

/* The OUTPUT_ARCH command specifies the machine architecture where the
   argument is one of the names used in the BFD library. More
   specifically one of the entires in bfd/cpu-mips.c */

OUTPUT_ARCH( "riscv" )
ENTRY(_start)

/*----------------------------------------------------------------------*/
/* Sections                                                             */
/*----------------------------------------------------------------------*/

SECTIONS
{

  /* text: test code section */
  . = 0x40000000;
  .text.init : { 
    *(.text.init)
    . = ALIGN(0x10);
   }

  . = ALIGN(0x1000);
  .tohost : { *(.tohost) }

  .text : { 
    *(.text);
    *(.text.startup);
    . = ALIGN(0x10);
   }

  /* data segment */
  .data : { 
    *(.data)
    . = ALIGN(0x10);
   }

   .data.string : { *(.data.string)}
  .bss : { *(.bss) }

  /* End of uninitalized data segement */
  _end = .;
}

