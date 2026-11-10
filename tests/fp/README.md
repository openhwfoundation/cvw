james.stine@okstate.edu 14 Jan 2022\
jcarlin@hmc.edu Sept 2024

# TestFloat for CVW

The CVW floating point unit is tested using testvectors from the Berkeley TestFloat suite, written originally by John Hauser.

TestFloat and SoftFloat can be found as submodules in the addins directory, and are linked here:
- TestFloat:  https://github.com/ucb-bar/berkeley-testfloat-3
- SoftFloat:  https://github.com/ucb-bar/berkeley-softfloat-3

## Compiling SoftFloat/TestFloat and Generating Testvectors

The entire testvector generation process can be performed by running make in this directory.

```bash
make --jobs
```

This compiles SoftFloat for an x86_64 environment in its `build/Linux-x86_64-GCC` directory using the `SPECIALIZE_TYPE=RISCV` flag to get RISC-V behavior. TestFloat is then compiled in its `build/Linux-x86_64-GCC` directory using this SoftFloat library.

The Makefile in the vectors subdirectory of this directory is then called to  generate testvectors for each rounding mode and operation. It also puts an underscore between the fields of each vector instead of a space, so that the testbench reads each line as one hexadecimal number.

Testvectors for the combined integer floating-point divider are also generated.

Although not needed, a `case.sh` script is included to change the case of the hex output.  This is for those that do not like to see hexadecimal capitalized :P.

## Running TestFloat Vectors on Wally

TestFloat is run using the standard Wally simulation commands.

To run all TestFloat tests on many different derived configurations of Wally, use
```bash
regression-wally --testfloat
```

To run a single test, use
```bash
wsim <config> <test> --tb testbench_fp            # Verilator by default; --sim questa or vcs also work
wsim <config> <test> --tb testbench_fp --args +TEST_SIZE=DP   # only one precision: QP, DP, SP or HP
```
The test is a runtime plusarg, so each configuration is compiled once for all of its tests.
The choices for `<test>` are as follows:

    cvtint - test integer conversion unit (fcvtint)
    cvtfp  - test floating-point conversion unit (fcvtfp)
    cmp    - test comparison unit's LT, LE, EQ operations, and the Zfa quiet LE and LT (fleq, fltq) (fcmp)
    add    - test addition
    fma    - test fma
    mul    - test mult with fma
    sub    - test subtraction
    div    - test division
    sqrt   - test square root
    round  - test Zfa round to integer, fround and froundnx (fround)
    class  - test classify (fclassify); cover-float vectors only
    sgnj   - test sign injection fsgnj, fsgnjn, fsgnjx (fsgninj); cover-float vectors only
    minmax - test fmin and fmax (fcmp); cover-float vectors only

TestFloat has no classify, sign injection or min/max operations, so those tests run only with a vector set that has them (`+VECTORS=`, below); `all` includes them when it does. TestFloat's `roundToInt` without and with `-exact` gives the fround and froundnx vectors, and `le_quiet` and `lt_quiet` the fleq and fltq vectors; the Zfa tests run on configurations with Zfa.

Any config that includes floating point support can be used. Each test will test all its vectors for all precisions supported by the given config.

## cover-float Vectors

The FPU is also tested with the vectors of [cover-float](https://github.com/cover-float/cover-float) (submodule `addins/cover-float`), which are generated to hit the corner cases of its floating-point coverage models.
```bash
make coverfloat                                     # in $WALLY; COVERFLOAT_FLAGS=--partial-output for cover-float's smaller set
wsim <config> all --tb testbench_fp --args +VECTORS=$WALLY/tests/fp/coverfloat/vectors/
```
cover-float generates its vectors in `coverfloat/gen`, and `bin/coverfloat2tv` converts them into `coverfloat/vectors`, one file per operation, precision and rounding mode named like the TestFloat files, so `testbench_fp` runs them with any `<test>`. cover-float's round to integer gives both froundnx vectors and fround vectors (the same results with inexact cleared). Remainder, which RISC-V lacks, BF16 and round-to-odd are not converted. `regression-wally --testfloat` and `--nightly` run the cover-float vectors after the TestFloat vectors.

### Testvector Count

      46464   185856   836352 f16_add_rd.tv
      46464   185856   836352 f16_add_rne.tv
      46464   185856   836352 f16_add_ru.tv
      46464   185856   836352 f16_add_rz.tv
      46464   185856   836352 f16_div_rd.tv
      46464   185856   836352 f16_div_rne.tv
      46464   185856   836352 f16_div_ru.tv
      46464   185856   836352 f16_div_rz.tv
      46464   185856   836352 f16_mul_rd.tv
      46464   185856   836352 f16_mul_rne.tv
      46464   185856   836352 f16_mul_ru.tv
      46464   185856   836352 f16_mul_rz.tv
        408     1224     5304 f16_sqrt_rd.tv
        408     1224     5304 f16_sqrt_rne.tv
        408     1224     5304 f16_sqrt_ru.tv
        408     1224     5304 f16_sqrt_rz.tv
      46464   185856   836352 f16_sub_rd.tv
      46464   185856   836352 f16_sub_rne.tv
      46464   185856   836352 f16_sub_ru.tv
      46464   185856   836352 f16_sub_rz.tv
      46464   185856  1393920 f32_add_rd.tv
      46464   185856  1393920 f32_add_rne.tv
      46464   185856  1393920 f32_add_ru.tv
      46464   185856  1393920 f32_add_rz.tv
      46464   185856  1068672 f32_cmp_eq_signaling.tv
      46464   185856  1068672 f32_cmp_eq.tv
      46464   185856  1068672 f32_cmp_le_quiet.tv
      46464   185856  1068672 f32_cmp_le.tv
      46464   185856  1068672 f32_cmp_lt_quiet.tv
      46464   185856  1068672 f32_cmp_lt.tv
      46464   185856  1393920 f32_div_rd.tv
      46464   185856  1393920 f32_div_rne.tv
      46464   185856  1393920 f32_div_ru.tv
      46464   185856  1393920 f32_div_rz.tv
        600     1800    17400 f32_f64_rd.tv
        600     1800    17400 f32_f64_rne.tv
        600     1800    17400 f32_f64_ru.tv
        600     1800    17400 f32_f64_rz.tv
        600     1800    12600 f32_i32_rd.tv
        600     1800    12600 f32_i32_rne.tv
        600     1800    12600 f32_i32_ru.tv
        600     1800    12600 f32_i32_rz.tv
        600     1800    17400 f32_i64_rd.tv
        600     1800    17400 f32_i64_rne.tv
        600     1800    17400 f32_i64_ru.tv
        600     1800    17400 f32_i64_rz.tv
      46464   185856  1393920 f32_mul_rd.tv
      46464   185856  1393920 f32_mul_rne.tv
      46464   185856  1393920 f32_mul_ru.tv
      46464   185856  1393920 f32_mul_rz.tv
        600     1800    12600 f32_sqrt_rd.tv
        600     1800    12600 f32_sqrt_rne.tv
        600     1800    12600 f32_sqrt_ru.tv
        600     1800    12600 f32_sqrt_rz.tv
      46464   185856  1393920 f32_sub_rd.tv
      46464   185856  1393920 f32_sub_rne.tv
      46464   185856  1393920 f32_sub_ru.tv
      46464   185856  1393920 f32_sub_rz.tv
        600     1800    12600 f32_ui32_rd.tv
        600     1800    12600 f32_ui32_rne.tv
        600     1800    12600 f32_ui32_ru.tv
        600     1800    12600 f32_ui32_rz.tv
        600     1800    17400 f32_ui64_rd.tv
        600     1800    17400 f32_ui64_rne.tv
        600     1800    17400 f32_ui64_ru.tv
        600     1800    17400 f32_ui64_rz.tv
      46464   185856  2509056 f64_add_rd.tv
      46464   185856  2509056 f64_add_rne.tv
      46464   185856  2509056 f64_add_ru.tv
      46464   185856  2509056 f64_add_rz.tv
      46464   185856  1812096 f64_cmp_eq_signaling.tv
      46464   185856  1812096 f64_cmp_eq.tv
      46464   185856  1812096 f64_cmp_le_quiet.tv
      46464   185856  1812096 f64_cmp_le.tv
      46464   185856  1812096 f64_cmp_lt_quiet.tv
      46464   185856  1812096 f64_cmp_lt.tv
      46464   185856  2509056 f64_div_rd.tv
      46464   185856  2509056 f64_div_rne.tv
      46464   185856  2509056 f64_div_ru.tv
      46464   185856  2509056 f64_div_rz.tv
        768     2304    22272 f64_f32_rd.tv
        768     2304    22272 f64_f32_rne.tv
        768     2304    22272 f64_f32_ru.tv
        768     2304    22272 f64_f32_rz.tv
        768     2304    22272 f64_i32_rd.tv
        768     2304    22272 f64_i32_rne.tv
        768     2304    22272 f64_i32_ru.tv
        768     2304    22272 f64_i32_rz.tv
        768     2304    28416 f64_i64_rd.tv
        768     2304    28416 f64_i64_rne.tv
        768     2304    28416 f64_i64_ru.tv
        768     2304    28416 f64_i64_rz.tv
      46464   185856  2509056 f64_mul_rd.tv
      46464   185856  2509056 f64_mul_rne.tv
      46464   185856  2509056 f64_mul_ru.tv
      46464   185856  2509056 f64_mul_rz.tv
        768     2304    28416 f64_sqrt_rd.tv
        768     2304    28416 f64_sqrt_rne.tv
        768     2304    28416 f64_sqrt_ru.tv
        768     2304    28416 f64_sqrt_rz.tv
      46464   185856  2509056 f64_sub_rd.tv
      46464   185856  2509056 f64_sub_rne.tv
      46464   185856  2509056 f64_sub_ru.tv
      46464   185856  2509056 f64_sub_rz.tv
        768     2304    22272 f64_ui32_rd.tv
        768     2304    22272 f64_ui32_rne.tv
        768     2304    22272 f64_ui32_ru.tv
        768     2304    22272 f64_ui32_rz.tv
        768     2304    28416 f64_ui64_rd.tv
        768     2304    28416 f64_ui64_rne.tv
        768     2304    28416 f64_ui64_ru.tv
        768     2304    28416 f64_ui64_rz.tv
        372     1116     7812 i32_f32_rd.tv
        372     1116     7812 i32_f32_rne.tv
        372     1116     7812 i32_f32_ru.tv
        372     1116     7812 i32_f32_rz.tv
        372     1116    10788 i32_f64_rd.tv
        372     1116    10788 i32_f64_rne.tv
        372     1116    10788 i32_f64_ru.tv
        372     1116    10788 i32_f64_rz.tv
        756     2268    21924 i64_f32_rd.tv
        756     2268    21924 i64_f32_rne.tv
        756     2268    21924 i64_f32_ru.tv
        756     2268    21924 i64_f32_rz.tv
        756     2268    27972 i64_f64_rd.tv
        756     2268    27972 i64_f64_rne.tv
        756     2268    27972 i64_f64_ru.tv
        756     2268    27972 i64_f64_rz.tv
        372     1116     7812 ui32_f32_rd.tv
        372     1116     7812 ui32_f32_rne.tv
        372     1116     7812 ui32_f32_ru.tv
        372     1116     7812 ui32_f32_rz.tv
        372     1116    10788 ui32_f64_rd.tv
        372     1116    10788 ui32_f64_rne.tv
        372     1116    10788 ui32_f64_ru.tv
        372     1116    10788 ui32_f64_rz.tv
        756     2268    21924 ui64_f32_rd.tv
        756     2268    21924 ui64_f32_rne.tv
        756     2268    21924 ui64_f32_ru.tv
        756     2268    21924 ui64_f32_rz.tv
        756     2268    27972 ui64_f64_rd.tv
        756     2268    27972 ui64_f64_rne.tv
        756     2268    27972 ui64_f64_ru.tv
        756     2268    27972 ui64_f64_rz.tv
    2840352 11308896 94651296 total
