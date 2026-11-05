######################################################################
# dtm.tcl: raw JTAG scans for the DTM rule tests
#
# Source after rules.tcl. These helpers scan Spike's JTAG DTM directly
# with OpenOCD irscan/drscan and echo directives that tv_from_log.py
# turns into raw-scan vector lines, in order with the DMI lines:
#
#   TV_IR <width> <tdi>             IR scan (OpenOCD can't return the
#                                   IR's TDO, so there is no Spike value)
#   TV_DR <width> <tdi> <tdo>       DR scan; tdo is what Spike shifted out
#   TV_TLR                          Test-Logic-Reset (TMS high), then idle
#   TV_TCK <ns>                     TCK half-period for the raw scans
#                                   that follow (testbench only)
#   TV_RTI <n>                      Run-Test/Idle cycles before each raw
#                                   scan that follows; 0 = go straight
#                                   from Update to Select-DR (testbench
#                                   only; Spike runs with --dmi-rti=0)
#   TV_SCAN_CHECK <mask> [<value>]  compare the mask bits of the last
#                                   TV_IR/TV_DR's TDO; with value, expect
#                                   value's bits (the spec value, where
#                                   Spike differs or can't be scanned)
#   TV_SCAN_ALT <mask> <value>      also accept this outcome for the
#                                   last checked scan
#
# Raw scans are compared only when checked. A DMI access after a raw
# IR scan reselects dmi on both sides (OpenOCD tracks its IR; the
# testbench debugger does the same).
######################################################################

set DTM_TAP riscv.cpu
set IR_BYPASS0 0x00
set IR_IDCODE 0x01
set IR_DTMCS 0x10
set IR_DMI 0x11
set IR_BYPASS 0x1f

# Wally's IDCODE (config P.JEDEC, src/debug/data_reg.sv): version 1,
# part 0x002a, manufacturer 0x602 (OpenHW Group, JEP106 bank 13 id 0x02).
set WALLY_IDCODE 0x1002ac05
# Wally's dtmcs after reset: errinfo=4, idle=0, dmistat=0, abits=7,
# version=1.
set WALLY_DTMCS 0x00100071

proc dtm_ir {ir} {
    global DTM_TAP
    irscan $DTM_TAP $ir
    echo [format "TV_IR 5 0x%02x" $ir]
}

# DR scan of width bits (<= 64); returns the value shifted out.
proc dtm_dr {width tdi} {
    global DTM_TAP
    set tdo [drscan $DTM_TAP $width [format 0x%x $tdi]]
    set tdo [expr {"0x$tdo"}]
    echo [format "TV_DR %d 0x%x 0x%x" $width $tdi $tdo]
    return $tdo
}

# A DR scan that OpenOCD refuses to do (it won't drscan a TAP that it
# believes is in BYPASS, as after Test-Logic-Reset). The testbench still
# scans; the caller must follow with dtm_check and a full spec value.
proc dtm_dr_unscanned {width tdi} {
    echo [format "TV_DR %d 0x%x 0x0" $width $tdi]
}

proc dtm_tlr {} {
    pathmove RESET IDLE
    echo "TV_TLR"
}

proc dtm_tck {ns} { echo "TV_TCK $ns" }
proc dtm_rti {n} { echo "TV_RTI $n" }

proc dtm_check {mask args} {
    if {[llength $args] == 0} {
        echo [format "TV_SCAN_CHECK 0x%x" $mask]
    } else {
        echo [format "TV_SCAN_CHECK 0x%x 0x%x" $mask [lindex $args 0]]
    }
}

proc dtm_alt {mask value} {
    echo [format "TV_SCAN_ALT 0x%x 0x%x" $mask $value]
}

# dmi register value: address, data, op
proc dmi_val {addr data op} {
    return [expr {($addr << 34) | (($data & 0xffffffff) << 2) | $op}]
}
proc dmi_op {v} { return [expr {$v & 3}] }
proc dmi_data {v} { return [expr {($v >> 2) & 0xffffffff}] }
proc dmi_addr {v} { return [expr {($v >> 34) & 0x7f}] }

# Raw dmi scan (IR must be dmi); returns the value shifted out.
proc dmi_scan {addr data op} {
    return [dtm_dr 41 [dmi_val $addr $data $op]]
}

# Write dtmcs (selects dtmcs, scans, leaves IR = dtmcs); returns the
# dtmcs value captured before the write.
proc dtmcs_write {value} {
    global IR_DTMCS
    dtm_ir $IR_DTMCS
    return [dtm_dr 32 $value]
}

# Back to dmi before the DMI helpers run (they would reselect anyway).
proc dtm_restore_dmi {} {
    global IR_DMI
    dtm_ir $IR_DMI
}

# An IR scan that OpenOCD can't do (its irscan always uses the
# configured irlen of 5 and returns no TDO). The testbench still scans;
# the caller must follow with dtm_check and a spec value, then put both
# sides back in step with dtm_ir.
proc dtm_ir_unscanned {width tdi} {
    echo [format "TV_IR %d 0x%x" $width $tdi]
}
