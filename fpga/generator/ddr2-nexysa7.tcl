
set partNumber $::env(XILINX_PART)
set boardName $::env(XILINX_BOARD)

set ipName ddr2

create_project $ipName . -force -part $partNumber
set_property board_part $boardName [current_project]

# really just these two lines which change
create_ip -name mig_7series -vendor xilinx.com -library ip -module_name $ipName

exec mkdir -p IP/$ipName.srcs/sources_1/ip/$ipName
exec cp ../xlnx_ddr2-nexysa7-mig.prj $ipName.srcs/sources_1/ip/$ipName/xlnx_ddr2-nexysa7-mig.prj

set_property -dict [list CONFIG.XML_INPUT_FILE {xlnx_ddr2-nexysa7-mig.prj} CONFIG.RESET_BOARD_INTERFACE {Custom} CONFIG.MIG_DONT_TOUCH_PARAM {Custom} CONFIG.BOARD_MIG_PARAM {Custom}] [get_ips $ipName]

generate_target {instantiation_template} [get_files ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
generate_target all [get_files  ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
create_ip_run [get_files -of_objects [get_fileset sources_1] ./$ipName.srcs/sources_1/ip/$ipName/$ipName.xci]
launch_run -jobs 8 ${ipName}_synth_1
wait_on_run ${ipName}_synth_1
