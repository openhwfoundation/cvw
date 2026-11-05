//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_prv_v_enc
//
// Rule dcsr_prv_v_enc: "H extension
// supported|v|prv|Abbreviation|Name === No|0|0|U-mode|User
// mode¶No|0|1|S-mode|Supervisor mode¶No|0|3|M-mode|Machine
// mode¶Yes|0|0|U-mode|User mode¶Yes|0|1|HS-mode|Hypervisor-enabled
// supervisor mode¶Yes|0|3|M-mode|Machine mode¶Yes|1|0|VU-
// mode|Virtual user mode¶Yes|1|1|VS-mode|Virtual supervisor mode
// ==="
//
// Halt with haltreq while the hart spins in U-mode, S-mode and
// M-mode. dcsr.v must be 0 and dcsr.prv must be 0, 1 and 3 (the
// encodings for a hart without H).
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

spin:
   addi s6, s6, 1
   j    spin

SDEXT_END
