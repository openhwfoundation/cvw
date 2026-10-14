#!/usr/bin/env python3
#
# WALLY-debug-fpu.py
# jacob.pease@okstate.edu 18 March 2026
# james.stine@okstate.edu 18 March 2026
#
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

import math
import struct


# ---- float32 helpers (match fmul.s / fsub.s) ----
def f32(x):
    return struct.unpack("<f", struct.pack("<f", x))[0]

def fp_hex(x):
    return struct.unpack("<I", struct.pack("<f", x))[0]

# ---- constants from assembly ----
f0 = f32(struct.unpack("<f", struct.pack("<I", 0x3f000000))[0])  # 0.5
f1 = f32(struct.unpack("<f", struct.pack("<I", 0x3f400000))[0])  # 0.75
f2 = f32(struct.unpack("<f", struct.pack("<I", 0x3fc00000))[0])  # 1.5
f3 = f32(struct.unpack("<f", struct.pack("<I", 0x40000000))[0])  # 2.0

iterations = 4

print("Newton iterations (matches fsw outputs):\n")

for i in range(iterations):

    # fmul.s / fsub.s sequence
    f4 = f32(f1 * f1)
    f4 = f32(f4 * f3)
    f4 = f32(f4 * f0)
    f4 = f32(f2 - f4)
    f1 = f32(f4 * f1)

    print(
        f"iter {i+1}: "
        f"y = {f1:.10f}   hex=0x{fp_hex(f1):08x}"
    )

print("\nReference 1/sqrt(2) =", 1/math.sqrt(2))
