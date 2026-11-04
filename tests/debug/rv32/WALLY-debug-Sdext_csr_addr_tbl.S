//////////////////////////////////////////////////////////////////////
// WALLY-debug-Sdext_csr_addr_tbl
//
// Rule Sdext_csr_addr_tbl: "Address|Name|Section === 0x7b0|Debug
// Control and Status (dcsr)|¶0x7b1|Debug PC (dpc)|¶0x7b2|Debug
// Scratch Register 0 (dscratch0)|¶0x7b3|Debug Scratch Register 1
// (dscratch1)| ==="
//
// Halt on an ebreak, then read CSR 0x7b0 (dcsr: debugver, cause=1,
// prv=3) and 0x7b1 (dpc = address of the ebreak) with abstract
// commands.
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
