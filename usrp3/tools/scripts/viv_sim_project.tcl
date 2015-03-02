#
# Copyright 2014 Ettus Research
#

# ---------------------------------------
# Gather all external parameters
# ---------------------------------------
set simulator       $::env(VIV_SIMULATOR)
set design_srcs     $::env(VIV_DESIGN_SRCS)
set sim_srcs        $::env(VIV_SIM_SRCS)
set sim_top         $::env(VIV_SIM_TOP)
set part_name       $::env(VIV_PART_NAME)
set sim_runtime     $::env(VIV_SIM_RUNTIME)
set sim_fast        $::env(VIV_SIM_FAST)
set sim_complibdir  $::env(VIV_SIM_COMPLIBDIR)
set vivado_mode     $::env(VIV_MODE)
set working_dir     [pwd]

set sim_fileset "sim_1"
set project_name "[string tolower $simulator]_proj"

if {[expr [file isdirectory $sim_complibdir] == 0]} {
    set sim_complibdir  ""
    if [expr [string equal $simulator "XSim"] == 0] {
        puts "BUILDER: \[ERROR\]: Could not resolve the location for the compiled simulation libraries."
        puts "                  Please build libraries for chosen simulator and set the env or"
        puts "                  makefile variable SIM_COMPLIBDIR to point to the location."
        exit 1
    }
}

# ---------------------------------------
# Vivado Commands
# ---------------------------------------
puts "BUILDER: Creating Vivado simulation project part $part_name"
create_project -part $part_name -force $project_name/$project_name

foreach src_file $design_srcs {
    set src_ext [file extension $src_file ]
    if [expr [lsearch {.vhd .vhdl} $src_ext] >= 0] {
        puts "BUILDER: Adding VHDL    : $src_file"
        read_vhdl -library work $src_file
    } elseif [expr [lsearch {.v .vh} $src_ext] >= 0] {
        puts "BUILDER: Adding Verilog : $src_file"
        read_verilog $src_file
    } elseif [expr [lsearch {.sv} $src_ext] >= 0] {
        puts "BUILDER: Adding SVerilog: $src_file"
        read_verilog -sv $src_file
    } elseif [expr [lsearch {.xdc} $src_ext] >= 0] {
        puts "BUILDER: Adding XDC     : $src_file"
        read_xdc $src_file
    } elseif [expr [lsearch {.xci} $src_ext] >= 0] {
        puts "BUILDER: Adding IP      : $src_file"
        read_ip $src_file
    } elseif [expr [lsearch {.ngc .edif} $src_ext] >= 0] {
        puts "BUILDER: Adding Netlist : $src_file"
        read_edif $src_file
    } else {
        puts "BUILDER: \[WARNING\] File ignored!!!: $src_file"
    }
}

foreach sim_src $sim_srcs {
    puts "BUILDER: Adding Sim Src : $sim_src"
    add_files -fileset $sim_fileset -norecurse $sim_src
}

# Simulator independent config
set_property top $sim_top [get_filesets $sim_fileset]

# Vivado quirk when passing options to external simulators
if [expr [string equal $simulator "XSim"] == 1] {
    set_property verilog_define "SIM_RUNTIME_US=$sim_runtime WORKING_DIR=\"$working_dir\"" [get_filesets $sim_fileset]
} else {
    set_property verilog_define "SIM_RUNTIME_US=$sim_runtime WORKING_DIR=$working_dir" [get_filesets $sim_fileset]
}

# XSim specific settings
set_property xsim.simulate.runtime "${sim_runtime}us" -objects [get_filesets $sim_fileset]
set_property xsim.elaborate.debug_level "all" -objects [get_filesets $sim_fileset]
set_property xsim.elaborate.unifast $sim_fast -objects [get_filesets $sim_fileset]

# Modelsim specific settings
set_property compxlib.compiled_library_dir $sim_complibdir [current_project]
set_property modelsim.simulate.runtime "${sim_runtime}ns" -objects [get_filesets $sim_fileset]
set_property modelsim.elaborate.acc "true" -objects [get_filesets $sim_fileset]
set_property modelsim.simulate.log_all_signals} "true" -objects [get_filesets $sim_fileset]
set_property modelsim.simulate.vsim.more_options -value {-c} -objects [get_filesets $sim_fileset]
set_property modelsim.elaborate.unifast $sim_fast -objects [get_filesets $sim_fileset]

# Select the simulator and launch simulation
set_property target_simulator $simulator [current_project]
launch_simulation

if [string equal $vivado_mode "batch"] {
    puts "BUILDER: Closing project"
    close_project
} else {
    puts "BUILDER: In GUI mode. Leaving project open."
}
