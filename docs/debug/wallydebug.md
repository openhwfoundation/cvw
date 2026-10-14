# Wally Debug Feature List

Wally currently implements a **minimal RISC-V Debug Specification–compliant debug module**, focused on **abstract register access**. When the debugger is engaged, the core **halts the pipeline** and services **abstract commands** issued by the debug module. These commands allow an external debugger to safely inspect and modify architectural state without software assistance.

At present, Wally supports **abstract read and write access** to:

### General-Purpose and Floating-Point Registers
- All **GPRs (x0–x31)**
- All **FPRs (f0–f31)**

### Supported CSRs (currently implemented and readable)
- `mstatus`
- `misa`
- `mtvec`
- `mepc`
- `mtval`
- `dcsr`
- `dpc`
- `dscratch0`

All of the above registers are accessible through the **abstract command interface** and are configured to support **read operations** (and write where architecturally meaningful).

This constitutes Wally’s current **“Minimal Debug Spec” implementation**: abstract access to **GPRs, FPRs, and a core subset of CSRs** sufficient for basic halt, inspection, and low-level bring-up.

Wally’s debug module halts the processor pipeline and services abstract commands, enabling external debuggers to read and write GPRs, FPRs, and a growing set of CSRs. This provides a clean, stable foundation for full RISC-V Debug Specification support.

:-: means we currently have no intention of implementing this feature.
[x] denotes an item that is currently completed.
🔶 means we intend to implement this in the future at some point but it is not immediately imperative.

Anything else is intended to be implemented and will be implemented as soon as possible.  

General Overview of Implemented Features:
- [x] Halting and Resuming
- [x] Abstract GPR read and write access.
- [x] Abstract CSR read and write access.
- [x] Stepping
- [x] Resetting from Debug Module
- [x] Halt on Reset
- [ ] Trigger Modules 🔶
- [ ] Program buffer 🔶
- [ ] System bus access 🔶

DTM Registers
- [x] idcode
- [x] dtmcs
- [x] dmi

Debug Module
- [x] DMControl
  - [x] haltreq
  - [x] resumereq
  - [ ] hartreset
  - [x] ackhavereset
  - [ ] ackunavail :-:
    - I can't imagine there's a scenario where the only hart that exists wouldn't be available, but I need to investigate further, just in case.
  - [ ] hasel :-:
    - By hardcoding this to `0` as well as the hardcoding `hartsello` and `hartselhi` to 0 indicates to the debugger that there is only one hart. If Wally becomes multicore, this will need to be expanded so that we can select many harts. For now, it's not important to implement.
  - [ ] hartsello :-:
  - [ ] hartselhi :-:
  - [ ] setkeepalive
  - [ ] clrkeepalive
  - [x] setresethaltreq
  - [x] clrresethaltreq
  - [x] ndmreset
  - [x] dmactive. Note: Partially implemented. It needs to actually block writes to other debug module registers when set low.
- [x] DMStatus
  - [x] ndmresetpending
  - [ ] stickyunavail 🔶
  - [ ] impebreak 🔶
  - [x] allhavereset
  - [x] anyhavereset
  - [x] allresumeack
  - [x] anyresumeack
  - [ ] allnonexistent
  - [ ] anynonexistent
  - [ ] allunavail :-:
  - [ ] anyunavail :-:
  - [x] allrunning
  - [x] anyrunning
  - [x] allhalted
  - [x] anyhalted
  - [ ] authenticated 🔶
  - [ ] authbusy 🔶
  - [x] hasresethaltreq
  - [ ] confstrptrvalid :-:
  - [x] version
- [x] Command
- [x] AbstractCS
  - [x] progbufsize 🔶
  - [ ] busy
    - For clarification, abstract access are near immediate currently, so there are no busy cycles. This is subject to change.
  - [ ] relaxedpriv 🔶
  - [x] cmderr
  - [x] datacount
- [x] Data0
- [x] Data1 (`if XLEN == 64`)
- [ ] HartInfo
- [ ] Hart Array Window Select
- [ ] Hart

Debug Extension
- [x] DCSR
  - [x] Halting
  - [x] Resuming
  - [x] Version field
  - [x] Halt cause updating
  - [x] Stepping
  - [x] Stepie 🔶
    - This is for enabling interrupts during stepping. Not as important as implementing stepping itself for now.
  - [x] Ebreak to Debug mode in all modes
  - [x] Stop counters 🔶
  - [ ] Stop time 🔶
  - [ ] extcause :-:
    - Can just be set to 0 for not being implemented and also stays 0 even if cetrig is implemented which is partly what it's needed for. All other values are reserved for future version of the RISCV debug spec.
  - [ ] nmip 🔶
  - [x] prv
  - [ ] mprven
  - [ ] v 🔶  
- [x] DPC
  - [x] Grabs PC + 4 on Halt
  - [x] Resumes at DPC value on Resume

- [ ] Sdtrig 🔶
