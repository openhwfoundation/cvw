#!/usr/bin/env -S uv run --script
# embench_arch_sweep.py
# David_Harris@hmc.edu 16 November 2023
# james.stine@okstate.edu 14 November 2025
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

import collections
import os
import re
import shutil
from datetime import datetime

archs = ["rv32i_zicsr", "rv32im_zicsr", "rv32imc_zicsr",
         "rv32imc_zba_zbb_zbc_zbs_zicsr", "rv32imafdc_zba_zbb_zbc_zbs_zicsr"]


# Official Embench benchmarks (19) https://github.com/embench/embench-iot.git
benchmarks = [
    "aha-mont64", "crc32", "cubic", "edn", "huffbench", "matmult-int", "minver",
    "nbody", "nettle-aes", "nettle-sha256", "nsichneu", "picojpeg", "qrduino",
    "sglib-combined", "slre", "st", "statemate", "ud", "wikisort"
]


def calcgeomean(d, arch):
    result = 1.0
    for p in benchmarks:
        val = d[arch].get(p, 1.0)
        result *= float(val)
    return result ** (1.0 / len(benchmarks))


def tabulate_arch_sweep(directory):
    for case in ["wallySizeOpt_size", "wallySpeedOpt_size", "wallySizeOpt_speed", "wallySpeedOpt_speed"]:
        print(case)
        d = collections.defaultdict(dict)

        for arch in archs:
            file_path = os.path.join(directory, f"{case}_{arch}.json")

            if not os.path.exists(file_path):
                print(f"[WARN] Missing: {file_path}")
                continue

            with open(file_path) as f:
                for line in f:
                    m = re.search(r'"([^"]*)" : ([^,\n]+)', line)
                    if m:
                        prog = m.group(1)
                        result = m.group(2)
                        d[arch][prog] = result

        if not d:
            print(f"[WARN] No data parsed for {case}\n")
            continue

        # Header
        print("\t".join([""] + archs))

        # Collect all unique programs across all architectures
        all_progs = set()
        for arch_data in d.values():
            all_progs.update(arch_data.keys())

        # summary rows we don't want in the main table
        summary_rows = [
            "size geometric mean",
            "size geometric standard deviation",
            "speed geometric mean",
            "speed geometric standard deviation",
        ]

        # filter these out of the main proglist
        proglist = sorted(p for p in all_progs if p not in summary_rows)

        # main table rows (benchmarks + extras like md5sum, primecount, tarfind)
        for prog in proglist:
            row = [prog] + [d[a].get(prog, "n/a") for a in archs]
            print("\t".join(row))

        # print any JSON-provided geometric summary rows at the bottom
        for label in summary_rows:
            if label in all_progs:
                row = [label] + [d[a].get(label, "n/a") for a in archs]
                print("\t".join(row))

        print("Total cvw Geometric Mean", end="\t")
        for arch in archs:
            if arch in d:
                print(calcgeomean(d, arch), end="\t")
            else:
                print("n/a", end="\t")
        print("\n")


def run_arch_sweep():
    # make a folder whose name depends on the date
    date_string = datetime.now().strftime("%Y%m%d_%H%M%S")
    target_dir = "run_" + date_string
    os.mkdir(target_dir)

    # these are the four JSONs your Makefile creates in actual_embench_results/
    results = [
        "SizeOpt_size", "SizeOpt_speed", "SpeedOpt_size", "SpeedOpt_speed",
    ]

    # sweep the runs and save the results in the run directory
    for arch in archs:
        print(f"[INFO] Running make run ARCH={arch}")
        os.system("make clean")
        os.system("make run ARCH=" + arch)

        for res in results:
            src = os.path.join("actual_embench_results", f"wally{res}.json")
            dst = os.path.join(target_dir, f"wally{res}_{arch}.json")

            if os.path.exists(src):
                shutil.copy(src, dst)
                print(f"[INFO] Copied {src} -> {dst}")
            else:
                print(f"[WARN] Missing result file: {src}")

    return target_dir


if __name__ == "__main__":
    directory = run_arch_sweep()
    # directory = "run_20231120_072037-caches"
    tabulate_arch_sweep(directory)
