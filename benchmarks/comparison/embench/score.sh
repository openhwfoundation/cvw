#!/bin/bash
# Embench speed score per MHz: geometric mean over benchmarks of baseline_ms / (cycles / 1000).
# The score is Embench 1.0's, over its 19 benchmarks; the submodule keeps their 1.0 baselines.
# "all" scores every benchmark in the checkout's speed.json, including the submodule's md5sum, primecount, and tarfind.
P=$(cd "$(dirname "$0")" && pwd); E=${EMBENCH:-$WALLY/addins/embench-iot}
for n in "$@"; do python3 - "$P/logs/$n" "$E/baseline-data/speed.json" "$n" <<'PY'
import sys, os, json, math, re
d, base, n = sys.argv[1], json.load(open(sys.argv[2])), sys.argv[3]
V10 = ('aha-mont64 crc32 cubic edn huffbench matmult-int minver nbody nettle-aes nettle-sha256 nsichneu '
       'picojpeg qrduino sglib-combined slre st statemate ud wikisort').split()
def score(benches):
    scores, bad = {}, []
    for b in benches:
        f = os.path.join(d, b + '.log')
        t = open(f, errors='replace').read() if os.path.exists(f) else ''
        c = re.search(r'EMBENCH_CYCLES (\d+)', t); ok = 'EMBENCH_CORRECT 1' in t
        if c and ok and int(c.group(1)) > 0: scores[b] = base[b] / (int(c.group(1)) / 1000)
        else: bad.append(b)
    g = math.exp(sum(map(math.log, scores.values())) / len(scores)) if scores else 0
    return f"{g:.3f} over {len(scores)}/{len(benches)}" + (f" (missing/failed: {' '.join(bad)})" if bad else '')
out = f"{n:16s}"
if all(b in base for b in V10): out += f" embench-1.0={score(V10)} "
print(out + f" all={score(sorted(base))}")
PY
done
