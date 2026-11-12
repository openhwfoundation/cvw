#!/usr/bin/env python3
#
# WALLY-debug-gcd.py
# jacob.pease@okstate.edu 18 March 2026
# james.stine@okstate.edu 18 March 2026
#
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

a = 0x67B16B7B  # 1739680635
b = 0x4015F8C2  # 1075181762

# zero-extend 32-bit (matches RV64: slli 32; srli 32)
a &= 0xFFFFFFFF
b &= 0xFFFFFFFF

t0, t1 = a, b
iters = 0

while t1 != 0:
    t3 = t0 % t1   # remu
    t0 = t1        # mv
    t1 = t3        # mv
    iters += 1

print(f"a   = 0x{a:08X} ({a})")
print(f"b   = 0x{b:08X} ({b})")
print(f"gcd = 0x{t0:X} ({t0})")
print(f"iterations = {iters}")
