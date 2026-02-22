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


set RED "\033\[1;31m"
set GREEN "\033\[1;32m"
set YELLOW "\033\[1;33m"
set CYAN "\033\[1;36m"
set RESET "\033\[0m"



proc putcolors { someText color } {

	set RESET "\033\[0m"

	puts "${color}\[MEEP\] INFO: ${someText}${RESET}"

}

proc putmeeps { someText } {        

	puts "\[MEEP\] INFO: ${someText}"

}

proc puterrors { someText } {

	set RED "\033\[1;31m"
	set RESET "\033\[0m"

	puts "${RED}\[MEEP\]\ ERROR: ${RESET}${someText}"
	
	return 1
}

proc putwarnings { someText } {

	set YELLOW "\033\[1;33m"
	set RESET "\033\[0m"

	puts "${YELLOW}\[MEEP\]\ WARNING: ${RESET}${someText}"
}

proc putdebugs { someText } {

	global DebugEnable

	set CYAN "\033\[1;36m"
	set RESET "\033\[0m"
	
	if { $DebugEnable == "True" } {
		puts "${CYAN}\[MEEP\]\ DEBUG: ${RESET}${someText}"
	}
}



####################################################
# Replace a matching Line in a file when it matches
# the input value
####################################################

proc updateFile {path2file match replace} {

	set tmp_file ${path2file}.tmp
	
	set fd_file [open $path2file "r"]
	set fd_tmp  [open $tmp_file  "w"]
	
	while {[gets $fd_file line] >= 0} {
	
		set newline [regsub -line "$match.*" $line $replace]
		if { $newline == "" } {
			set newline $line
		}
		puts $fd_tmp $newline	
	}

	close $fd_file
	close $fd_tmp
	
	file copy -force $tmp_file $path2file
	file delete -force $tmp_file

}

proc Add2EnvFile {path2file addString} {
	
	set fd_file [open $path2file "a"]
	
	puts $fd_file $addString
	
	close $fd_file	
}

proc Add2ConstrFileList {path2file addStringList} {
	
	set fd_file [open $path2file "a"]

	foreach StringIn $addStringList {
	
		puts $fd_file $StringIn

	}
	
	close $fd_file	
}

proc AddClk2MMCM { ClockList ConfMMCMString NewClk} {

	set ClkNameNew [lindex $NewClk 0]
	set ClkFreqNew [lindex $NewClk 1]


	putdebugs $ClkNameNew
	putdebugs $ClkFreqNew

	set NewClockList $ClockList
	set NewConfMMCMString $ConfMMCMString

	putdebugs $NewClockList 
	putdebugs $NewConfMMCMString 

    ### +2 because the list is at this point one element short and because
    ### The Clock wizard numeration differs and doesn't have a 0
    set numClk [string trimleft [dict get [lindex $ClockList end] ClkNum] CLK]
    set d_clock [dict create Name CLK$[llength $ClockList]]
        
    dict set d_clock ClkNum  CLK[incr numClk]
    dict set d_clock ClkFreq $ClkFreqNew
    dict set d_clock ClkName $ClkNameNew
	dict set d_clock ClkRst ""
	dict set d_clock ClkRstPol ""

    set NewClockList [lappend NewClockList $d_clock]

    putdebugs "Adding $ClkNameNew Clk to the list: $NewClockList"

	set ClkFreqMHz [expr $ClkFreqNew/1000000 ]

	incr numClk	

    set ConfMMCM "CONFIG.CLKOUT${numClk}_USED true "
    append NewConfMMCMString "$ConfMMCM"

    set ConfMMCM "CONFIG.CLKOUT${numClk}_REQUESTED_OUT_FREQ $ClkFreqMHz "
    append NewConfMMCMString "$ConfMMCM"

	set RetMMCM [list $NewClockList $NewConfMMCMString]

    #set name [gets stdin]

	return $RetMMCM


}

proc formatHBMch { HBMChannel } {

	set HBMChannelFormatted $HBMChannel

	if { [string length $HBMChannel] == 1 } {
		# Append a 0 for those values that are passed as a single number
		# This makes the AXI HBM Connections easier.
		putdebugs "Formatting HBM Channel numbering to be two digits long"
		set HBMChannelFormatted "0${HBMChannel}"		
	}

	if { [string length $HBMChannel] > 2 } {
		puterrors "HBM Channels with three or more digits doesn't make sense"
	}

	return $HBMChannelFormatted
}
