# Textbook Errata

This document contains errata for [RISC-V System-on-Chip Design](https://www.amazon.com/RISC-V-Microprocessor-System-Chip-Design/dp/0323994989) published by Elsevier.

Please contribute by making a pull request to modify this document on GitHub.  Sort the errata by page number. Keep the correction as succinct as possible.

| Page | Location | Error | Correction  | Contributor | Date |
| ---- | -------- | ----- | ----------- | ----------- | ----|
| 20 | 1.6 3rd paragraph | Link for Fig 1.21 takes user to section F.2.6 | fix the link to point to the figure on page 22 | Prithviraj Prasad, USA | 6/23/26 |
| 31 | Ch. 2 opening paragraph | "RISC processor sign" | Replace with "RISC processor design". | Sotaro Fujimoto, Japan | 6/17/26 |
| 33 | Table 2.1 | The source register counts for J-type and U-type instructions are listed as 1. | Change both counts to 0. | Sotaro Fujimoto, Japan | 6/22/26 |
| 46 | 2.3.1 | "The trap handler and system call validates the parameters ..." | Replace with "The trap handler for the system call validates the parameters ...". | Sotaro Fujimoto, Japan | 6/22/26 |
| 48 | Fig. 2.6(c) | The final virtual hart label is shown only as "p". | Replace with "Virtual Hart p". | Sotaro Fujimoto, Japan | 6/23/26 |
| 57 | 2.7 | The text says the adder drives `IEUAdr = PC + ImmExt` directly to the LSU and IFU. | For load/store, `IEUAdr = R1 + ImmExt` is sent to the LSU; for `beq`/`jal`, `IEUAdr = PC + ImmExt` is sent to the IFU. | Sotaro Fujimoto, Japan | 7/5/26 |
| 59 | 2.7.1.1 | `ImmExt = 0x000000004` | Change to `ImmExt = 0x00000004`. | Sotaro Fujimoto, Japan | 6/30/26 |
| 59 | 2.7.1.1 | The ALUSrc value for the lw in Cycle 1 is given as 10₂. | Change ALUSrc to 01₂. | Sotaro Fujimoto, Japan | 6/30/26 |
| 133 | 3.7 | The ACT suite has been completely redesigned and no longer uses RISCOF.  |See the [riscv-arch-test](https://github.com/riscv-non-isa/riscv-arch-test) repository for updated information.|David Harris, Claremont, CA | 1/4/26 |
| 226 | 5.9.2 | cvw-arch-verif has been deprecated and no longer is in use | Replace with riscv-arch-test | David Harris, Claremont, CA | 1/4/26 |
| 227 | 5.11 | The ACT suite has been completely redesigned and no longer uses RISCOF.  *** Other big changes pending in this section. | n/a | David Harris, Claremont, CA | 1/4/26 |
| 347 | 8.2.3.4, introduction to the register list | "Performance monitoring CSRs (see Table I.9) include the following:" | Change to "Performance monitoring registers include the following:" when adding the memory-mapped `mtime` counter to the list. | Sotaro Fujimoto, Japan | 9/9/26 |
| 347 | 8.2.3.4, first bullet | The list of "Up to 32 performance counters" omits `mtime` and lists only 31 counters. | Insert `mtime` after `mcycle/h`. | Sotaro Fujimoto, Japan | 9/9/26 |
| 347 | 8.2.3.4, sidebar | "time/h is a memory-mapped register, not a CSR." | Replace with "mtime is a 64-bit memory-mapped register, not a CSR. All other performance-monitoring registers described in this section, including the read-only counter views, are CSRs (see Table I.9)." | Sotaro Fujimoto, Japan | 9/9/26 |
| 347 | 8.2.3.4, paragraph beginning "The time register" | The sentence claims that there is no `mtime` register to which a user could write the time. | Replace the first sentence with "The time register comes from a system timer rather than a per-hart timer." | Sotaro Fujimoto, Japan | 9/9/26 |
| 348 | 8.2.3.6, first paragraph | `stimercmp` | Change all three occurrences to `stimecmp`. | Sotaro Fujimoto, Japan | 9/9/26 |
| 356 | 8.2.5.4, paragraph beginning "Timer interrupts" | "when the timer exceeds some mtimecmp compare value" | Change to "when the timer is greater than or equal to the mtimecmp compare value". | Sotaro Fujimoto, Japan | 9/9/26 |
| 367 | 8.4.1 | "Uses the CSRs (xtvect)" | Replace "xtvect" with "xtvec". | Sotaro Fujimoto, Japan | 6/19/26 |
| 388 | Fig. 9.6 | The top-left controller label is shown as "Controller1". | Replace with "Controller 1". | Sotaro Fujimoto, Japan | 7/14/26 |
| 394 | sidebar | "Fig. 20.3 shows a full-featured GPIO peripheral with an APB interface." | Replace "Fig. 20.3" with "Fig. 20.4". | Sotaro Fujimoto, Japan | 7/19/26 |
| 455 | Table 10.2, `ClearDirty` row | The flush condition is listed as `(Flush & ~LineDirty)`. | Change it to `(Flush & LineDirty)`, consistent with Section 10.4.5.4 and `cachefsm.sv`. | 王晗宇, China | 9/2/26 |
| 784.e8 | 20.2, first paragraph | "when the timer exceeds the compare value" | Change to "when the timer is greater than or equal to the compare value". | Sotaro Fujimoto, Japan | 9/9/26 |
| 784.e8 | 20.2.1, first two paragraphs | The register at `0x0200BFF8` and the memory-mapped system timer are called `time`. | Change both occurrences of `time` to `mtime`. | Sotaro Fujimoto, Japan | 9/9/26 |
| 784.e8 | 20.2.1, final paragraph | "Recall from Section 8.2.3 that a hart can read (but not write) the read-only time memory-mapped register from the CLINT." | Replace with "Recall from Section 8.2.3 that a hart can read (but not write) the time CSR, which reflects the memory-mapped mtime register in the CLINT." | Sotaro Fujimoto, Japan | 9/9/26 |
| 784.e9 | Example 20.2, register addresses | `0x20000000`, `0x20004000`, and `0x2000BFF8` do not match the stated CLINT base address `0x02000000`. | Change to `0x02000000`, `0x02004000`, and `0x0200BFF8`, respectively. | Sotaro Fujimoto, Japan | 9/9/26 |
| 784.e9 | Example 20.2, solution text | "delay() causes the timer interrupt to rise after the specified number of ticks." | Change to "delay() waits until the specified number of timer ticks has elapsed." The code polls `mtime` without writing `mtimecmp`. | Sotaro Fujimoto, Japan | 9/9/26 |
| 784.e10 | Fig. 20.7 | The timer interrupt output is labeled `MTimeInt`. | Change to `MTimerInt`, consistent with Fig. 20.6 and `clint_apb.sv`. | Sotaro Fujimoto, Japan | 9/9/26 |
| 784.e10 | 20.2.3, second paragraph | "circuity" | Change to "circuitry". | Sotaro Fujimoto, Japan | 9/9/26 |
| 885   | 23.2.2.4-5 | The ramspeed benchmark is no longer supported and has been removed from the Buildroot Linux image. | n/a | David Harris, Claremont, CA | 1/4/26 |
