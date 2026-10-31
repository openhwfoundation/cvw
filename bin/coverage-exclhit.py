#!/usr/bin/env python3
###########################################
## coverage-exclhit.py
##
## Written: David_Harris@hmc.edu 27 October 2026
##
## Purpose: Find coverage items that an exclusion file excludes although a test hit them.  An exclusion
##          claims that its item cannot be reached, so a hit means the claim (or the exclusion's target)
##          is wrong.  Compares two `vcover report -details -showexcluded -all` reports: one of the merged
##          database before exclusions and one after.  Items excluded and hit show as E-hit; those
##          already E-hit before (RTL coverage pragmas) are not reported.  -all is needed because the
##          report otherwise omits the rows of expressions and conditions that are at 100%.
##
## Usage: coverage-exclhit.py <before.rpt> <after.rpt> <coverage-exclusions.do>
##          Items under an instance that the .do file excludes whole (coverage exclude -scope <s> -recursive)
##          are not reported: such an instance is excluded with its reset and idle activity on purpose.
##          Exits 1 if any other item is excluded and hit.
##
## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwfoundation/cvw
##
## Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
###########################################

import re
import sys
from collections import Counter


def ehits(fn):
    """E-hit lines of a report, keyed by instance, section and FEC expression line."""
    found = Counter()
    inst = section = expr = None
    with open(fn, errors="replace") as f:
        for line in f:
            if m := re.match(r"^=== Instance: (\S+)", line):
                inst, section, expr = m.group(1), None, None
            elif m := re.match(r"^(\w+ Coverage for instance|-+Focused \w+ View)", line):
                section, expr = m.group(1).strip("-"), None
            elif m := re.match(r"^Line\s+(\d+)\s+Item\s+(\d+)", line):
                expr = f"line {m.group(1)} item {m.group(2)}"
            elif "E-hit" in line:
                found[(inst, section, expr, " ".join(line.split()))] += 1
    return found


def wholeInstances(dofile):
    """Scopes the .do file excludes with -recursive, with its simple `set NAME value` variables substituted."""
    variables, scopes = {}, []
    with open(dofile) as f:
        for line in f:
            if m := re.match(r"^\s*set\s+(\w+)\s+(\S+)\s*$", line):
                variables[m.group(1)] = m.group(2)
            elif m := re.match(r"^\s*coverage exclude -scope (\S+) -recursive\s*$", line):
                scopes.append(m.group(1))
    def subst(s):
        return re.sub(r"\$\{?(\w+)\}?", lambda m: subst(variables[m.group(1)]), s)
    return [subst(s) for s in scopes]


def main():
    if len(sys.argv) != 4:
        sys.exit("usage: coverage-exclhit.py <before.rpt> <after.rpt> <coverage-exclusions.do>")
    before, after, allowed = ehits(sys.argv[1]), ehits(sys.argv[2]), wholeInstances(sys.argv[3])
    new = [k for k in after - before if not any(k[0] == a or k[0].startswith(a + "/") for a in allowed)]
    for inst, section, expr, text in sorted(new, key=lambda k: tuple(str(x) for x in k)):
        print(f"excluded but hit: {inst} {section}{', ' + expr if expr else ''}: {text}")
    if new:
        print(f"{len(new)} excluded items were hit: fix or remove their exclusions")
        sys.exit(1)


if __name__ == "__main__":
    main()
