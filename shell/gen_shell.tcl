# Copyright 2022 Barcelona Supercomputing Center-Centro Nacional de Supercomputación

# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or, at your option, the Apache License version 2.0.
# You may obtain a copy of the License at
# 
#     http://www.solderpad.org/licenses/SHL-2.1
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Author: Daniel J.Mazure, BSC-CNS
# Date: 22.02.2022
# Description: 


## TODO: Cover repeated interfaces: 2 AURORA, 2 ETHERNET... etc.
## 	   : Incompatibilities: Can't use 2 Aurora and 2 Ethernet (Limited QSFP)

set g_system_file   $g_root_dir/interfaces/system.sv
set g_pcie_file     $g_root_dir/interfaces/pcie.sv
set g_ddr4_file     $g_root_dir/interfaces/ddr4.sv
set g_aurora0_file  $g_root_dir/interfaces/aurora0.sv
set g_aurora1_file  $g_root_dir/interfaces/aurora1.sv
set g_Eth0_file     $g_root_dir/interfaces/ethernet0.sv
set g_Eth1_file     $g_root_dir/interfaces/ethernet1.sv
set g_Eth100Gb_file $g_root_dir/interfaces/eth100gb.sv
set g_uart_file     $g_root_dir/interfaces/uart.sv

# Create a list with the physical ports file handler
# When an interface is detected, the file path is added to the list
# That list will be used to create the top level ports in the module
# definition. The list is updated inside the shell_<inft>.tcl files

set PortList [list]

# Source the shell definition parameters
source $g_root_dir/tcl/shell_env.tcl

# Create the Vivado block desing structure & placeholder
source $g_root_dir/shell/shell_base.tcl

# Create the clock structure
source $g_root_dir/shell/shell_mmcm.tcl
# Added by definition
add_files -fileset [get_filesets constrs_1] "$g_root_dir/xdc/$g_board_part/hbm_${g_board_part}.xdc"

##if {[info exists $shellIntf]} 

# Source procedures once before the loop
source $g_root_dir/shell/shell_qdma.tcl
source $g_root_dir/shell/shell_ddr4.tcl
source $g_root_dir/shell/shell_hbm.tcl
if { [file exists $g_root_dir/shell/shell_100GbEthernet.tcl] } {
    source $g_root_dir/shell/shell_100GbEthernet.tcl
}
source $g_root_dir/shell/shell_aurora.tcl

set config_dict [dict create \
    PortList $PortList \
    g_pcie_file     $g_pcie_file \
    g_ddr4_file     $g_ddr4_file \
    g_aurora0_file  $g_aurora0_file \
    g_aurora1_file  $g_aurora1_file \
    g_Eth100Gb_file $g_Eth100Gb_file \
    g_root_dir      $g_root_dir \
    g_board_part    $g_board_part \
    meep_util_ds_buf xilinx.com:ip:util_ds_buf:2.2 \
    pcieBlockLoc    "X1Y2" \
    g_ip_version    "1.0" \
    HBM_AXI_LABEL   "" \
    slv_axi_ninstances 0 \
    PCIeDMAdone 0 \
    HBMaddrWidth 33 \
    HBMDensity "8GB" \
    APBclkCandidate "" \
    APBclk "" \
    APBClockPin "" \
    APBRstPin "" \
    pcie_clk_pin "" \
    pcie_rst_pin "" \
]

foreach dicEntry $ShellEnabledIntf {

	set IntfName [dict get $dicEntry Name]

	if {[regexp -inline -all "PCIE" $IntfName] ne "" } {
        set PCIEentry $dicEntry
        dict set config_dict PCIEentry $PCIEentry

        # Instantiate QDMA
        set config_dict [instantiate_qdma $config_dict "qdma_0"]

        add_files -fileset [get_filesets constrs_1] "$g_root_dir/xdc/$g_board_part/qdma_${g_board_part}.xdc"

        set PCIeDMA [dict get $PCIEentry Mode]
        set PCIeHBMCh [dict get $PCIEentry HBMChan]
    }

		
	if {[regexp -inline -all "DDR4" $IntfName] ne "" } {
		set DDR4entry $dicEntry
        dict set config_dict DDR4entry $DDR4entry

        set config_dict [instantiate_ddr4 $config_dict]

		add_files -fileset [get_filesets constrs_1] "$g_root_dir/xdc/$g_board_part/ddr4_${g_board_part}.xdc"
        
        set DDR4ClkNm [dict get $DDR4entry ClkName]
        set DDR4intf [dict get $DDR4entry IntfLabel]
        set_property CONFIG.ASSOCIATED_BUSIF [get_property CONFIG.ASSOCIATED_BUSIF [get_bd_ports /$DDR4ClkNm]]$DDR4intf: [get_bd_ports /$DDR4ClkNm]

	} 
	
	if {[regexp -inline -all "HBM" $IntfName] ne "" } {
		set HBMentry $dicEntry
        dict set config_dict HBMentry $HBMentry

        set config_dict [instantiate_hbm $config_dict "hbm_0"]
        set hbm_inst "hbm_0"
	}

	if {[regexp -inline -all "UART" $IntfName] ne "" } {
		set UARTentry $dicEntry
		source $g_root_dir/shell/shell_uart.tcl
		add_files -fileset [get_filesets constrs_1] "$g_root_dir/xdc/$g_board_part/uart_${g_board_part}.xdc"		
	}

	if {[regexp -inline -all "ETHERNET" $IntfName] ne "" } {
		set ETHentry $dicEntry
        dict set config_dict ETHentry $ETHentry

		set ETHrate  [dict get $ETHentry GbEth]
		set ETHqsfp  [dict get $ETHentry qsfpPort]
        set ETHdmaMem [dict get $ETHentry dmaMem]
        set EthHBMCh [dict get $ETHentry HBMChan]

        if { $ETHrate == "100" } {
            set config_dict [instantiate_100gb_ethernet $config_dict "Eth100GbSyst_w_${ETHdmaMem}"]
        } else {
		    source $g_root_dir/shell/shell_${ETHrate}Ethernet.tcl
        }

		if { $ETHqsfp != "pcie" } {
		add_files -fileset [get_filesets constrs_1] "$g_root_dir/xdc/$g_board_part/ethernet${ETHrate}_${ETHqsfp}_${g_board_part}.xdc"
	        } else {
		source $g_root_dir/shell/shell_eth2pci.tcl
		}	

	}
	if {[regexp -inline -all "AURORA" $IntfName] ne "" } {
		set AURORAentry $dicEntry
        dict set config_dict AURORAentry $AURORAentry

        set config_dict [instantiate_aurora $config_dict]
        
        set AuroraQSFP [dict get $AURORAentry qsfpPort]
        set AuroradmaMem [dict get $AURORAentry dmaMem]
        set AuroraHBMCh [dict get $AURORAentry HBMChan]

		add_files -fileset [get_filesets constrs_1] "$g_root_dir/xdc/$g_board_part/aurora_${AuroraQSFP}_${g_board_part}.xdc"		
	}
    if {[regexp -inline -all "JTAG" $IntfName] ne "" } {
      set JTAGentry $dicEntry
      source $g_root_dir/shell/shell_jtag.tcl
	}
	if {[regexp -inline -all "BROM" $IntfName] ne "" } {
		set BROMentry $dicEntry
		source $g_root_dir/shell/shell_brom.tcl
	}
	if {[regexp -inline -all "BRAM" $IntfName] ne "" } {
			set BRAMentry $dicEntry
			source $g_root_dir/shell/shell_bram.tcl
	}
	if {[regexp -inline -all "SLV_AXI" $IntfName] ne "" } {
		set SLVAXIentry $dicEntry
		source $g_root_dir/shell/shell_slvaxi.tcl	
		set_property CONFIG.ASSOCIATED_BUSIF [get_property CONFIG.ASSOCIATED_BUSIF [get_bd_ports /$g_SLVAXI_CLK]]$g_SLVAXI_ifname: [get_bd_ports /$g_SLVAXI_CLK]
	}
	
}

#Extract modified portlist for later code:
set PortList [dict get $config_dict PortList]

#GEnerate IF GPIO: Inside the tcl

source $g_root_dir/shell/shell_gpio.tcl

if { [info exists hbm_inst] && [info exists AuroradmaMem] && $AuroradmaMem eq "hbm"} {
  set AurHBMSwitch [expr $AuroraHBMCh/16]
  putmeeps "Setting Aurora clock to drive HBM cross-switch $AurHBMSwitch through channel $AuroraHBMCh"
  set_property -dict [list CONFIG.USER_CLK_SEL_LIST${AurHBMSwitch} AXI_${AuroraHBMCh}_ACLK] [get_bd_cells hbm_0]
}
if { [info exists hbm_inst] && [info exists PCIeDMA] && $PCIeDMA eq "dma"} {
  set PCIeHBMSwitch [expr $PCIeHBMCh/16]
  putmeeps "Setting PCIe clock to drive HBM cross-switch $PCIeHBMSwitch through channel $PCIeHBMCh"
  set_property -dict [list CONFIG.USER_CLK_SEL_LIST${PCIeHBMSwitch} AXI_${PCIeHBMCh}_ACLK] [get_bd_cells hbm_0]
}
if { [info exists hbm_inst] && [info exists ETHdmaMem] && $ETHdmaMem eq "hbm"} {
  set EthHBMSwitch [expr $EthHBMCh/16]
  putmeeps "Setting Eth clock to drive HBM cross-switch $EthHBMSwitch through channel $EthHBMCh"
  set_property -dict [list CONFIG.USER_CLK_SEL_LIST${EthHBMSwitch} AXI_${EthHBMCh}_ACLK] [get_bd_cells hbm_0]
}

### TODO: Catch
source $g_root_dir/shell/shell_memmap.tcl

update_ip_catalog -rebuild -scan_changes
 
save_bd_design 

