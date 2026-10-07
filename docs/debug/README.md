# Wally Debug Support

This repository documents debug support for **Wally**, an open-source RISC-V processor platform. The goal of this effort is to support the RISC-V Debug Specification while enabling reliable debugging in both simulation and hardware environments. Wally integrates debug functionality compatible with OpenOCD, Spike remote bitbang simulation, and physical JTAG debug adapters.

## OpenOCD for RISC-V

This repository uses a separate fork of OpenOCD maintained by the RISC-V
community, available at:
```
https://github.com/riscv/riscv-openocd
```
## Installation

OpenOCD for RISC-V is installed as part of the Wally toolchain. To install,
run the provided installation script:
```bash
$RISCV/bin/wally-tool-chain-install.sh
```

This script will automatically download, build, and install `riscv-openocd`
along with the rest of the Wally toolchain components. The `$RISCV` environment
variable should be set per `setup.sh` to your toolchain installation directory
before running the script.

### Why a Separate Fork?

The official OpenOCD mainline was slow to merge RISC-V support, so the
RISC-V community (primarily SiFive) maintained an independent fork to track
the evolving RISC-V debug specification. Key reasons the fork exists:

- **Evolving debug spec** — the RISC-V External Debug Support specification
  went through significant revisions (0.11 → 0.13 → 1.0) while hardware was
  already being shipped, requiring frequent implementation updates that
  mainline OpenOCD could not absorb quickly enough
- **Hardware availability** — SiFive and others were shipping silicon that
  needed a working debugger before upstream review cycles could complete
- **Slow upstream process** — mainline OpenOCD has a small maintainer team
  and large feature sets take considerable time to review and merge

RISC-V support has since been progressively upstreamed into mainline OpenOCD,
so the gap between the two has narrowed. However, `riscv-openocd` may still
carry newer debug spec features or bug fixes ahead of mainline.

### Key Components

**DTM (Debug Transport Module)** — sits between JTAG and the debug module.
It exposes a small set of JTAG registers (`dtmcs`, `dmi`) that OpenOCD uses
to issue DMI transactions. The DTM handles the clock domain crossing between
the JTAG TCK domain and the core's system clock domain.

**DMI (Debug Module Interface)** — a simple address/data/op bus. OpenOCD
reads and writes DMI registers to control the debug module. Key registers
include `dmcontrol` (halt/resume), `dmstatus` (hart state), `abstractcs`
(abstract command control), `data0`/`data1` (data exchange), and
`progbuf0`–`progbufN` (program buffer for executing arbitrary instructions).

**Debug Module (DM)** — the on-chip hardware block that implements the debug
spec. It can:
- Halt and resume harts
- Reset harts or the whole system
- Execute abstract commands (read/write GPRs and CSRs directly)
- Execute arbitrary instructions via the Program Buffer
- Trigger hardware breakpoints via the Trigger Module

**Program Buffer** — a small instruction memory (typically 2–16 instructions)
that the debug module can fill with arbitrary RISC-V instructions and execute
on the halted hart. This is the mechanism used to access Debug Mode-only CSRs
(`dcsr`, `dscratch0`, `dscratch1`) and to perform memory access, since those
CSRs are only accessible when the hart is in Debug Mode.

**Trigger Module** — a set of hardware comparators that can fire on
instruction addresses (breakpoints) or data addresses/values (watchpoints),
causing the hart to enter Debug Mode without software intervention. Configured
via the `tselect`, `tdata1`, and `tdata2` CSRs from M-mode.


## Supported RISC-V Debug Specification

Wally currently targets:

**RISC-V Debug Specification — Version 1.0 (Revised 2025-02-21)**

Development continues toward expanded functionality and improved
tool interoperability.

---

## Note on Spike Debug Compatibility

The current Wally debug implementation does **not** include an initial Debug Module *program buffer* (`progbufsize = 0`). While this is allowed by the RISC-V Debug Specification (which permits implementations to rely on abstract register access instead of a program buffer), some debugger workflows assume program-buffer execution is available.

A recent Spike update (https://github.com/riscv-software-src/riscv-isa-sim/commit/5397899bb9eddba8c2f87d7d62e6303629ebed90) introduced stricter debug checks, including an assertion (around line 122 of riscv/debug_module.cc) that may trigger when debugging a target that does not implement a program buffer.

As a result, users may observe assertion failures or unexpected debugger behavior when using newer versions of Spike together with Wally debug.

This limitation is temporary. Future Wally debug revisions will include program buffer support, improving compatibility with Spike, OpenOCD, and standard RISC-V debug workflows.

Spike also does not implement the DCSR fields `stopcount` and `stoptime`. It's possible to implement these bits in Wally, but using the testvector generation system in `tests/debug` causes these bits to be set to zero upon resume since they are hardcoded to zero in Spike. Spike's issue [1621](https://github.com/riscv-software-src/riscv-isa-sim/issues/1621) has the details.

---

## OpenOCD udev Rules Installation (Linux)

USB debug adapters typically require root privileges. Installing the OpenOCD udev rules allows OpenOCD to access supported debug probes without using `sudo`.

The rules file is provided with OpenOCD:

```
contrib/60-openocd.rules
```

Install it with:

```bash
sudo cp openocd-code/contrib/60-openocd.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

After installation, unplug and reconnect the debug adapter.  You may also need to log out and back in if group permissions change.

OpenOCD should then run normally as a user as an example here:

```bash
openocd -f tests/debug/openocd.cfg
```
