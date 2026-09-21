create_generated_clock -name SPISDCClock -source [get_pins mmcm/clk_out3] -multiply_by 1 -divide_by 1 [get_pins wallypipelinedsoc/uncoregen.uncore/SDCCLK]

##### clock #####
# Nexys A7-100T CLK100MHZ
set_property PACKAGE_PIN E3 [get_ports default_100mhz_clk]
set_property IOSTANDARD LVCMOS33 [get_ports default_100mhz_clk]

##### UART #####
set_property PACKAGE_PIN C4 [get_ports UARTSin]
set_property PACKAGE_PIN D4 [get_ports UARTSout]
set_property IOSTANDARD LVCMOS33 [get_ports UARTSin]
set_property IOSTANDARD LVCMOS33 [get_ports UARTSout]
set_property DRIVE 4 [get_ports UARTSout]

##### Simple GPI/GPO mapping to on-board buttons/LEDs #####
# Map GPO[0..4] to LD0..LD4
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports {GPO[0]}]
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVCMOS33} [get_ports {GPO[1]}]
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports {GPO[2]}]
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports {GPO[3]}]
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {GPO[4]}]

# Map GPI[0..3] to BTNC/BTNU/BTNL/BTNR
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports {GPI[0]}] ;# BTNC
set_property -dict {PACKAGE_PIN M18 IOSTANDARD LVCMOS33} [get_ports {GPI[1]}] ;# BTNU
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports {GPI[2]}] ;# BTNL
set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVCMOS33} [get_ports {GPI[3]}] ;# BTNR

##### reset #####
set_property PACKAGE_PIN C12 [get_ports resetn]
set_property IOSTANDARD LVCMOS33 [get_ports resetn]


# Micro SD Connector
set_property PULLTYPE PULLUP [get_ports SDCCS]
set_property PULLTYPE PULLUP [get_ports SDCIn]
set_property PULLTYPE PULLUP [get_ports SDCCmd]
set_property PULLTYPE PULLUP [get_ports SDCCD]
#set_property PULLTYPE PULLUP [get_ports SDCCLK]
#set_property PULLTYPE PULLUP [get_ports SDCWP]
set_output_delay -clock [get_clocks SPISDCClock] -min -add_delay 2.500 [get_ports {SDCCS}]
set_output_delay -clock [get_clocks SPISDCClock] -max -add_delay 10.000 [get_ports {SDCCS}]
set_input_delay -clock [get_clocks SPISDCClock] -min -add_delay 2.500 [get_ports {SDCIn}]
set_input_delay -clock [get_clocks SPISDCClock] -max -add_delay 10.000 [get_ports {SDCIn}]
set_output_delay -clock [get_clocks SPISDCClock] -min -add_delay 2.000 [get_ports {SDCCmd}]
set_output_delay -clock [get_clocks SPISDCClock] -max -add_delay 6.000 [get_ports {SDCCmd}]
set_output_delay -clock [get_clocks SPISDCClock] 0.000 [get_ports SDCCLK]

set_property -dict { PACKAGE_PIN B1 IOSTANDARD LVCMOS33 } [get_ports SDCCLK]  ;# SD_SCK
set_property -dict { PACKAGE_PIN C1 IOSTANDARD LVCMOS33 } [get_ports SDCCmd]  ;# SD_CMD
set_property -dict { PACKAGE_PIN C2 IOSTANDARD LVCMOS33 } [get_ports SDCIn]   ;# SD_DAT0 (MISO)
set_property -dict { PACKAGE_PIN D2 IOSTANDARD LVCMOS33 } [get_ports SDCCS]   ;# SD_DAT3 (CS)
set_property -dict { PACKAGE_PIN A1 IOSTANDARD LVCMOS33 } [get_ports SDCCD]   ;# SD_CD
set_property -dict { PACKAGE_PIN E2 IOSTANDARD LVCMOS33 } [get_ports SD_RESET];# SD_RESET (JD6, NC Digilent micro SD adapter?)
# no SDCWP



##### Ethernet #####
# Nexys A7 has LAN8720A in RMII (not the MII-style pinout Arty assumes),
# keep the whole Arty “phy_*” block DISABLED

##### DDR2 #####
set_property IO_BUFFER_TYPE NONE [get_ports {ddr2_ck_n[*]} ]
set_property IO_BUFFER_TYPE NONE [get_ports {ddr2_ck_p[*]} ]

#create_clock -period 5 [get_ports sys_clk_i]

# PadFunction: IO_L23P_T3_34
set_property SLEW FAST [get_ports {ddr2_dq[0]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[0]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[0]}]
set_property PACKAGE_PIN R7 [get_ports {ddr2_dq[0]}]

# PadFunction: IO_L20N_T3_34
set_property SLEW FAST [get_ports {ddr2_dq[1]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[1]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[1]}]
set_property PACKAGE_PIN V6 [get_ports {ddr2_dq[1]}]

# PadFunction: IO_L24P_T3_34
set_property SLEW FAST [get_ports {ddr2_dq[2]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[2]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[2]}]
set_property PACKAGE_PIN R8 [get_ports {ddr2_dq[2]}]

# PadFunction: IO_L22P_T3_34
set_property SLEW FAST [get_ports {ddr2_dq[3]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[3]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[3]}]
set_property PACKAGE_PIN U7 [get_ports {ddr2_dq[3]}]

# PadFunction: IO_L20P_T3_34
set_property SLEW FAST [get_ports {ddr2_dq[4]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[4]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[4]}]
set_property PACKAGE_PIN V7 [get_ports {ddr2_dq[4]}]

# PadFunction: IO_L19P_T3_34
set_property SLEW FAST [get_ports {ddr2_dq[5]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[5]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[5]}]
set_property PACKAGE_PIN R6 [get_ports {ddr2_dq[5]}]

# PadFunction: IO_L22N_T3_34
set_property SLEW FAST [get_ports {ddr2_dq[6]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[6]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[6]}]
set_property PACKAGE_PIN U6 [get_ports {ddr2_dq[6]}]

# PadFunction: IO_L19N_T3_VREF_34
set_property SLEW FAST [get_ports {ddr2_dq[7]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[7]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[7]}]
set_property PACKAGE_PIN R5 [get_ports {ddr2_dq[7]}]

# PadFunction: IO_L12P_T1_MRCC_34
set_property SLEW FAST [get_ports {ddr2_dq[8]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[8]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[8]}]
set_property PACKAGE_PIN T5 [get_ports {ddr2_dq[8]}]

# PadFunction: IO_L8N_T1_34
set_property SLEW FAST [get_ports {ddr2_dq[9]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[9]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[9]}]
set_property PACKAGE_PIN U3 [get_ports {ddr2_dq[9]}]

# PadFunction: IO_L10P_T1_34
set_property SLEW FAST [get_ports {ddr2_dq[10]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[10]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[10]}]
set_property PACKAGE_PIN V5 [get_ports {ddr2_dq[10]}]

# PadFunction: IO_L8P_T1_34
set_property SLEW FAST [get_ports {ddr2_dq[11]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[11]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[11]}]
set_property PACKAGE_PIN U4 [get_ports {ddr2_dq[11]}]

# PadFunction: IO_L10N_T1_34
set_property SLEW FAST [get_ports {ddr2_dq[12]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[12]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[12]}]
set_property PACKAGE_PIN V4 [get_ports {ddr2_dq[12]}]

# PadFunction: IO_L12N_T1_MRCC_34
set_property SLEW FAST [get_ports {ddr2_dq[13]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[13]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[13]}]
set_property PACKAGE_PIN T4 [get_ports {ddr2_dq[13]}]

# PadFunction: IO_L7N_T1_34
set_property SLEW FAST [get_ports {ddr2_dq[14]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[14]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[14]}]
set_property PACKAGE_PIN V1 [get_ports {ddr2_dq[14]}]

# PadFunction: IO_L11N_T1_SRCC_34
set_property SLEW FAST [get_ports {ddr2_dq[15]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dq[15]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dq[15]}]
set_property PACKAGE_PIN T3 [get_ports {ddr2_dq[15]}]

# PadFunction: IO_L18N_T2_34
set_property SLEW FAST [get_ports {ddr2_addr[12]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[12]}]
set_property PACKAGE_PIN N6 [get_ports {ddr2_addr[12]}]

# PadFunction: IO_L5P_T0_34
set_property SLEW FAST [get_ports {ddr2_addr[11]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[11]}]
set_property PACKAGE_PIN K5 [get_ports {ddr2_addr[11]}]

# PadFunction: IO_L15N_T2_DQS_34
set_property SLEW FAST [get_ports {ddr2_addr[10]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[10]}]
set_property PACKAGE_PIN R2 [get_ports {ddr2_addr[10]}]

# PadFunction: IO_L13P_T2_MRCC_34
set_property SLEW FAST [get_ports {ddr2_addr[9]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[9]}]
set_property PACKAGE_PIN N5 [get_ports {ddr2_addr[9]}]

# PadFunction: IO_L5N_T0_34
set_property SLEW FAST [get_ports {ddr2_addr[8]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[8]}]
set_property PACKAGE_PIN L4 [get_ports {ddr2_addr[8]}]

# PadFunction: IO_L3N_T0_DQS_34
set_property SLEW FAST [get_ports {ddr2_addr[7]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[7]}]
set_property PACKAGE_PIN N1 [get_ports {ddr2_addr[7]}]

# PadFunction: IO_L4N_T0_34
set_property SLEW FAST [get_ports {ddr2_addr[6]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[6]}]
set_property PACKAGE_PIN M2 [get_ports {ddr2_addr[6]}]

# PadFunction: IO_L13N_T2_MRCC_34
set_property SLEW FAST [get_ports {ddr2_addr[5]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[5]}]
set_property PACKAGE_PIN P5 [get_ports {ddr2_addr[5]}]

# PadFunction: IO_L2N_T0_34
set_property SLEW FAST [get_ports {ddr2_addr[4]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[4]}]
set_property PACKAGE_PIN L3 [get_ports {ddr2_addr[4]}]

# PadFunction: IO_L17N_T2_34
set_property SLEW FAST [get_ports {ddr2_addr[3]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[3]}]
set_property PACKAGE_PIN T1 [get_ports {ddr2_addr[3]}]

# PadFunction: IO_L18P_T2_34
set_property SLEW FAST [get_ports {ddr2_addr[2]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[2]}]
set_property PACKAGE_PIN M6 [get_ports {ddr2_addr[2]}]

# PadFunction: IO_L14P_T2_SRCC_34
set_property SLEW FAST [get_ports {ddr2_addr[1]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[1]}]
set_property PACKAGE_PIN P4 [get_ports {ddr2_addr[1]}]

# PadFunction: IO_L16P_T2_34
set_property SLEW FAST [get_ports {ddr2_addr[0]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_addr[0]}]
set_property PACKAGE_PIN M4 [get_ports {ddr2_addr[0]}]

# PadFunction: IO_L17P_T2_34
set_property SLEW FAST [get_ports {ddr2_ba[2]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_ba[2]}]
set_property PACKAGE_PIN R1 [get_ports {ddr2_ba[2]}]

# PadFunction: IO_L14N_T2_SRCC_34
set_property SLEW FAST [get_ports {ddr2_ba[1]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_ba[1]}]
set_property PACKAGE_PIN P3 [get_ports {ddr2_ba[1]}]

# PadFunction: IO_L15P_T2_DQS_34
set_property SLEW FAST [get_ports {ddr2_ba[0]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_ba[0]}]
set_property PACKAGE_PIN P2 [get_ports {ddr2_ba[0]}]

# PadFunction: IO_L16N_T2_34
set_property SLEW FAST [get_ports {ddr2_ras_n}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_ras_n}]
set_property PACKAGE_PIN N4 [get_ports {ddr2_ras_n}]

# PadFunction: IO_L1P_T0_34
set_property SLEW FAST [get_ports {ddr2_cas_n}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_cas_n}]
set_property PACKAGE_PIN L1 [get_ports {ddr2_cas_n}]

# PadFunction: IO_L3P_T0_DQS_34
set_property SLEW FAST [get_ports {ddr2_we_n}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_we_n}]
set_property PACKAGE_PIN N2 [get_ports {ddr2_we_n}]

# PadFunction: IO_L1N_T0_34
set_property SLEW FAST [get_ports {ddr2_cke[0]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_cke[0]}]
set_property PACKAGE_PIN M1 [get_ports {ddr2_cke[0]}]

# PadFunction: IO_L4P_T0_34
set_property SLEW FAST [get_ports {ddr2_odt[0]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_odt[0]}]
set_property PACKAGE_PIN M3 [get_ports {ddr2_odt[0]}]

# PadFunction: IO_0_34
set_property SLEW FAST [get_ports {ddr2_cs_n[0]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_cs_n[0]}]
set_property PACKAGE_PIN K6 [get_ports {ddr2_cs_n[0]}]

# PadFunction: IO_L23N_T3_34
set_property SLEW FAST [get_ports {ddr2_dm[0]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dm[0]}]
set_property PACKAGE_PIN T6 [get_ports {ddr2_dm[0]}]

# PadFunction: IO_L7P_T1_34
set_property SLEW FAST [get_ports {ddr2_dm[1]}]
set_property IOSTANDARD SSTL18_II [get_ports {ddr2_dm[1]}]
set_property PACKAGE_PIN U1 [get_ports {ddr2_dm[1]}]

# PadFunction: IO_L21P_T3_DQS_34
set_property SLEW FAST [get_ports {ddr2_dqs_p[0]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dqs_p[0]}]
set_property IOSTANDARD DIFF_SSTL18_II [get_ports {ddr2_dqs_p[0]}]
set_property PACKAGE_PIN U9 [get_ports {ddr2_dqs_p[0]}]

# PadFunction: IO_L21N_T3_DQS_34
set_property SLEW FAST [get_ports {ddr2_dqs_n[0]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dqs_n[0]}]
set_property IOSTANDARD DIFF_SSTL18_II [get_ports {ddr2_dqs_n[0]}]
set_property PACKAGE_PIN V9 [get_ports {ddr2_dqs_n[0]}]

# PadFunction: IO_L9P_T1_DQS_34
set_property SLEW FAST [get_ports {ddr2_dqs_p[1]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dqs_p[1]}]
set_property IOSTANDARD DIFF_SSTL18_II [get_ports {ddr2_dqs_p[1]}]
set_property PACKAGE_PIN U2 [get_ports {ddr2_dqs_p[1]}]

# PadFunction: IO_L9N_T1_DQS_34
set_property SLEW FAST [get_ports {ddr2_dqs_n[1]}]
set_property IN_TERM UNTUNED_SPLIT_50 [get_ports {ddr2_dqs_n[1]}]
set_property IOSTANDARD DIFF_SSTL18_II [get_ports {ddr2_dqs_n[1]}]
set_property PACKAGE_PIN V2 [get_ports {ddr2_dqs_n[1]}]

# PadFunction: IO_L6P_T0_34
set_property SLEW FAST [get_ports {ddr2_ck_p[0]}]
set_property IOSTANDARD DIFF_SSTL18_II [get_ports {ddr2_ck_p[0]}]
set_property PACKAGE_PIN L6 [get_ports {ddr2_ck_p[0]}]

# PadFunction: IO_L6N_T0_VREF_34
set_property SLEW FAST [get_ports {ddr2_ck_n[0]}]
set_property IOSTANDARD DIFF_SSTL18_II [get_ports {ddr2_ck_n[0]}]
set_property PACKAGE_PIN L5 [get_ports {ddr2_ck_n[0]}]


set_property INTERNAL_VREF  0.900 [get_iobanks 34]


set_property LOC PHASER_OUT_PHY_X1Y7 [get_cells  -hier -filter {NAME =~ */ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_D.ddr_byte_lane_D/phaser_out}]
set_property LOC PHASER_OUT_PHY_X1Y5 [get_cells  -hier -filter {NAME =~ */ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_B.ddr_byte_lane_B/phaser_out}]
set_property LOC PHASER_OUT_PHY_X1Y6 [get_cells  -hier -filter {NAME =~ */ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_C.ddr_byte_lane_C/phaser_out}]
set_property LOC PHASER_OUT_PHY_X1Y4 [get_cells  -hier -filter {NAME =~ */ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_A.ddr_byte_lane_A/phaser_out}]


## set_property LOC PHASER_IN_PHY_X1Y7 [get_cells  -hier -filter {NAME =~ */ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_D.ddr_byte_lane_D/phaser_in_gen.phaser_in}]
## set_property LOC PHASER_IN_PHY_X1Y5 [get_cells  -hier -filter {NAME =~ */ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_B.ddr_byte_lane_B/phaser_in_gen.phaser_in}]
set_property LOC PHASER_IN_PHY_X1Y6 [get_cells  -hier -filter {NAME =~ */ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_C.ddr_byte_lane_C/phaser_in_gen.phaser_in}]
set_property LOC PHASER_IN_PHY_X1Y4 [get_cells  -hier -filter {NAME =~ */ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_A.ddr_byte_lane_A/phaser_in_gen.phaser_in}]





set_property LOC OUT_FIFO_X1Y7 [get_cells  -hier -filter {NAME =~ */ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_D.ddr_byte_lane_D/out_fifo}]
set_property LOC OUT_FIFO_X1Y5 [get_cells  -hier -filter {NAME =~ */ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_B.ddr_byte_lane_B/out_fifo}]
set_property LOC OUT_FIFO_X1Y6 [get_cells  -hier -filter {NAME =~ */ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_C.ddr_byte_lane_C/out_fifo}]
set_property LOC OUT_FIFO_X1Y4 [get_cells  -hier -filter {NAME =~ */ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_A.ddr_byte_lane_A/out_fifo}]


set_property LOC IN_FIFO_X1Y6 [get_cells  -hier -filter {NAME =~ */ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_C.ddr_byte_lane_C/in_fifo_gen.in_fifo}]
set_property LOC IN_FIFO_X1Y4 [get_cells  -hier -filter {NAME =~ */ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_A.ddr_byte_lane_A/in_fifo_gen.in_fifo}]


set_property LOC PHY_CONTROL_X1Y1 [get_cells  -hier -filter {NAME =~ */ddr_phy_4lanes_0.u_ddr_phy_4lanes/phy_control_i}]


set_property LOC PHASER_REF_X1Y1 [get_cells  -hier -filter {NAME =~ */ddr_phy_4lanes_0.u_ddr_phy_4lanes/phaser_ref_i}]


set_property LOC OLOGIC_X1Y81 [get_cells  -hier -filter {NAME =~ */ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_C.ddr_byte_lane_C/ddr_byte_group_io/*slave_ts}]
set_property LOC OLOGIC_X1Y57 [get_cells  -hier -filter {NAME =~ */ddr_phy_4lanes_0.u_ddr_phy_4lanes/ddr_byte_lane_A.ddr_byte_lane_A/ddr_byte_group_io/*slave_ts}]



set_property LOC PLLE2_ADV_X1Y1 [get_cells -hier -filter {NAME =~ */u_ddr2_infrastructure/plle2_i}]
set_property LOC MMCME2_ADV_X1Y1 [get_cells -hier -filter {NAME =~ */u_ddr2_infrastructure/gen_mmcm.mmcm_i}]




set_false_path -through [get_pins -filter {NAME =~ */DQSFOUND} -of [get_cells -hier -filter {REF_NAME == PHASER_IN_PHY}]]

set_multicycle_path -through [get_pins -filter {NAME =~ */OSERDESRST} -of [get_cells -hier -filter {REF_NAME == PHASER_OUT_PHY}]] -setup 2 -start
set_multicycle_path -through [get_pins -filter {NAME =~ */OSERDESRST} -of [get_cells -hier -filter {REF_NAME == PHASER_OUT_PHY}]] -hold 1 -start

#set_max_delay -datapath_only -from [get_cells -hier -filter {NAME =~ *temp_mon_enabled.u_tempmon/* && IS_SEQUENTIAL}] -to [get_cells -hier -filter {NAME =~ *temp_mon_enabled.u_tempmon/device_temp_sync_r1*}] 20
set_max_delay -to [get_pins -hier -include_replicated_objects -filter {NAME =~ *temp_mon_enabled.u_tempmon/device_temp_sync_r1_reg[*]/D}] 20
set_max_delay -from [get_cells -hier *rstdiv0_sync_r1_reg*] -to [get_pins -filter {NAME =~ */RESET} -of [get_cells -hier -filter {REF_NAME == PHY_CONTROL}]] -datapath_only 5
#set_false_path -through [get_pins -hier -filter {NAME =~ */u_iodelay_ctrl/sys_rst}]
set_false_path -through [get_nets -hier -filter {NAME =~ */u_iodelay_ctrl/sys_rst_i}]


# DDR2 calibration finished signal CDC
set_false_path -to [get_pins {ddr_ready_cpu_sync_reg[0]/D}]
