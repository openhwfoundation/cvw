# ACT4 vector tests on Wally

`bin/vector-act` builds the riscv-arch-test (ACT4) vector tests for a vector configuration of Wally and runs them.

## One-time setup

The ACT submodule must be on the fork branch that has the scalar self-check and the base-only options:

```bash
cd $WALLY/addins/riscv-arch-test
git remote rename origin upstream
git remote add origin https://github.com/georgiatai/riscv-arch-test.git
git fetch origin
git switch vector-base
```

## Running

```bash
source $WALLY/setup.sh
vector-act                         # build, then run every instruction in the passing list
vector-act vsub.vv vsub.vx         # run only these instructions
vector-act --all                   # run every Vx64 base test and report what passes
vector-act --run-only vsub.vv      # skip the build
vector-act --build-only            # build only
vector-act --suite Vf64            # floating-point tests (the default suite is Vx64)
```

Each test prints `RVCP-SUMMARY: TEST PASSED` or `FAILED`; the first mismatch in a file stops that file and
reports the register, element, expected and actual values.

## The passing list

`rv64gcv/passing-Vx64.txt` and `rv64gcv/passing-Vf64.txt` list the instructions that are implemented and whose base tests pass. Every entry
must keep passing: `vector-act` with no instructions runs the list and fails, printing `REGRESSION: ...`, if any
entry fails. An instruction that passes by coincidence (e.g. `vredsum.vs` is just an add at vl=1) does not go in
the list.

When you implement an instruction:

1. Test it: `vector-act vsub.vv vsub.vx`.
2. Make sure nothing that passed before broke: `vector-act --run-only`.
3. Add it to the list: `vector-act --run-only vsub.vv vsub.vx --update` adds the named instructions that pass
   (it never removes one). Commit `passing-Vx64.txt` with your change.

`vector-act --all` runs every test and reports instructions that pass but are not in the list, without adding them.

## What the tests contain

- **Base suite only** (`VECTOR_SUITE=base`): every testcase runs at vl=1, LMUL=1, unmasked. The length suite
  (masking, vl, LMUL 2/4/8, tail/mask agnostic, vl=0) is not generated.
- **Scalar self-check** (`VECTOR_CHECK=scalar`): a scalar routine compares the result with the value Sail computed.
- **No vector loads or stores** (`--loadstore move`, the default, `VECTOR_LOADSTORE=move`): operands are set with a
  scalar load and `vmv.v.x`, and results are read with `vmv.x.s`. Use `--loadstore vector` once `vle64.v` and
  `vse64.v` work.
- Vx64 and Vf64 on rv64gcv: SEW=64. The ACT configuration declares Zve64d, not full V, so the 9 tests that need
  full V at SEW=64 (`vmulh*`, `vsmul`) are not built.

The ACT configuration is in `rv64gcv/`, outside `config/rv64gcv/act`, so that `make act` and
`regression-wally` do not build vector tests.
