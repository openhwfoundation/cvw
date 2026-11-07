#!/bin/bash
# Build and run Embench (speed) for each core's riscv-arch-test configuration on its ACT testbench.
# usage: run_all.sh <core> ...   Logs: logs/<core>/<bench>.log
P=$(cd "$(dirname "$0")" && pwd); A=${ACT_CONFIGS:?set to a directory of riscv-arch-test configuration directories}; T=${CI_TOOLS:?set to the directory of riscv-arch-test core installs}; C=$T
E=${EMBENCH:-$WALLY/addins/embench-iot}
BENCHES=$(ls $E/src)
# name | ACT config | march | mabi | extra cflags | env setup | run command (ELF appended)
CORES='
cv32e20|cv32e20|rv32imc_zicsr|ilp32||source '$T'/cve2.env|run-cv32e20.sh --elf
cv32e40p-imc|cv32e40p-v2-rv32imc|rv32imc_zicsr|ilp32|-DCLEAR_MCOUNTINHIBIT|source '$T'/cve4.env|run-cve4.sh --cfg rv32imc --elf
cv32e40p-imcf|cv32e40p-v2-rv32imcf|rv32imc_zicsr|ilp32|-DCLEAR_MCOUNTINHIBIT|source '$T'/cve4.env|run-cve4.sh --cfg rv32imcf --elf
cv32e40s-imc|cv32e40s-rv32imc|rv32imc_zicsr|ilp32|-DCLEAR_MCOUNTINHIBIT|source '$T'/cve4.env; export CVE40S_TB_ROOT='$C'/cv32e40s-nostall CERT_MAXCYCLES=400000000|run-cv32e40s.sh --cfg rv32imc --elf
cv32e40s-imcb|cv32e40s-rv32imcb-pma-pmp|rv32imc_zicsr_zba_zbb_zbs_zbc|ilp32|-DCLEAR_MCOUNTINHIBIT|source '$T'/cve4.env; export CVE40S_TB_ROOT='$C'/cv32e40s-nostall CERT_MAXCYCLES=400000000|run-cv32e40s.sh --cfg rv32imcb-pma-pmp --elf
cv32e40x|cv32e40x-rv32imc|rv32imc_zicsr|ilp32|-DCLEAR_MCOUNTINHIBIT|source '$T'/cve4.env; export CVE40X_DV_ROOT='$C'/cv32e40x-dv-nostall CERT_MAXCYCLES=400000000|run-cv32e40x.sh --cfg rv32imc --elf
hazard3|hazard3-rv32imacb-u-pmp|rv32imac_zicsr_zba_zbb_zbs_zbc|ilp32||source '$T'/hazard3.env|run-hazard3.sh --cycles 400000000 --timeout 7200 --elf
ibex|ibex-opentitan|rv32imc_zicsr_zba_zbb_zbs_zbc|ilp32|-DIBEX_ICACHE|source '$T'/ibex.env|run-ibex.sh --cycles 400000000 --timeout 7200 --elf
picorv32|picorv32-rv32imc|rv32imc_zicsr|ilp32|-DUSE_RDCYCLE|source '$T'/picorv32.env|run-picorv32.sh --max-cycles 1000000000 --timeout 7200 --elf
sargantana|sargantana-rv64imafdb|rv64im_zicsr_zba_zbb_zbs|lp64||source '$T'/sargantana.env|run-sargantana.sh --max-cycles 400000000 --timeout 7200 --elf
serv|serv-rv32imc|rv32imc_zicsr|ilp32|-DMTIME_ADDR=0xC0000000|source '$T'/serv.env|run-serv.sh --timeout 14400 --sim-timeout 200000000000 --elf
veer-eh1|veer-eh1-rv32imc|rv32imc_zicsr|ilp32|-DVEER_STACK_TOP=0xf0050000|source '$T'/veer-eh1.env; export VEER_SNAPSHOT='$C'/veer-eh1-longrun|run-veer-eh1.sh --timeout 7200 --elf
veer-eh2|veer-eh2-rv32imacb|rv32imac_zicsr_zba_zbb_zbs_zbc|ilp32|-DVEER_STACK_TOP=0xf0050000|source '$T'/veer-eh2.env|run-veer-eh2.sh --timeout 7200 --elf
veer-el2|veer-el2-rv32imcb-u-pmp|rv32imc_zicsr_zba_zbb_zbs_zbc|ilp32|-DVEER_STACK_TOP=0xf0050000|source '$T'/veer-el2.env; export VEER_SNAPSHOT='$C'/veer-el2-longrun|run-veer-el2.sh --timeout 7200
cv32a65x|cv32a65x|rv32imc_zicsr_zba_zbb_zbs_zbc|ilp32||export CVA6_SNAPSHOT='$C'/cva6-snapshot-longrun PATH='$C'/cva6/bin:$PATH|run-cva6.sh --target cv32a65x --timeout 14400 --elf
cv32a6_imac_sv32|cv32a6_imac_sv32|rv32imac_zicsr_zba_zbb_zbs_zbc|ilp32||export CVA6_SNAPSHOT='$C'/cva6-snapshot-longrun PATH='$C'/cva6/bin:$PATH|run-cva6.sh --target cv32a6_imac_sv32 --timeout 14400 --elf
cv64a6_imafdc_sv39|cv64a6_imafdc_sv39|rv64imac_zicsr_zba_zbb_zbs_zbc|lp64||export CVA6_SNAPSHOT='$C'/cva6-snapshot-longrun PATH='$C'/cva6/bin:$PATH|run-cva6.sh --target cv64a6_imafdc_sv39_hpdcache --timeout 14400 --elf
neorv32|neorv32-rv32imacb-u-pmp|rv32imc_zicsr_zba_zbb_zbs_zbc|ilp32||source '$T'/neorv32.env|run-neorv32.sh --cycles 1000000000 --timeout 7200 --elf
e902|e902-rv32emc-u-pmp|rv32emc_zicsr|ilp32e||source '$T'/e902.env; export E902_SNAPSHOT='$C'/e902-longrun/opene902/smart_run/work|run-e902.sh --timeout 7200 --elf
e906|e906-rv32imafc-u-pmp|rv32imac_zicsr|ilp32||source '$T'/e906.env|run-e906.sh --timeout 7200 --elf
vexriscv|vexriscv-imac|rv32imac_zicsr|ilp32||source '$T'/vexriscv.env; export VEXRISCV_CYCLES=1000000000|run-vexriscv.sh --elf
naxriscv|naxriscv-rv64imafdc|rv64imac_zicsr|lp64||source '$T'/naxriscv.env; export NAXRISCV_CYCLES=1000000000|run-naxriscv.sh --elf
rocket|rocket-saturn-rv64gcvh|rv64imac_zicsr_zba_zbb_zbs|lp64||export PATH='$T'/rocket/bin:$PATH|run-rocket.sh --elf
shakti-eclass|shakti-eclass-rv32imac|rv32imac_zicsr|ilp32||source '$T'/shakti.env|run-shakti.sh --core eclass --timeout 14400 --elf
shakti-cclass|shakti-cclass-rv64gc|rv64imac_zicsr|lp64||source '$T'/shakti.env|run-shakti.sh --core cclass --timeout 14400 --elf
boom|boom-v3-medium-rv64gc|rv64imac_zicsr|lp64||true|'$T'/boom/bin/run-boom.sh --elf
c910|c910-openc910|rv64imac_zicsr|lp64||source '$T'/c910.env|'$T'/c910-padfix/run-c910.sh --timeout 86400 --elf
xiangshan|xiangshan-kmhv2|rv64imac_zicsr_zba_zbb_zbs_zbc|lp64||source '$T'/xiangshan.env; export XIANGSHAN_CYCLES=400000000|run-xiangshan.sh --timeout 172800 --elf
cvw-rv32imc|cvw-rv32imc|rv32imc_zicsr|ilp32||cd $WALLY; source ./setup.sh >/dev/null 2>&1|wsim --sim verilator rv32imc --elf
cvw-rv64gc|cvw-rv64gc|rv64imac_zicsr_zba_zbb_zbs_zbc|lp64||cd $WALLY; source ./setup.sh >/dev/null 2>&1|wsim --sim verilator rv64gc --elf
'
jobs=$P/jobs.txt; : > $jobs
while IFS='|' read n cfg march mabi extra envs cmd; do
  [ -z "$n" ] && continue
  [[ " $* " != *" $n "* ]] && continue
  mkdir -p $P/logs/$n
  for b in $BENCHES; do
    elf=$($P/build.sh $n $A/$cfg $march $mabi $b $extra 2>$P/logs/$n/$b.build | tail -1)
    [ -f "$elf" ] || { echo "$n $b BUILD FAILED"; continue; }
    echo "$envs; $cmd $elf > $P/logs/$n/$b.log 2>&1; echo rc=\$? >> $P/logs/$n/$b.log" >> $jobs
  done
done <<< "$CORES"
# slowest simulators first
sort -t' ' -k1,1 $jobs | awk '/rocket|serv|cvw-rv64gc/{print; next} {rest[NR]=$0} END{for (i in rest) print rest[i]}' > $jobs.sorted
tr '\n' '\0' < $jobs.sorted | xargs -0 -P ${JOBS:-24} -I{} bash -c '{}'
$P/score.sh "$@"
