/*======================================================================*/
/* Proxy kernel linker script                                           */
/*======================================================================*/
/* This is the linker script used when building the proxy kernel. */

/*----------------------------------------------------------------------*/
/* Setup                                                                */
/*----------------------------------------------------------------------*/

/* The OUTPUT_ARCH command specifies the machine architecture where the
   argument is one of the names used in the BFD library. More
   specifically one of the entries in bfd/cpu-mips.c */

OUTPUT_ARCH( "riscv" )
ENTRY(rvtest_entry_point)

/*----------------------------------------------------------------------*/
/* Sections                                                             */
/*----------------------------------------------------------------------*/

SECTIONS
{
  . = 0x80000000;
  .tohost : { *(.tohost) }
  . = ALIGN(0x1000);

  /* text: test code section */
  .text.init : { *(.text.init) }

  .text : { *(.text) *(.text.main) }

  . = ALIGN(0x1000);
  .rodata : { *(.rodata .rodata.*) *(.srodata .srodata.*) } /* Read-only data in DMEM */
  . = ALIGN(16);

  /* data segment */
  .data : { *(.data) }
  .data.string : { *(.data.string)}

  .sdata : {
    __global_pointer$ = . + 0x800;
    *(.srodata.cst16) *(.srodata.cst8) *(.srodata.cst4) *(.srodata.cst2) *(.srodata*)
    *(.sdata .sdata.* .gnu.linkonce.s.*)
  }

  /* bss segment */
  .sbss : {
    *(.sbss .sbss.* .gnu.linkonce.sb.*)
    *(.scommon)
  }
  .bss : { *(.bss) }

  /* thread-local data segment */
  .tdata :
  {
    _tls_data = .;
    *(.tdata.begin)
    *(.tdata)
    *(.tdata.end)
  }
  .tbss :
  {
    *(.tbss)
    *(.tbss.end)
  }

  . = ALIGN(16);
  _stack_bottom = .;
  . += 0x1000;
  _stack_top = .;

  /* End of uninitialized data segment */
  _end = .;
}
