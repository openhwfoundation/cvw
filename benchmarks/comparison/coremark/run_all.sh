#!/bin/bash
# Build CoreMark for each core's riscv-arch-test configuration and run it on the core's ACT testbench.
# usage: run_all.sh [name ...]      (default: all)    Logs: logs/<name>-<iters>.log
P=$(cd "$(dirname "$0")" && pwd); A=${ACT_CONFIGS:?set to a directory of riscv-arch-test configuration directories}; T=${CI_TOOLS:?set to the directory of riscv-arch-test core installs}; mkdir -p $P/logs
# name | ACT config | march | mabi | iterations | extra cflags | env file | run command (ELF appended)
CORES='
cv32e20|cv32e20|rv32imc_zicsr|ilp32|10||cve2.env|run-cv32e20.sh --elf
cv32e40p-imc|cv32e40p-v2-rv32imc|rv32imc_zicsr|ilp32|10|-DCLEAR_MCOUNTINHIBIT|cve4.env|run-cve4.sh --cfg rv32imc --elf
cv32e40p-imcf|cv32e40p-v2-rv32imcf|rv32imfc_zicsr|ilp32|10|-DCLEAR_MCOUNTINHIBIT|cve4.env|run-cve4.sh --cfg rv32imcf --elf
cv32e40s-imc|cv32e40s-rv32imc|rv32imc_zicsr|ilp32|10|-DCLEAR_MCOUNTINHIBIT|cve4.env|CVE40S_TB_ROOT=$T/cv32e40s-nostall CERT_MAXCYCLES=400000000 run-cv32e40s.sh --cfg rv32imc --elf
cv32e40s-imcb|cv32e40s-rv32imcb-pma-pmp|rv32imc_zicsr_zba_zbb_zbs_zbc|ilp32|10|-DCLEAR_MCOUNTINHIBIT|cve4.env|CVE40S_TB_ROOT=$T/cv32e40s-nostall CERT_MAXCYCLES=400000000 run-cv32e40s.sh --cfg rv32imcb-pma-pmp --elf
cv32e40x|cv32e40x-rv32imc|rv32imc_zicsr|ilp32|10|-DCLEAR_MCOUNTINHIBIT|cve4.env|CVE40X_DV_ROOT=$T/cv32e40x-dv-nostall CERT_MAXCYCLES=400000000 run-cv32e40x.sh --cfg rv32imc --elf
e902|e902-rv32emc-u-pmp|rv32emc_zicsr|ilp32e|10||e902.env|run-e902.sh --timeout 3000 --elf
e906|e906-rv32imafc-u-pmp|rv32imac_zicsr|ilp32|10||e906.env|run-e906.sh --timeout 3000 --elf
e906-f|e906-rv32imafc-u-pmp|rv32imafc_zicsr|ilp32|10||e906.env|run-e906.sh --timeout 3000 --elf
hazard3|hazard3-rv32imacb-u-pmp|rv32imac_zicsr_zba_zbb_zbs_zbc|ilp32|10||hazard3.env|run-hazard3.sh --cycles 400000000 --timeout 3000 --elf
ibex|ibex-opentitan|rv32imc_zicsr_zba_zbb_zbs_zbc|ilp32|10|-DIBEX_ICACHE|ibex.env|run-ibex.sh --cycles 400000000 --timeout 3000 --elf
neorv32|neorv32-rv32imacb-u-pmp|rv32imc_zicsr_zba_zbb_zbs_zbc|ilp32|10||neorv32.env|run-neorv32.sh --cycles 400000000 --timeout 3000 --elf
picorv32|picorv32-rv32imc|rv32imc_zicsr|ilp32|10|-DUSE_RDCYCLE|picorv32.env|run-picorv32.sh --max-cycles 400000000 --timeout 3000 --elf
sargantana|sargantana-rv64imafdb|rv64imafd_zicsr_zba_zbb_zbs|lp64|10||sargantana.env|run-sargantana.sh --max-cycles 400000000 --timeout 3000 --elf
serv|serv-rv32imc|rv32imc_zicsr|ilp32|2|-DMTIME_ADDR=0xC0000000|serv.env|run-serv.sh --timeout 7200 --elf
veer-eh1|veer-eh1-rv32imc|rv32imc_zicsr|ilp32|10|-DVEER_STACK_TOP=0xf0050000|veer-eh1.env|run-veer-eh1.sh --timeout 3000 --elf
veer-eh2|veer-eh2-rv32imacb|rv32imac_zicsr_zba_zbb_zbs_zbc|ilp32|10|-DVEER_STACK_TOP=0xf0050000|veer-eh2.env|run-veer-eh2.sh --timeout 3000 --elf
veer-el2|veer-el2-rv32imcb-u-pmp|rv32imc_zicsr_zba_zbb_zbs_zbc|ilp32|5|-DVEER_STACK_TOP=0xf0050000|veer-el2.env|run-veer-el2.sh --timeout 3000
cv32a65x|cv32a65x|rv32imc_zicsr_zba_zbb_zbs_zbc|ilp32|10||NONE|CVA6_SNAPSHOT=$T/cva6-snapshot-longrun $T/cva6/bin/run-cva6.sh --target cv32a65x --timeout 7200 --elf
cv32a6_imac_sv32|cv32a6_imac_sv32|rv32imac_zicsr_zba_zbb_zbs_zbc|ilp32|10||NONE|CVA6_SNAPSHOT=$T/cva6-snapshot-longrun $T/cva6/bin/run-cva6.sh --target cv32a6_imac_sv32 --timeout 7200 --elf
cv64a6_imafdc_sv39|cv64a6_imafdc_sv39|rv64imafdc_zicsr_zba_zbb_zbs_zbc|lp64|10||NONE|CVA6_SNAPSHOT=$T/cva6-snapshot-longrun $T/cva6/bin/run-cva6.sh --target cv64a6_imafdc_sv39_hpdcache --timeout 7200 --elf
rocket|rocket-saturn-rv64gcvh|rv64imafdc_zicsr_zba_zbb_zbs|lp64|10||NONE|PATH=$T/rocket/bin:$PATH run-rocket.sh --elf
boom|boom-v3-medium-rv64gc|rv64imafdc_zicsr|lp64|10||NONE|$T/boom/bin/run-boom.sh --elf
c910|c910-openc910|rv64imafdc_zicsr|lp64|10||c910.env|$T/c910-padfix/run-c910.sh --timeout 14400 --elf
xiangshan|xiangshan-kmhv2|rv64imafdc_zicsr_zba_zbb_zbs_zbc|lp64|3||xiangshan.env|XIANGSHAN_CYCLES=200000000 run-xiangshan.sh --timeout 86400 --elf
vexriscv-imac|vexriscv-imac|rv32imac_zicsr|ilp32|10||vexriscv.env|VEXRISCV_CYCLES=400000000 run-vexriscv.sh --elf
naxriscv-rv64imafdc|naxriscv-rv64imafdc|rv64imafdc_zicsr|lp64|10||naxriscv.env|NAXRISCV_CYCLES=400000000 run-naxriscv.sh --elf
shakti-eclass|shakti-eclass-rv32imac|rv32imac_zicsr|ilp32|10||shakti.env|run-shakti.sh --core eclass --timeout 3000 --elf
shakti-cclass|shakti-cclass-rv64gc|rv64imafdc_zicsr|lp64|10||shakti.env|run-shakti.sh --core cclass --timeout 3000 --elf
'
while IFS='|' read n cfg march mabi it extra env cmd; do
  [ -z "$n" ] && continue
  [ $# -gt 0 ] && [[ " $* " != *" $n "* ]] && continue
  (
    elf=$($P/../../coremark/build.sh $n $A/$cfg $march $mabi $it $extra 2>$P/logs/$n-$it.build | tail -1)
    [ "$env" != NONE ] && source $T/$env
    eval "$cmd $elf" > $P/logs/$n-$it.log 2>&1; echo "rc=$?" >> $P/logs/$n-$it.log
  ) &
done <<< "$CORES"
wait
$P/summarize.sh
