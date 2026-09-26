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
import socket
import subprocess
import time

WALLY = os.environ.get("WALLY")
DEBUGTESTS = f"{WALLY}/tests/debug/build"
ISA = "rv64gc_zicsr"
ISA32 = "rv32gcB_Zicbom_Zicsr_zicntr"
RBBPORT = "9824"

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
def find_free_port(host = "127.0.0.1"):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((host, 0))
        return s.getsockname()[1]

def is_port_in_use(port, host = "127.0.0.1"):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            s.bind((host, port))
            return False          # we succeeded → nothing is listening
        except OSError:
            return True           # address in use → server is up

def wait_for_port(port, host = "127.0.0.1",
                  timeout = 10.0,
                  process = None):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if process is not None and process.poll() is not None:
            raise RuntimeError(
                f"Server process exited early (return code {process.returncode})"
            )
        if is_port_in_use(port, host):
            return
        time.sleep(0.05)
    raise TimeoutError(f"Nothing listening on {host}:{port} after {timeout}s")

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
def start_spike(test, isa, port = "9824"):
    print(f"Launching Spike with port: {port}")
    spikeargs = SPIKEARGS[:]

    if (isa == "32"):
        spikeargs[1] = f"--isa={ISA32}"
        #spikeargs[7] = f"--dm-datacount=1" # default is 2 in Spike, despite 32 bit or 64 bit architectures

    if (port):
        spikeargs[2] = f"--rbb-port={port}"
    spikeargs = spikeargs + \
        [f"+signature={os.path.splitext(test)[0]}.signature.output", test]
    print(" ".join(spikeargs))
    return subprocess.Popen(spikeargs)

def start_openocd(tclscript, isa, elf, port = "9824"):
    print(f"Launching OpenOCD with port: {port}")
    test_name = os.path.splitext(os.path.basename(elf))[0]
    build_dir = "build32" if isa == "32" else "build"

    openocd_args = [
        "openocd",
        "-c", f"set PORT {port}",
        "-f", "openocd.cfg",
        "-c", f"set ISA32 {1 if isa == '32' else 0}",
        "-c", f"set BUILD_DIR {build_dir}",
        "-c", f"set TEST_NAME {test_name}",
        "-c", f"source {tclscript}"
    ]
    print(" ".join(openocd_args))
    return subprocess.Popen(openocd_args)

# --------------------------------------------------------------------

def main(args):
    port = find_free_port()

    spikeinst = start_spike(args.test, args.isa, port)

    try:
        wait_for_port(port, process=spikeinst)
    except Exception:
        spikeinst.kill()
        spikeinst.wait()
        raise

    openocd_proc = start_openocd(args.tcl, args.isa, args.test, port)
    openocd_proc.wait()
    print(os.path.splitext(args.test))

if __name__ == "__main__":
    args = parse_args()
    main(args)
