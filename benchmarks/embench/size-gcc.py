#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
"""Keep Embench's size-only library stubs opaque to link-time optimization."""

import os
import sys
from pathlib import Path


def main():
    compiler = os.environ.get("EMBENCH_CC", "riscv64-unknown-elf-gcc")
    args = sys.argv[1:]
    dummy_sources = {"dummy-crt0.c", "dummy-libc.c", "dummy-libgcc.c", "dummy-libm.c"}
    if "-c" in args and any(Path(arg).name in dummy_sources for arg in args):
        # Inlining these fake library bodies can erase benchmark work. LTO can
        # also drop helpers that GCC only introduces during code generation.
        args.append("-fno-lto")
    os.execvp(compiler, [compiler, *args])


if __name__ == "__main__":
    main()
