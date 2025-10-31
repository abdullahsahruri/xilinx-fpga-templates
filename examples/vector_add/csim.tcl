# Vitis HLS C Simulation Script
# Phase 2: Validate synthesizability before hw_emu
#
# Usage: vitis-run --mode hls --tcl csim.tcl
#
# This validates that your kernel can be synthesized to hardware:
# - Checks for unsupported C++ features
# - Validates HLS pragmas (PIPELINE, INTERFACE, etc.)
# - Ensures data types are synthesizable
#

# Create new project (reset if exists)
open_project -reset vadd_hls

# Add kernel source file
add_files vector_add.cpp

# Add testbench (not synthesized, only used for simulation)
add_files -tb test_vadd.cpp

# Specify top-level function to synthesize
set_top vadd

# Open solution with configuration
open_solution "solution1" -flow_target vitis

# Set target FPGA part (change to match your board)
# U200: xcu200-fsgd2104-2-e
# U250: xcu250-figd2104-2L-e
# U280: xcu280-fsvh2892-2L-e
set_part {xcu200-fsgd2104-2-e}

# Create clock constraint (300 MHz = 3.33ns period)
create_clock -period 3.33 -name default

# Run C Simulation
# This validates:
# - Functional correctness
# - HLS pragma syntax
# - Synthesizability of C++ code
csim_design -clean

# Optional: Run C Synthesis to get resource estimates
# Uncomment to see LUT/FF/BRAM usage
# csynth_design

# Optional: Run C/RTL Co-simulation to validate RTL matches C
# Uncomment for full validation (takes longer)
# cosim_design

# Exit HLS
exit