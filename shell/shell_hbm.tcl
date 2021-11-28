#Make the configurations needed depending on the flexibility the Shell wants to provide.
# For instance, pick between targets:

if { "$g_board_part" eq "u55c" } {
	set HBM_AXI_LABEL "_8HI"
} else {
	set HBM_AXI_LABEL ""
}

# source tcl/procedures.tcl
# source tcl/shell_env.tcl

# foreach dicEntry $ShellEnabledIntf {

	# set IntfName [dict get $dicEntry Name]
	
	# if {[regexp -inline -all "HBM" $IntfName] ne "" } {
		# set HBMentry $dicEntry
	# }
	
# }

putwarnings $HBMentry

set HBMClkNm [dict get $HBMentry SyncClk Label]
set HBMFreq  [dict get $HBMentry SyncClk Freq]
set HBMname  [dict get $HBMentry SyncClk Name]
set HBMintf  [dict get $HBMentry IntfLabel]
set HBMReady [dict get $HBMentry CalibDone]

set HBMaddrWidth [dict get $HBMentry AxiAddrWidth]
set HBMdataWidth [dict get $HBMentry AxiDataWidth]
set HBMidWidth   [dict get $HBMentry AxiIdWidth]


set hbm_axi4 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 hbm_axi4 ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH $HBMaddrWidth \
   CONFIG.ARUSER_WIDTH {0} \
   CONFIG.AWUSER_WIDTH {0} \
   CONFIG.BUSER_WIDTH {0} \
   CONFIG.DATA_WIDTH $HBMdataWidth \
   CONFIG.FREQ_HZ $HBMFreq \
   CONFIG.HAS_BRESP {1} \
   CONFIG.HAS_BURST {1} \
   CONFIG.HAS_CACHE {1} \
   CONFIG.HAS_LOCK {1} \
   CONFIG.HAS_PROT {1} \
   CONFIG.HAS_QOS {1} \
   CONFIG.HAS_REGION {1} \
   CONFIG.HAS_RRESP {1} \
   CONFIG.HAS_WSTRB {1} \
   CONFIG.ID_WIDTH $HBMidWidth \
   CONFIG.MAX_BURST_LENGTH {256} \
   CONFIG.NUM_READ_OUTSTANDING {1} \
   CONFIG.NUM_READ_THREADS {1} \
   CONFIG.NUM_WRITE_OUTSTANDING {1} \
   CONFIG.NUM_WRITE_THREADS {1} \
   CONFIG.PROTOCOL {AXI4} \
   CONFIG.READ_WRITE_MODE {READ_WRITE} \
   CONFIG.RUSER_BITS_PER_BYTE {0} \
   CONFIG.RUSER_WIDTH {0} \
   CONFIG.SUPPORTS_NARROW_BURST {1} \
   CONFIG.WUSER_BITS_PER_BYTE {0} \
   CONFIG.WUSER_WIDTH {0} \
   ] $hbm_axi4
   
## User clock
create_bd_port -dir O -type clk $HBMname
connect_bd_net [get_bd_ports $HBMname] [get_bd_pins clk_wiz_1/$HBMClkNm]

set_property name $HBMintf [get_bd_intf_ports hbm_axi4]
## Associate the clock with the user interface
## TODO: Looks like this doesn't work until smartConnect is connected
# putdebugs "Associated clock-intf: $HBMintf - $HBMname"
# set_property CONFIG.ASSOCIATED_BUSIF $HBMintf [get_bd_ports /$HBMname]

# save_bd_design 


## TODO: Make dependant of selected HBM channels number
create_bd_cell -type ip -vlnv xilinx.com:ip:hbm:1.0 hbm_0
set_property -dict [list CONFIG.USER_CLK_SEL_LIST0 {AXI_08_ACLK} \
	CONFIG.USER_SAXI_00 {false} \
	CONFIG.USER_SAXI_01 {false} \
	CONFIG.USER_SAXI_02 {false} \
	CONFIG.USER_SAXI_03 {false} \
	CONFIG.USER_SAXI_04 {false} \
	CONFIG.USER_SAXI_05 {false} \
	CONFIG.USER_SAXI_06 {false} \
	CONFIG.USER_SAXI_07 {false} \
	CONFIG.USER_SAXI_08 {true} \
	CONFIG.USER_SAXI_09 {false} \
	CONFIG.USER_SAXI_10 {false} \
	CONFIG.USER_SAXI_11 {false} \
	CONFIG.USER_SAXI_12 {false} \
	CONFIG.USER_SAXI_13 {false} \
	CONFIG.USER_SAXI_14 {false} \
	CONFIG.USER_SAXI_15 {false} \
	CONFIG.USER_APB_EN {false}] [get_bd_cells hbm_0]
	
	

	
create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.1 util_ds_buf_0
make_bd_intf_pins_external  [get_bd_intf_pins util_ds_buf_0/CLK_IN_D]
set_property name sysclk0 [get_bd_intf_ports CLK_IN_D_0]
connect_bd_net [get_bd_pins util_ds_buf_0/IBUF_OUT] [get_bd_pins hbm_0/HBM_REF_CLK_0]
### TODO: APB CLOCK Can't be the same as ACLK. Needs to be a different source
connect_bd_net [get_bd_pins hbm_0/AXI_08_ACLK] [get_bd_pins clk_wiz_1/$HBMClkNm]
connect_bd_net [get_bd_pins hbm_0/APB_0_PCLK] [get_bd_pins clk_wiz_1/$HBMClkNm]
#connect_bd_net [get_bd_pins rst_ea_domain/peripheral_aresetn] [get_bd_pins hbm_0/AXI_08_ARESET_N]
#connect_bd_net [get_bd_pins hbm_0/APB_0_PRESET_N] [get_bd_pins rst_ea_domain/peripheral_aresetn]
set hbm_cattrip [ create_bd_port -dir O -from 0 -to 0 hbm_cattrip ]
connect_bd_net [get_bd_ports hbm_cattrip] [get_bd_pins hbm_0/DRAM_0_STAT_CATTRIP]






## HBM Calibration Complete, 
## It can be used when it has been defined in the definition file

if { $HBMReady != ""} {
	make_bd_pins_external  [get_bd_pins hbm_0/apb_complete_0]
	set_property name $HBMReady [get_bd_ports apb_complete_0_0]
}



save_bd_design
