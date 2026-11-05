//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_v_rdonly0_no_H
//
// Rule dcsr_v_rdonly0_no_H: "This bit is hardwired to 0 on harts
// that do not support virtualization mode."
//
// Wally does not implement the H extension, so dcsr.v (bit 5) does
// not exist and must read 0. Write dcsr with v=1 (and prv=M,
// ebreakm=1) and read it back: bit 5 must be 0.
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
