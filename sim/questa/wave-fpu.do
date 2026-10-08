
add wave -noupdate /testbench_fp/clk
add wave -noupdate -radix decimal /testbench_fp/VectorNum
add wave -noupdate /testbench_fp/FrmNum
add wave -noupdate /testbench_fp/X
add wave -noupdate /testbench_fp/Y
add wave -noupdate /testbench_fp/Z
add wave -noupdate /testbench_fp/Res
add wave -noupdate /testbench_fp/Ans
add wave -noupdate /testbench_fp/reset
add wave -noupdate /testbench_fp/DivStart
add wave -noupdate /testbench_fp/FDivBusyE
add wave -noupdate /testbench_fp/CheckNow
add wave -noupdate /testbench_fp/DivDone
add wave -noupdate /testbench_fp/ResMatch
add wave -noupdate /testbench_fp/FlagMatch
add wave -noupdate /testbench_fp/CheckNow
add wave -noupdate /testbench_fp/NaNGood
add wave -group {PostProc} -noupdate /testbench_fp/postprocess/*
add wave -group {PostProc} -noupdate /testbench_fp/postprocess/specialcase/*
add wave -group {PostProc} -noupdate /testbench_fp/postprocess/flags/*
add wave -group {PostProc} -noupdate /testbench_fp/postprocess/normshift/*
add wave -group {PostProc} -noupdate /testbench_fp/postprocess/shiftcorrection/*
add wave -group {PostProc} -noupdate /testbench_fp/postprocess/resultsign/*
add wave -group {PostProc} -noupdate /testbench_fp/postprocess/rounder/*
add wave -group {PostProc} -noupdate /testbench_fp/postprocess/fmashiftcalc/*
add wave -group {PostProc} -noupdate /testbench_fp/postprocess/divshiftcalc/*
add wave -group {PostProc} -noupdate /testbench_fp/postprocess/cvtshiftcalc/*
add wave -group {Testbench} -noupdate /testbench_fp/*
add wave -group {Testbench} -noupdate /testbench_fp/readvectors/*
