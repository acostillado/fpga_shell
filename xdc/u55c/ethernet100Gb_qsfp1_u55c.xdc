# Physicall constraints

set_property PACKAGE_PIN AB43       [get_ports "qsfp_ref_clk_n"] ;# Bank 131 - MGTREFCLK0N_131
set_property PACKAGE_PIN AB42       [get_ports "qsfp_ref_clk_p"] ;# Bank 131 - MGTREFCLK0P_131


# Timing constraints
set_false_path -from [get_pins {meep_shell_inst/MEEP_100Gb_Ethernet_0/inst/tx_rx_ctl_stat/U0/gpio_core_1/Dual.gpio_Data_Out_reg[*]/C}]  		
