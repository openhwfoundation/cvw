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
| 367 | 8.4.1 | "Uses the CSRs (xtvect)" | Replace "xtvect" with "xtvec". | Sotaro Fujimoto, Japan | 6/19/26 |
| 388 | Fig. 9.6 | The top-left controller label is shown as "Controller1". | Replace with "Controller 1". | Sotaro Fujimoto, Japan | 7/14/26 |
| 394 | sidebar | "Fig. 20.3 shows a full-featured GPIO peripheral with an APB interface." | Replace "Fig. 20.3" with "Fig. 20.4". | Sotaro Fujimoto, Japan | 7/19/26 |
| 885   | 23.2.2.4-5 | The ramspeed benchmark is no longer supported and has been removed from the Buildroot Linux image. | n/a | David Harris, Claremont, CA | 1/4/26 |
