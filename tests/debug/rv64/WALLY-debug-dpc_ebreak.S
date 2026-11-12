//////////////////////////////////////////////////////////////////////
// WALLY-debug-dpc_ebreak
//
// Rule dpc_ebreak: "Address of the ebreak instruction"
//
// Halt on ebreak instructions (dcsr.ebreakm=1) and check that dpc =
// the ebreak's address: a 4-byte ebreak, a 2-byte c.ebreak, and an
// ebreak in the last word of a 64-byte line whose next line is not
// yet cached.
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe32:
   ebreak
.option push
.option rvc
probe16:
   c.ebreak
.option pop
.balign 64
line_start:
   .fill 15, 4, 0x00000013   // nops
probe_eol:
   ebreak

SDEXT_END
