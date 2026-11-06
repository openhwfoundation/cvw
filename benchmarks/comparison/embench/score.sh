#!/bin/bash
# Embench speed score per MHz: geometric mean over benchmarks of baseline_ms / (cycles / 1000)
P=$(cd "$(dirname "$0")" && pwd); E=${EMBENCH:-$WALLY/addins/embench-iot}
for n in "$@"; do python3 - "$P/logs/$n" "$E/baseline-data/speed.json" "$n" <<'PY'
import sys, os, json, math, re
d, base, n = sys.argv[1], json.load(open(sys.argv[2])), sys.argv[3]
scores, bad = {}, []
for b in sorted(base):
    f = os.path.join(d, b + '.log')
    t = open(f, errors='replace').read() if os.path.exists(f) else ''
    c = re.search(r'EMBENCH_CYCLES (\d+)', t); ok = 'EMBENCH_CORRECT 1' in t
    if c and ok and int(c.group(1)) > 0: scores[b] = base[b] / (int(c.group(1)) / 1000)
    else: bad.append(b)
g = math.exp(sum(map(math.log, scores.values())) / len(scores)) if scores else 0
print(f"{n:16s} embench={g:.3f} over {len(scores)}/{len(base)}" + (f"  missing/failed: {' '.join(bad)}" if bad else ''))
PY
done
