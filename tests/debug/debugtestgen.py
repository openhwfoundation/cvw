#!/usr/bin/env python3
#
# debugtestgen.py
# jacob.pease@okstate.edu 5 Apr 2025
# james.stine@okstate.edu
# Integrat vectors from spike and use to compare to simulation
#
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

import argparse
import os
import re
import selectors
import subprocess
import threading
import time

WALLY = os.environ.get("WALLY")
DEBUGTESTS = f"{WALLY}/tests/debug/build"
ISA = "rv64gc_zicsr"
ISA32 = "rv32gcB_Zicbom_Zicsr_zicntr"
RBBPORT = "9824"
OPENOCD_TIMEOUT = 600  # seconds; a stuck OpenOCD fails the test instead of hanging make

SPIKEARGS = [
    "spike",
    "--isa=rv64gcB_Zicbom_Zicsr_zicntr",
    "--rbb-port=9824",
    "--dm-progsize=0",
    "--dm-no-hasel",
    "--dm-no-halt-groups",
    "--dm-no-impebreak",
    "--dm-datacount=2",
    "+signature-granularity=4"
]

# --------------------------------------------------------------------
# Port control
# --------------------------------------------------------------------
# Spike is started with --rbb-port=0, so the kernel picks a free port
# when Spike binds it, and Spike prints the port it got. Choosing a
# port in this script first and passing it to Spike races with other
# parallel generators, which can then attach OpenOCD to the wrong Spike.
LISTENING = re.compile(r"Listening for remote bitbang connection on port (\d+)")

def wait_for_port(process, timeout = 10.0):
    sel = selectors.DefaultSelector()
    sel.register(process.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if not sel.select(timeout=deadline - time.monotonic()):
            break
        line = process.stdout.readline()
        if not line:
            raise RuntimeError(
                f"Spike exited early (return code {process.wait()})"
            )
        print(line, end="")
        m = LISTENING.search(line)
        if m:
            # Keep passing Spike's output through so its pipe never fills.
            threading.Thread(target=copy_output, args=(process.stdout,),
                             daemon=True).start()
            return m.group(1)
    raise TimeoutError(f"Spike did not report its port after {timeout}s")

def copy_output(stream):
    for line in stream:
        print(line, end="")

# --------------------------------------------------------------------
# Argument parsing
# --------------------------------------------------------------------
def non_empty_string(value):
    if len(value.strip()) == 0:
        raise argparse.ArgumentTypeError("Argument must be a non-empty string")
    return value

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--test", "-s", help="Assembly test.", type=non_empty_string)
    parser.add_argument(
        "--tcl", "-t", help="Tcl script to run parallel to assembly test.",
        type=non_empty_string)
    parser.add_argument(
        "--isa", "-i", help="ISA choice, [32, 64]", type=non_empty_string
    )
    return parser.parse_args()

# --------------------------------------------------------------------
# Processes
# --------------------------------------------------------------------
def start_spike(test, isa):
    print("Launching Spike")
    spikeargs = SPIKEARGS[:]

    if (isa == "32"):
        spikeargs[1] = f"--isa={ISA32}"
        #spikeargs[7] = f"--dm-datacount=1" # default is 2 in Spike, despite 32 bit or 64 bit architectures

    spikeargs[2] = "--rbb-port=0"
    spikeargs = spikeargs + \
        [f"+signature={os.path.splitext(test)[0]}.signature.output", test]
    print(" ".join(spikeargs))
    return subprocess.Popen(spikeargs, stdout=subprocess.PIPE, text=True)

def start_openocd(tclscript, isa, elf, port = "9824"):
    print(f"Launching OpenOCD with port: {port}")
    test_name = os.path.splitext(os.path.basename(elf))[0]
    build_dir = "build32" if isa == "32" else "build"

    # Parallel OpenOCD instances will collide on gdb/telnet/and tcl
    # ports, so disabling those ports for parallel test generation is
    # necessary. Disable them before the test script runs init, which
    # opens the ports.

    openocd_args = [
        "openocd",
        "-c", f"set PORT {port}",
        "-c", "gdb port disabled; telnet port disabled; tcl port disabled",
        "-f", "openocd.cfg",
        "-c", f"set ISA32 {1 if isa == '32' else 0}",
        "-c", f"set BUILD_DIR {build_dir}",
        "-c", f"set TEST_NAME {test_name}",
        "-c", f"source {tclscript}",
    ]
    print(" ".join(openocd_args))
    return subprocess.Popen(openocd_args)

# --------------------------------------------------------------------

def main(args):
    spikeinst = start_spike(args.test, args.isa)

    try:
        port = wait_for_port(spikeinst)
    except Exception:
        spikeinst.kill()
        spikeinst.wait()
        raise

    openocd_proc = start_openocd(args.tcl, args.isa, args.test, port)
    try:
        openocd_proc.wait(timeout=OPENOCD_TIMEOUT)
    except subprocess.TimeoutExpired:
        openocd_proc.kill()
        openocd_proc.wait()
        spikeinst.kill()
        spikeinst.wait()
        raise RuntimeError(f"OpenOCD did not finish within {OPENOCD_TIMEOUT}s")
    try:
        spikeinst.wait(timeout=1)  # Some tests end after OpenOCD finishes. Have to wait for them.
    except subprocess.TimeoutExpired:
        spikeinst.kill()
        spikeinst.wait()

    print(os.path.splitext(args.test))

if __name__ == "__main__":
    args = parse_args()
    main(args)
