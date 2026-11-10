# CORE-V Wally Design Verification Test Plan

CORE-V Wally is functionally tested in the following ways.  Each test is run in lock-step against ImperasDV to ensure all architectural state is correct after each instruction.

| Tests               | Section        | TRL3         | TRL5   | Coverage Method       | Status | Command |
| ------------------- | -------------- | ------------ | ------ | --------------------- | ------ | ------- |
| Verilator Lint      | 5.3            | All configs  | rv64gc | lint-wally            | PASS   | regression-wally --nightly |
| Instructions        | 3.7            | All configs  | rv64gc | riscv-arch-test       | PASS   | regression-wally --nightly |
| Privileged          | 3.7            | All configs  | rv64gc | riscv-arch-test priv  | PASS   | regression-wally --nightly |
| Floating-point      | 5.11.7, 16.5.3 | rv{32/64}gc + derived | rv64gc    | TestFloat | PASS   | regression-wally --nightly |
| CoreMark            | 21.1           | Many configs | rv64gc | CoreMark              | PASS       | regression-wally --nightly |
| Embench             | 21.2           | rv32*        | n/a    | Embench               | PASS       | regression-wally --nightly |
| Cache PV            | 21.3.1         | rv{32/64}gc  | rv64gc | CacheSim                   | TBD    | TBD |
| Branch PV            | 21.3.2         | rv{32/64}gc  | rv64gc | BP simulator                   | TBD    | TBD |
| Linux Boot          | 22.3.2         | rv64gc       | rv64gc | buildroot                  | PASS    | regression-wally --nightly |
| FPGA Linux Boot     | 23.2           |              | rv64gc | Lab test                   | PASS    | TBD |
| Code Coverage       | 5.11.10        |              | rv64gc | multiple tests                   | TBD    | regression-wally --nightly |
| Functional Coverage | 5.11.11        |              | rv64gc | cvw-arch-verif                   | TBD    | regression-wally --nightly |

Functional Verification plans are in
https://drive.google.com/drive/folders/11hTR2Yl48kOMODxhwrSsC-eXYtM_rJJE?usp=sharing
