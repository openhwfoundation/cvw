//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_cause_priority_tbl
//
// Rule dcsr_cause_priority_tbl: "cause encoding|Cause ===
// 5|resethaltreq¶6|halt group¶3|haltreq¶2|trigger (See for detailed
// priority)¶1|ebreak¶4|step ==="
//
// Step (dcsr.step=1) over an ebreak with ebreakm=1. Both step and
// ebreak cause Debug Mode entry; ebreak has higher priority, so
// dcsr.cause = 1 and dpc = the ebreak.
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
