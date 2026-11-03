#!/usr/bin/env python3
###############################################################################
# tv_from_log.py
#
# Turns an OpenOCD debug log into a debugger testvector file.
#
# Every "41b" DMI scan logged by OpenOCD becomes one testvector line,
# as the old grep | sed pipeline did. Tcl scripts can also echo
# directives into the log (see testvectors/lib/rules.tcl):
#
#   TV_RULE
#       Rule mode: compare only the responses named by TV_CHECK, and
#       turn off the testbench's knownExceptions waivers. All other
#       scans are setup.
#   TV_CHECK <addr> <mask> [<data>]
#       Compare the bits in <mask> of the last response carrying data
#       from DM register <addr>. With <data>, expect those bits of
#       <data> (the spec value) instead of what Spike returned.
#   TV_DONTCARE_BEGIN / TV_DONTCARE_END
#       Don't compare the responses of scans in between (for polling
#       loops whose length depends on timing).
#
# Raw JTAG directives (see testvectors/lib/dtm.tcl):
#   TV_IR <width> <tdi>, TV_DR <width> <tdi> <tdo>
#       A raw IR or DR scan, with what Spike shifted out (IR: none).
#   TV_SCAN_CHECK <mask> [<value>]
#       Compare the mask bits of the last raw scan's TDO; with
#       <value>, expect those bits of <value> (the spec value).
#   TV_SCAN_ALT <mask> <value>
#       Also accept TDO whose mask bits equal <value>'s.
#   TV_TLR, TV_TCK <ns>, TV_RTI <n>
#       Test-Logic-Reset; TCK half-period; Run-Test/Idle cycles before
#       each raw scan (testbench timing only).
#
# Output lines are "[x ]<request> -> <response>[ mask=<hex>]", where
# "x " means the response is not compared and mask= limits the data
# bits compared. Raw lines are "[x ]ir|dr <width> <tdi>[ -> <tdo>
# mask=<hex>[ alt=<value>/<mask>]]", "tlr", "tck <ns>" and "rti <n>"
# (hex without 0x); raw scans are compared only when checked.
#
# Usage: tv_from_log.py <openocd.log> <out.tv>
###############################################################################

import re
import sys

SCAN = re.compile(r"41b ([rw-]) ([0-9a-f]{8}) @([0-9a-f]{2}) -> (\S) ([0-9a-f]{8}) @([0-9a-f]{2})")
DIRECTIVE = re.compile(r"handle_echo\(\): (TV_\w+)(.*)")


def raw_line(v):
    if v["raw"] not in ("ir", "dr"):
        return v["raw"]
    line = f"{v['raw']} {v['width']} {v['tdi']:x}"
    if v["mask"] is None:
        return "x " + line
    line += f" -> {v['tdo']:x} mask={v['mask']:x}"
    if v["alt"]:
        line += f" alt={v['alt'][0]:x}/{v['alt'][1]:x}"
    return (v["note"] + "\n" if v["note"] else "") + line


def main(logname, tvname):
    vectors = []
    rule = False
    dontcare = False
    checks = 0
    with open(logname) as log:
        for line in log:
            m = SCAN.search(line)
            if m:
                op, data, addr, rop, rdata, raddr = m.groups()
                vectors.append({"req": f"{op} {data} @{addr}", "rop": rop, "rdata": rdata,
                                "raddr": raddr, "dontcare": dontcare, "mask": None, "note": ""})
                continue
            d = DIRECTIVE.search(line)
            if not d:
                continue
            name, args = d.group(1), d.group(2).split()
            if name in ("TV_IR", "TV_DR"):
                vectors.append({"raw": name[3:].lower(), "width": int(args[0]),
                                "tdi": int(args[1], 0),
                                "tdo": int(args[2], 0) if len(args) > 2 else None,
                                "mask": None, "alt": None, "note": ""})
            elif name == "TV_TLR":
                vectors.append({"raw": "tlr"})
            elif name in ("TV_TCK", "TV_RTI"):
                vectors.append({"raw": f"{name[3:].lower()} {int(args[0])}"})
            elif name in ("TV_SCAN_CHECK", "TV_SCAN_ALT"):
                for v in reversed(vectors):
                    if v.get("raw") in ("ir", "dr"):
                        break
                else:
                    sys.exit(f"{logname}: {name} has no earlier raw scan")
                mask = int(args[0], 0) & ((1 << v["width"]) - 1)
                if name == "TV_SCAN_ALT":
                    if v["mask"] is None:
                        sys.exit(f"{logname}: TV_SCAN_ALT before TV_SCAN_CHECK")
                    v["alt"] = (int(args[1], 0) & mask, mask)
                    continue
                v["mask"] = mask
                checks += 1
                if len(args) > 1:
                    spike = v["tdo"] if v["tdo"] is not None else 0
                    want = (spike & ~mask) | (int(args[1], 0) & mask)
                    if want != spike or v["tdo"] is None:
                        v["note"] = f"# spec value: Spike returned {'nothing' if v['tdo'] is None else f'{spike:x}'}"
                    v["tdo"] = want
                elif v["tdo"] is None:
                    sys.exit(f"{logname}: TV_SCAN_CHECK of an IR scan needs a value")
            elif name == "TV_RULE":
                rule = True
            elif name == "TV_DONTCARE_BEGIN":
                dontcare = True
            elif name == "TV_DONTCARE_END":
                dontcare = False
            elif name == "TV_CHECK":
                addr = f"{int(args[0], 0):02x}"
                mask = int(args[1], 0) & 0xFFFFFFFF
                for v in reversed(vectors):
                    if v.get("raddr") == addr and v["rop"] == "+":
                        break
                else:
                    sys.exit(f"{logname}: TV_CHECK {addr} has no earlier response from @{addr}")
                v["mask"] = mask
                v["dontcare"] = False
                checks += 1
                if len(args) > 2:
                    spike = int(v["rdata"], 16)
                    want = (spike & ~mask) | (int(args[2], 0) & mask)
                    if want != spike:
                        v["note"] = f"# spec value @{addr}: Spike returned {spike:08x}"
                        v["rdata"] = f"{want:08x}"
            else:
                sys.exit(f"{logname}: unknown directive {name}")

    if not vectors:
        sys.exit(f"{logname}: no DMI scans found")
    if rule and checks == 0:
        sys.exit(f"{logname}: TV_RULE test has no TV_CHECK")
    with open(tvname, "w") as tv:
        if rule:
            tv.write("#pragma strict\n")
        for v in vectors:
            if "raw" in v:
                tv.write(raw_line(v) + "\n")
                continue
            if v["note"]:
                tv.write(v["note"] + "\n")
            compared = v["mask"] is not None or not (rule or v["dontcare"])
            line = f"{'' if compared else 'x '}{v['req']} -> {v['rop']} {v['rdata']} @{v['raddr']}"
            if v["mask"] is not None and v["mask"] != 0xFFFFFFFF:
                line += f" mask={v['mask']:08x}"
            tv.write(line + "\n")
        # Final resume, so the program can reach test_end and stop.
        tv.write(f"{'x ' if rule else ''}w 40000001 @10 -> + 00000000 @00\n")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
