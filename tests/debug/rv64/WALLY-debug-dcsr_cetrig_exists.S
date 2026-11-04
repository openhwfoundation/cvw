//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_cetrig_exists
//
// Rule dcsr_cetrig_exists: "This bit is part of ((Smdbltrp)) and
// only exists when that extension is implemented."
//
// Wally does not implement Smdbltrp, so dcsr.cetrig (bit 19) does
// not exist and must read 0. Write dcsr with cetrig=1 (and prv=M,
// ebreakm=1) and read it back: bit 19 must be 0.
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe:
   addi s2, s2, 1
probe_ebreak:
   ebreak
   addi s3, s3, 1
   ebreak

SDEXT_END
