//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_ebreakvs_rdonly0_no_H
//
// Rule dcsr_ebreakvs_rdonly0_no_H: "This bit is hardwired to 0 if
// the hart does not support virtualization mode."
//
// Wally does not implement the H extension, so dcsr.ebreakvs (bit
// 17) does not exist and must read 0. Write dcsr with ebreakvs=1
// (and prv=M, ebreakm=1) and read it back: bit 17 must be 0.
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
