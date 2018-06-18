#
# MEMSEC - Framework for building transparent memory encryption and authentication solutions.
# Copyright (C) 2017 Graz University of Technology, IAIK <mario.werner@iaik.tugraz.at>
#
# This file is part of MEMSEC.
#
# MEMSEC is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# MEMSEC is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with MEMSEC.  If not, see <http://www.gnu.org/licenses/>.
#
open_project $env(FLOW_MODULE).xpr

###############################################################################
# apply generics
###############################################################################
set generics ""
foreach index [array names env] {
  if {[string match "GENERIC_*" "$index"] == 0} {
    continue
  }
  set generic_name [string range "$index" [string length "GENERIC_"] [string length "$index"]]
  set generics "$generics $generic_name=$env($index)"
  puts "$generic_name=$env($index)"
}
set generics [string trim $generics]
set_property -name generic -value $generics -objects [get_filesets sources_1]

###############################################################################
# apply block design specific generics
###############################################################################
if { [info exists env(FLOW_VIVADO_BD_TCL_FILE)] == 1 } {
  # Update the config of cells in the block diagram with values from the environment
  # Every variable of the form FLOW_VIVADO_BD_GENERIC_<name>_AT_<cell>=<value> gets
  # applied to the open block design.
  foreach index [array names env] {
    if {[string match "FLOW_VIVADO_BD_GENERIC_*" "$index"] == 0} {
      continue
    }
    set generic_name_and_cell [string range "$index" [string length "FLOW_VIVADO_BD_GENERIC_"] [string length "$index"]]
    set generic_name [string range "$generic_name_and_cell" 0 [expr {[string first "_AT_" "$generic_name_and_cell"]-1}]]
    set generic_cell [string range "$generic_name_and_cell" [expr {[string first "_AT_" "$generic_name_and_cell"]+4}] [string length "$generic_name_and_cell"]]
    puts "$generic_name@$generic_cell=$env($index)"
    set_property -dict [list CONFIG.$generic_name "$env($index)"] [get_bd_cells $generic_cell]
  }

  save_bd_design
  generate_target all [get_files *.bd]
}

if { [info exists env(FLOW_VIVADO_GUI)] == 1 } {
  start_gui
}

# change the strategy when requested or reset incomplete or out of date run
if {[get_property strategy [get_runs synth_1]] != "$env(FLOW_VIVADO_SYNTH_STRATEGY)" } {
  puts "Switching synthesis strategy to $env(FLOW_VIVADO_SYNTH_STRATEGY)"
  set_property strategy "$env(FLOW_VIVADO_SYNTH_STRATEGY)" [get_runs synth_1]
  reset_run synth_1
} elseif {[get_property PROGRESS [get_runs synth_1]] != "100%" || [get_property NEEDS_REFRESH [get_runs synth_1]] != 0 } {
  reset_run synth_1
}

if {[get_property PROGRESS [get_runs synth_1]] != "100%" } {
  launch_runs synth_1
  wait_on_run synth_1
}

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
  error "ERROR: synthesis failed"
  close_project
  exit -1
} else {
  open_run synth_1
  write_checkpoint -force "$env(FLOW_BINARY_ROOT_DIR)/$env(FLOW_MODULE)-synth.dcp"
  report_timing_summary -file "$env(FLOW_BINARY_ROOT_DIR)/$env(FLOW_MODULE)-synth_timing_summary.txt" -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -input_pins
  report_utilization -hierarchical -file "$env(FLOW_BINARY_ROOT_DIR)/$env(FLOW_MODULE)-synth_utilization.txt"

  if { [info exists env(FLOW_VIVADO_GUI)] == 0 } {
    close_project
    exit 0
  }
}
