OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS
{
  . = 0x40000000;
  .text.init : { 
    *(.text.init)
    . = ALIGN(0x10);
   }
  . = ALIGN(0x1000);
  .tohost : { 
    *(.tohost)
    . = ALIGN(0x10);
   }
  . = ALIGN(0x1000);
  .text : { 
    *(.text)
    . = ALIGN(0x10);
   }
  . = ALIGN(0x1000);
  .data : { 
    *(.data)
    . = ALIGN(0x10);
   }
  .bss : { 
    *(.bss)
    . = ALIGN(0x10);
   }
  _end = .;
}
