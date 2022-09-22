#!/bin/bash

# mk_hdr.sh
# Redistributed URL: https://github.com/embeddedTS/linux-2.6.35.3-imx28/blob/master/mk_hdr.sh
#
# This program is distributed with mk_mx28_sd that has the text of 3-Clause BSD License.
# Both are considered to be licenced under the same agreement so we put the text here.

# Copyright (c) 2010 Freescale Semiconductor, Inc.
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
# 
# o Redistributions of source code must retain the above copyright notice, this list
#   of conditions and the following disclaimer.
#     
# o Redistributions in binary form must reproduce the above copyright notice, this
#   list of conditions and the following disclaimer in the documentation and/or
#   other materials provided with the distribution.
#    
# o Neither the name of Freescale Semiconductor, Inc. nor the names of its
#   contributors may be used to endorse or promote products derived from this
#   software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Usage:  make_boot <base_sector> <num_sb_files>
# 
# where
#
#  <base_sector> is the first sector _of the boot stream partition (i.e. /sd#2 or /sd#3, etc)
#  <num_sb_files> is the # of boot stream blocks (currently only 1 supported)

#[ $1 = ] && { echo -e " error - boot partition start sector missing"  ; exit };
#[ $2 = ] && { echo -e " error - # of bootable images in .sb file missing" ; exit };

# Future usage:  make_boot <dev_partition> <sb_file_tag,sb_sector_offset> <sb_file_tag2, base_addr2> ... 
#
# Where base sector comes from MBR, and sb_sector_offset is an offset from start of boot-partition, not absolute sector.


#Script Vars 
base_sector=$1
numbootstreams=$2
primary=0
secondary=0



#########################################
# out_byte args...  
# 
# this function writes the binary value to stdout of each argument in the order given
# i.e. out_byte 0 1 2 3  will echo "\x00\x01\x02\x03" to stdout (w/o  terminating null )

function out_byte(){
  for val in $* 
  	do
	# echo -e "byte=$val"
	echo -en "\\x$(printf %02x $val)"
  done
}


function out_u32_le()
{
  for val32 in $*
  	do

	val=$(($val32))
	b0=$((val % (2**8)))
	val=$((val / (2**8)))
	b1=$((val % (2**8)))
	val=$((val / (2**8)))
	b2=$((val % (2**8)))
	val=$((val / (2**8)))
	b3=$((val % (2**8)))

	### Keep around for debug/verbose output
 	# printf "$val32 ==> %02x%02x%02x%02x\n" $b0 $b1 $b2 $b3
	
	### Output the bytes in binary form
	#
  	out_byte  $b0 $b1 $b2 $b3

  done
}


function out_bcb ()
{
  signature=0x00112233
  primary_tag=$1
  secondary_tag=$2
  num_bsb=$3
  out_u32_le signature primary_tag secondary_tag num_bsb 
}

# usage:  out_bsb tag base_sector
# where base_sector is relative to partition 
# i.e. if partition starts on lba 63 & first boot stream, base_sector = 1, not 64
# This function will automatically compute the absolute base sector.
function out_bsb 
{
  abs_sector=$(($2 + $base_sector))
  # unused0
  out_u32_le 0 
  # unused1
  out_u32_le 0
  # tag  boot stream tag
  out_u32_le $1
  # boot stream base sector (absolute)
  out_u32_le $abs_sector
  # unused2
  out_u32_le 0
}


###############################
# Send header output to std out
###############################


# Output boot stream signature & info
# out_u32_le signature primary secondary numbootstreams 
out_bcb primary secondary numbootstreams

# Output .sb starting sector info 
# out_u32_le unused0 unused1 tag base_sector unused2
out_bsb primary 1 

# Output bsb for sb #2
#out_bsb tag_[p|s] base_sector_2

# Output bsb for sb #n
# out_bsb tag_[p|s] base_sector_n
# 

