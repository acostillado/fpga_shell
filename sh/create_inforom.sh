#!/bin/bash
set -e

#This executes without errors from the context of the Makefile, which is the one calling this script.
#It won't work when called from the scripts' context.

THIS_DIR=$(pwd) # ~/git_repo/fpga_shell
PARENT_DIR="$(dirname "$THIS_DIR")" #Returns to parent directory fpga_shell (git_repo)

SHELL_DEF_FILE="$THIS_DIR/accelerator/meep_shell/accelerator_def.csv"
FILE_GENERATED="$THIS_DIR/misc/initrom.mem" #primera prueba con txt

# This converts the date (from epoc) to hexadecimal value
printf '%x\r\n' $(date +%s) > "$FILE_GENERATED"
# This extracts the short SHA, which is 7 digits. We need to pad it
SHA_SHELL=$(git rev-parse --short HEAD)
PAD_SHA="0${SHA_SHELL}"

echo "$PAD_SHA" >> "$FILE_GENERATED"

cd "$THIS_DIR/accelerator"

# Do the same for the ACC SHA
SHA_ACC=$(git rev-parse --short HEAD)
PAD_SHA="0${SHA_ACC}"

echo "$PAD_SHA" >> "$FILE_GENERATED"
cd "$PARENT_DIR"

# The PCIe script should do the following:
# Convert to decimal the stored hexadecimal 
#printf '%d\n' `echo $output`
# ... so it can be read by date
#date --date @${output}


#stores [4 bytes]/[word] every row
#In ASCII, every letter occupies a [byte], so either I reduce the names, or padd them with an extra char

# Dynamically extract EANAME
awk -F= '/^EANAME=/ {print $2}' "$SHELL_DEF_FILE" | xxd -p -c 4 >> "$FILE_GENERATED"

append_feature() {
    local feature=$1
    local code=$2
    if grep -q "^${feature},yes," "$SHELL_DEF_FILE"; then
        echo -n "$code" | xxd -p -c 4 >> "$FILE_GENERATED"
    fi
}

append_feature "PCIE" "PCIE"
append_feature "DDR4" "DDR4"
append_feature "HBM" "HBMM"
append_feature "AURORA" "AURO"
append_feature "UART" "UART"
append_feature "ETHERNET" "ETHE"
append_feature "BROM" "BROM"
append_feature "BRAM" "BRAM"
