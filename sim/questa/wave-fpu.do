
add wave -noupdate /cvw_testbench_fp/clk
add wave -noupdate -radix decimal /cvw_testbench_fp/VectorNum
add wave -noupdate /cvw_testbench_fp/FrmNum
add wave -noupdate /cvw_testbench_fp/X
add wave -noupdate /cvw_testbench_fp/Y
add wave -noupdate /cvw_testbench_fp/Z
add wave -noupdate /cvw_testbench_fp/Res
add wave -noupdate /cvw_testbench_fp/Ans
add wave -noupdate /cvw_testbench_fp/reset
add wave -noupdate /cvw_testbench_fp/DivStart
add wave -noupdate /cvw_testbench_fp/FDivBusyE
add wave -noupdate /cvw_testbench_fp/CheckNow
add wave -noupdate /cvw_testbench_fp/DivDone
add wave -noupdate /cvw_testbench_fp/ResMatch
add wave -noupdate /cvw_testbench_fp/FlagMatch
add wave -noupdate /cvw_testbench_fp/CheckNow
add wave -noupdate /cvw_testbench_fp/NaNGood
add wave -group {PostProc} -noupdate /cvw_testbench_fp/postprocess/*
add wave -group {PostProc} -noupdate /cvw_testbench_fp/postprocess/specialcase/*
add wave -group {PostProc} -noupdate /cvw_testbench_fp/postprocess/flags/*
add wave -group {PostProc} -noupdate /cvw_testbench_fp/postprocess/normshift/*
add wave -group {PostProc} -noupdate /cvw_testbench_fp/postprocess/shiftcorrection/*
add wave -group {PostProc} -noupdate /cvw_testbench_fp/postprocess/resultsign/*
add wave -group {PostProc} -noupdate /cvw_testbench_fp/postprocess/rounder/*
add wave -group {PostProc} -noupdate /cvw_testbench_fp/postprocess/fmashiftcalc/*
add wave -group {PostProc} -noupdate /cvw_testbench_fp/postprocess/divshiftcalc/*
add wave -group {PostProc} -noupdate /cvw_testbench_fp/postprocess/cvtshiftcalc/*
add wave -group {Testbench} -noupdate /cvw_testbench_fp/*
add wave -group {Testbench} -noupdate /cvw_testbench_fp/readvectors/*
