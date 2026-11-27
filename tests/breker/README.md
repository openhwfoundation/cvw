Jordan Carlin, jcarlin@hmc.edu, December 2024

# Breker Tests for CVW

[Breker's Trek Test Suite](https://brekersystems.com/products/trek-suite/) is a proprietary set of tests that require a license to use (this license is not generally available to noncommercial users).

To generate the Breker tests (with a license), run `make` in both the `tests/breker` and `testbench/trek_files` directories. Alternatively, running `make breker` from the top-level `$WALLY` directory will run both of these. Before running, make sure to set `$BREKER_HOME` in your system's `site-setup.sh` file. The `testbench/trek_files` Makefile only needs to be run once, but the tests that are generated can be different each time so rerunning the `tests/breker` Makefile is worthwhile.

This will generate a testsuite for each of the constraint yaml files in the `constraints` directory. These generated tests are produced in the `tests/breker/work` directory. To run a single test use `wsim` to run the elf. The `rv64breker` configuration must be used. For example,

```bash
$ wsim rv64breker $WALLY/tests/breker/work/atomics_1/atomics_1.elf
```

To run all of the generated Breker tests use
```bash
$ regression-wally --breker
```
