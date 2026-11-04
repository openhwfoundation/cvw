//////////////////////////////////////////////////////////////////////
// WALLY-debug-dcsr_ebreakm_exception
//
// Rule dcsr_ebreakm_exception: "ebreak instructions in M-mode behave
// as described in the Privileged Spec."
//
// Resume in M-mode at an ebreak with dcsr.ebreakm=0 (the other
// ebreak bits set). The ebreak must raise a breakpoint exception:
// the handler records mcause=3, mepc = the ebreak, and mstatus.MPP =
// M; the hart then loops in M-mode until the debugger halts it.
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
