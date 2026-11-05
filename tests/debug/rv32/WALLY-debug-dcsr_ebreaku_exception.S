//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_ebreaku_exception
//
// Rule dcsr_ebreaku_exception: "ebreak instructions in U-mode behave
// as described in the Privileged Spec."
//
// Resume in U-mode at an ebreak with dcsr.ebreaku=0 (the other
// ebreak bits set). The ebreak must raise a breakpoint exception:
// the handler records mcause=3, mepc = the ebreak, and mstatus.MPP =
// U; the hart then loops in U-mode until the debugger halts it.
//////////////////////////////////////////////////////////////////////
#include "../include/sdext.h"
SDEXT_START

probe:
   ebreak
   mv   s2, s9            // mcause recorded by trap_handler
   mv   s3, s11           // traps taken
done:
   j    done

SDEXT_END
