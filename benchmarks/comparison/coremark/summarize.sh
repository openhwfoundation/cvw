#!/bin/bash
# Summarize CoreMark logs: CoreMark/MHz = Iterations * 1e6 / Total ticks (mcycle)
P=$(cd "$(dirname "$0")" && pwd)
for f in $P/logs/*.log; do
  t=$(grep -m1 "Total ticks" $f | awk '{print $NF}'); i=$(grep -m1 "^Iterations " $f | awk '{print $NF}')
  ok=$(grep -c "Correct operation validated" $f)
  cm=""; [ -n "$t" ] && [ "$t" != 0 ] && cm=$(python3 -c "print(f'{$i*1e6/$t:.3f}')")
  printf "%-22s ticks=%-10s iters=%-3s valid=%s CM/MHz=%-6s %s\n" $(basename $f .log) "$t" "$i" "$ok" "$cm" "$(tail -1 $f | cut -c1-60)"
done
