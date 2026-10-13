
set partNumber $::env(XILINX_PART)
set boardName $::env(XILINX_BOARD)
#set partNumber xcvu9p-flga2104-2L-e
#set boardName  xilinx.com:vcu118:part0:2.4

set ipName sysrst

create_project $ipName . -force -part $partNumber
if {$boardName!="ArtyA7" && $boardName!="qmtechk7" } {
    set_property board_part $boardName [current_project]
}

# really just these two lines which change
create_ip -name proc_sys_reset -vendor xilinx.com -library ip -module_name $ipName
set_property -dict [list CONFIG.C_AUX_RESET_HIGH {1} \
                         CONFIG.C_AUX_RST_WIDTH {1} \
                         CONFIG.C_EXT_RESET_HIGH {1} \
                         CONFIG.C_EXT_RST_WIDTH {1} \
                         CONFIG.C_NUM_BUS_RST {1}] [get_ips $ipName]

generate_target {instantiation_template} [get_files ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
generate_target all [get_files  ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
create_ip_run [get_files -of_objects [get_fileset sources_1] ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
launch_run -jobs 8 ${ipName}_synth_1
wait_on_run ${ipName}_synth_1
