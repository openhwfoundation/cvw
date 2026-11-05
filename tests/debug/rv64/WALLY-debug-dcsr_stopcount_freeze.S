//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_stopcount_freeze
//
// Rule dcsr_stopcount_freeze: "Don't increment any hart-local
// counters while in Debug Mode or on ebreak instructions that cause
// entry into Debug Mode. These counters include the instret CSR."
//
// With dcsr.stopcount=1 (Wally implements it), read minstret, halt
// on an ebreak, wait in Debug Mode, resume after the ebreak, and
// read minstret again. Only the first csrr may be counted: the
// halting ebreak and Debug Mode add nothing, so the difference is 1.
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe:
   csrr s6, minstret
   ebreak
after:
   csrr a0, minstret
   sub  a0, a0, s6
   ebreak

SDEXT_END
