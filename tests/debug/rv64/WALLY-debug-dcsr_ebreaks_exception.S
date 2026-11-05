//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_ebreaks_exception
//
// Rule dcsr_ebreaks_exception: "ebreak instructions in S-mode behave
// as described in the Privileged Spec."
//
// Resume in S-mode at an ebreak with dcsr.ebreaks=0 (the other
// ebreak bits set). The ebreak must raise a breakpoint exception:
// the handler records mcause=3, mepc = the ebreak, and mstatus.MPP =
// S; the hart then loops in S-mode until the debugger halts it.
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
