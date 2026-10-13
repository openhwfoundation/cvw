
set partNumber $::env(XILINX_PART)
set boardName $::env(XILINX_BOARD)

set ipName ahbaxibridge

create_project $ipName . -force -part $partNumber
if {$boardName!="ArtyA7" && $boardName!="qmtechk7"} {
    set_property board_part $boardName [current_project]
}

# really just these two lines which change
create_ip -name ahblite_axi_bridge -vendor xilinx.com -library ip -module_name $ipName
set_property -dict [list CONFIG.C_M_AXI_DATA_WIDTH {64} CONFIG.C_S_AHB_DATA_WIDTH {64} CONFIG.C_M_AXI_THREAD_ID_WIDTH {4}] [get_ips $ipName]

generate_target {instantiation_template} [get_files ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
generate_target all [get_files  ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
create_ip_run [get_files -of_objects [get_fileset sources_1] ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
launch_run -jobs 8 ${ipName}_synth_1
wait_on_run ${ipName}_synth_1
