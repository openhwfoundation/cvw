//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_pelp_exists
//
// Rule dcsr_pelp_exists: "This bit is part of ((Zicfilp)) and only
// exists when that extension is implemented."
//
// Wally does not implement Zicfilp, so dcsr.pelp (bit 18) does not
// exist and must read 0. Write dcsr with pelp=1 (and prv=M,
// ebreakm=1) and read it back: bit 18 must be 0.
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
