#!/bin/bash
# Copyright 2022 Barcelona Supercomputing Center-Centro Nacional de Supercomputación

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Author: Daniel J.Mazure, BSC-CNS
# Date: 22.02.2022
# Description: 


#!/bin/bash

FILENAME=$1
#FILESIZE=$(stat -c%s $FILENAME)
FILESIZE=$(du -b $FILENAME | cut -f1)

echo -e "Booting using $FILENAME image file which is $FILESIZE bytes\r\n"

dma-ctl qdma08000 reg write bar 2 0x0 0x0 
sleep 1 
dma-to-device -d /dev/qdma08000-MM-1 -s $FILESIZE -a 0x80000000 -f $FILENAME #load the bbl into main memory.
dma-ctl qdma08000 reg write bar 2 0x0 0x1 #Release Lagarto's reset
