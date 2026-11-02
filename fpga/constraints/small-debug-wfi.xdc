create_debug_core u_ila_0 ila




set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
startgroup
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0 ]
set_property C_ADV_TRIGGER true [get_debug_cores u_ila_0 ]
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0 ]
set_property ALL_PROBE_SAME_MU_CNT 4 [get_debug_cores u_ila_0 ]
endgroup
connect_debug_port u_ila_0/clk [get_nets CPUCLK]

set_property port_width 33 [get_debug_ports u_ila_0/probe0]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {wallypipelinedsoc/core/PCM[0]} {wallypipelinedsoc/core/PCM[1]} {wallypipelinedsoc/core/PCM[2]} {wallypipelinedsoc/core/PCM[3]} {wallypipelinedsoc/core/PCM[4]} {wallypipelinedsoc/core/PCM[5]} {wallypipelinedsoc/core/PCM[6]} {wallypipelinedsoc/core/PCM[7]} {wallypipelinedsoc/core/PCM[8]} {wallypipelinedsoc/core/PCM[9]} {wallypipelinedsoc/core/PCM[10]} {wallypipelinedsoc/core/PCM[11]} {wallypipelinedsoc/core/PCM[12]} {wallypipelinedsoc/core/PCM[13]} {wallypipelinedsoc/core/PCM[14]} {wallypipelinedsoc/core/PCM[15]} {wallypipelinedsoc/core/PCM[16]} {wallypipelinedsoc/core/PCM[17]} {wallypipelinedsoc/core/PCM[18]} {wallypipelinedsoc/core/PCM[19]} {wallypipelinedsoc/core/PCM[20]} {wallypipelinedsoc/core/PCM[21]} {wallypipelinedsoc/core/PCM[22]} {wallypipelinedsoc/core/PCM[23]} {wallypipelinedsoc/core/PCM[24]} {wallypipelinedsoc/core/PCM[25]} {wallypipelinedsoc/core/PCM[26]} {wallypipelinedsoc/core/PCM[27]} {wallypipelinedsoc/core/PCM[28]} {wallypipelinedsoc/core/PCM[29]} {wallypipelinedsoc/core/PCM[30]} {wallypipelinedsoc/core/PCM[31]} {wallypipelinedsoc/core/PCM[32]} } ]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe1]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list wallypipelinedsoc/core/TrapM ]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe2]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list wallypipelinedsoc/core/InstrValidM ]]

create_debug_port u_ila_0 probe
set_property port_width 32 [get_debug_ports u_ila_0/probe3]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {wallypipelinedsoc/core/InstrM[0]} {wallypipelinedsoc/core/InstrM[1]} {wallypipelinedsoc/core/InstrM[2]} {wallypipelinedsoc/core/InstrM[3]} {wallypipelinedsoc/core/InstrM[4]} {wallypipelinedsoc/core/InstrM[5]} {wallypipelinedsoc/core/InstrM[6]} {wallypipelinedsoc/core/InstrM[7]} {wallypipelinedsoc/core/InstrM[8]} {wallypipelinedsoc/core/InstrM[9]} {wallypipelinedsoc/core/InstrM[10]} {wallypipelinedsoc/core/InstrM[11]} {wallypipelinedsoc/core/InstrM[12]} {wallypipelinedsoc/core/InstrM[13]} {wallypipelinedsoc/core/InstrM[14]} {wallypipelinedsoc/core/InstrM[15]} {wallypipelinedsoc/core/InstrM[16]} {wallypipelinedsoc/core/InstrM[17]} {wallypipelinedsoc/core/InstrM[18]} {wallypipelinedsoc/core/InstrM[19]} {wallypipelinedsoc/core/InstrM[20]} {wallypipelinedsoc/core/InstrM[21]} {wallypipelinedsoc/core/InstrM[22]} {wallypipelinedsoc/core/InstrM[23]} {wallypipelinedsoc/core/InstrM[24]} {wallypipelinedsoc/core/InstrM[25]} {wallypipelinedsoc/core/InstrM[26]} {wallypipelinedsoc/core/InstrM[27]} {wallypipelinedsoc/core/InstrM[28]} {wallypipelinedsoc/core/InstrM[29]} {wallypipelinedsoc/core/InstrM[30]} {wallypipelinedsoc/core/InstrM[31]} ]]

create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe4]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {wallypipelinedsoc/core/lsu/MemRWM[0]} {wallypipelinedsoc/core/lsu/MemRWM[1]} ]]

create_debug_port u_ila_0 probe
set_property port_width 64 [get_debug_ports u_ila_0/probe5]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {wallypipelinedsoc/core/lsu/IEUAdrM[0]} {wallypipelinedsoc/core/lsu/IEUAdrM[1]} {wallypipelinedsoc/core/lsu/IEUAdrM[2]} {wallypipelinedsoc/core/lsu/IEUAdrM[3]} {wallypipelinedsoc/core/lsu/IEUAdrM[4]} {wallypipelinedsoc/core/lsu/IEUAdrM[5]} {wallypipelinedsoc/core/lsu/IEUAdrM[6]} {wallypipelinedsoc/core/lsu/IEUAdrM[7]} {wallypipelinedsoc/core/lsu/IEUAdrM[8]} {wallypipelinedsoc/core/lsu/IEUAdrM[9]} {wallypipelinedsoc/core/lsu/IEUAdrM[10]} {wallypipelinedsoc/core/lsu/IEUAdrM[11]} {wallypipelinedsoc/core/lsu/IEUAdrM[12]} {wallypipelinedsoc/core/lsu/IEUAdrM[13]} {wallypipelinedsoc/core/lsu/IEUAdrM[14]} {wallypipelinedsoc/core/lsu/IEUAdrM[15]} {wallypipelinedsoc/core/lsu/IEUAdrM[16]} {wallypipelinedsoc/core/lsu/IEUAdrM[17]} {wallypipelinedsoc/core/lsu/IEUAdrM[18]} {wallypipelinedsoc/core/lsu/IEUAdrM[19]} {wallypipelinedsoc/core/lsu/IEUAdrM[20]} {wallypipelinedsoc/core/lsu/IEUAdrM[21]} {wallypipelinedsoc/core/lsu/IEUAdrM[22]} {wallypipelinedsoc/core/lsu/IEUAdrM[23]} {wallypipelinedsoc/core/lsu/IEUAdrM[24]} {wallypipelinedsoc/core/lsu/IEUAdrM[25]} {wallypipelinedsoc/core/lsu/IEUAdrM[26]} {wallypipelinedsoc/core/lsu/IEUAdrM[27]} {wallypipelinedsoc/core/lsu/IEUAdrM[28]} {wallypipelinedsoc/core/lsu/IEUAdrM[29]} {wallypipelinedsoc/core/lsu/IEUAdrM[30]} {wallypipelinedsoc/core/lsu/IEUAdrM[31]} {wallypipelinedsoc/core/lsu/IEUAdrM[32]} {wallypipelinedsoc/core/lsu/IEUAdrM[33]} {wallypipelinedsoc/core/lsu/IEUAdrM[34]} {wallypipelinedsoc/core/lsu/IEUAdrM[35]} {wallypipelinedsoc/core/lsu/IEUAdrM[36]} {wallypipelinedsoc/core/lsu/IEUAdrM[37]} {wallypipelinedsoc/core/lsu/IEUAdrM[38]} {wallypipelinedsoc/core/lsu/IEUAdrM[39]} {wallypipelinedsoc/core/lsu/IEUAdrM[40]} {wallypipelinedsoc/core/lsu/IEUAdrM[41]} {wallypipelinedsoc/core/lsu/IEUAdrM[42]} {wallypipelinedsoc/core/lsu/IEUAdrM[43]} {wallypipelinedsoc/core/lsu/IEUAdrM[44]} {wallypipelinedsoc/core/lsu/IEUAdrM[45]} {wallypipelinedsoc/core/lsu/IEUAdrM[46]} {wallypipelinedsoc/core/lsu/IEUAdrM[47]} {wallypipelinedsoc/core/lsu/IEUAdrM[48]} {wallypipelinedsoc/core/lsu/IEUAdrM[49]} {wallypipelinedsoc/core/lsu/IEUAdrM[50]} {wallypipelinedsoc/core/lsu/IEUAdrM[51]} {wallypipelinedsoc/core/lsu/IEUAdrM[52]} {wallypipelinedsoc/core/lsu/IEUAdrM[53]} {wallypipelinedsoc/core/lsu/IEUAdrM[54]} {wallypipelinedsoc/core/lsu/IEUAdrM[55]} {wallypipelinedsoc/core/lsu/IEUAdrM[56]} {wallypipelinedsoc/core/lsu/IEUAdrM[57]} {wallypipelinedsoc/core/lsu/IEUAdrM[58]} {wallypipelinedsoc/core/lsu/IEUAdrM[59]} {wallypipelinedsoc/core/lsu/IEUAdrM[60]} {wallypipelinedsoc/core/lsu/IEUAdrM[61]} {wallypipelinedsoc/core/lsu/IEUAdrM[62]} {wallypipelinedsoc/core/lsu/IEUAdrM[63]} ]]

create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe6]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {wallypipelinedsoc/core/lsu/ReadDataM[0]} {wallypipelinedsoc/core/lsu/ReadDataM[1]} {wallypipelinedsoc/core/lsu/ReadDataM[2]} {wallypipelinedsoc/core/lsu/ReadDataM[3]} {wallypipelinedsoc/core/lsu/ReadDataM[4]} {wallypipelinedsoc/core/lsu/ReadDataM[5]} {wallypipelinedsoc/core/lsu/ReadDataM[6]} {wallypipelinedsoc/core/lsu/ReadDataM[7]}  ]]

create_debug_port u_ila_0 probe
set_property port_width 8 [get_debug_ports u_ila_0/probe7]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {wallypipelinedsoc/core/lsu/WriteDataM[0]} {wallypipelinedsoc/core/lsu/WriteDataM[1]} {wallypipelinedsoc/core/lsu/WriteDataM[2]} {wallypipelinedsoc/core/lsu/WriteDataM[3]} {wallypipelinedsoc/core/lsu/WriteDataM[4]} {wallypipelinedsoc/core/lsu/WriteDataM[5]} {wallypipelinedsoc/core/lsu/WriteDataM[6]} {wallypipelinedsoc/core/lsu/WriteDataM[7]}  ]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {wallypipelinedsoc/core/priv.priv/csr/csri/MExtInt}]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {wallypipelinedsoc/core/priv.priv/csr/csri/SExtInt} ]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {wallypipelinedsoc/core/priv.priv/pmd/wfiM} ]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {wallypipelinedsoc/core/priv.priv/pmd/WaitedM} ]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/INTR ]]


create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe13]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/txfifohead[0]} {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/txfifohead[1]} {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/txfifohead[2]} {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/txfifohead[3]}]]


create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/txsrfull}]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/txhrfull}]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/RXRDYb ]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/txfifofull}]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/txfifoempty}]]


create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list {wallypipelinedsoc/core/priv.priv/pmd/TWTimeoutM} ]]

create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe20]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/plic.plic/requests[1]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/requests[2]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/requests[3]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/requests[4]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/requests[5]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/requests[6]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/requests[7]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/requests[8]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/requests[9]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/requests[10]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/requests[11]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/requests[12]}]]

create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe21]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/IER[0]} {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/IER[1]} {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/IER[2]} {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/IER[3]} ]]

create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe22]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/plic.plic/intInProgress[1]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intInProgress[2]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intInProgress[3]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intInProgress[4]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intInProgress[5]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intInProgress[6]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intInProgress[7]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intInProgress[8]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intInProgress[9]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intInProgress[10]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intInProgress[11]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intInProgress[12]}]]

create_debug_port u_ila_0 probe
set_property port_width 12 [get_debug_ports u_ila_0/probe23]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/plic.plic/intPending[1]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intPending[2]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intPending[3]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intPending[4]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intPending[5]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intPending[6]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intPending[7]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intPending[8]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intPending[9]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intPending[10]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intPending[11]} {wallypipelinedsoc/uncoregen.uncore/plic.plic/intPending[12]}]]

create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe24]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/txstate[0]} {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/txstate[1]} ]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe25]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/rxdataready} ]]

create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe26]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/txfifotail[0]} {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/txfifotail[1]} {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/txfifotail[2]} {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/txfifotail[3]}]]


create_debug_port u_ila_0 probe
set_property port_width 2 [get_debug_ports u_ila_0/probe27]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/rxstate[0]} {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/rxstate[1]} ]]

create_debug_port u_ila_0 probe
set_property port_width 4 [get_debug_ports u_ila_0/probe28]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/rxfifoentries[0]} {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/rxfifoentries[1]} {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/rxfifoentries[2]} {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/rxfifoentries[3]} ]]

create_debug_port u_ila_0 probe
set_property port_width 3 [get_debug_ports u_ila_0/probe29]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe29]
connect_debug_port u_ila_0/probe29 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/intrID[0]} {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/intrID[1]} {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/intrID[2]} ]]

create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe30]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe30]
connect_debug_port u_ila_0/probe30 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/rxfifotriggered} ]]


create_debug_port u_ila_0 probe
set_property port_width 1 [get_debug_ports u_ila_0/probe31]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe31]
connect_debug_port u_ila_0/probe31 [get_nets [list {wallypipelinedsoc/uncoregen.uncore/uartgen.uart/uartPC/fifoenabled} ]]




# the debug hub has issues with the clocks from the mmcm so lets give up an connect to the 100Mhz input clock.
#connect_debug_port dbg_hub/clk [get_nets default_100mhz_clk]
connect_debug_port dbg_hub/clk [get_nets CPUCLK]
