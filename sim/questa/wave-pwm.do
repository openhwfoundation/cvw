onerror {resume}
quietly virtual signal -install /testbench/dut/core/ifu/bpred/bpred { /testbench/dut/core/ifu/bpred/bpred/PostSpillInstrRawF[11:7]} rd
quietly WaveActivateNextPane {} 0
add wave -noupdate /testbench/clk
add wave -noupdate /testbench/reset
add wave -noupdate /testbench/memfilename
add wave -noupdate /testbench/dut/core/PCE
add wave -noupdate /testbench/dut/core/ieu/dp/regf/rf
add wave -noupdate -label MCYCLE -radix unsigned {/testbench/dut/core/priv/priv/csr/counters/counters/HPMCOUNTER_REGW[0]}
add wave -noupdate /testbench/dut/uncoregen/uncore/pwm/pwm/PWMCompareIP
add wave -noupdate /testbench/dut/uncoregen/uncore/gpio/gpio/high_ip
add wave -noupdate /testbench/dut/uncoregen/uncore/pwm/pwm/PWMCount
add wave -noupdate /testbench/dut/uncoregen/uncore/pwm/pwm/PWMScaled
add wave -noupdate /testbench/dut/uncoregen/uncore/pwm/pwm/PWMCompare0
add wave -noupdate /testbench/dut/uncoregen/uncore/pwm/pwm/PWMDeglitchMux
add wave -noupdate /testbench/dut/uncoregen/uncore/pwm/pwm/PWMCompareXNOR
add wave -noupdate /testbench/dut/uncoregen/uncore/pwm/pwm/PWMCompareBoolean
add wave -noupdate /testbench/dut/uncoregen/uncore/pwm/pwm/PWMCompareIPIn
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 4} {89834 ns} 1} {{Cursor 4} {79055 ns} 1} {{Cursor 3} {89604 ns} 0}
quietly wave cursor active 3
configure wave -namecolwidth 250
configure wave -valuecolwidth 194
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {89564 ns} {89776 ns}
