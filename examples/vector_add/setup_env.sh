#!/bin/bash
# Environment setup for vector_add example
# Usage: source setup_env.sh [phase]
#   phase: 1 (g++), 2 (csim), 3 (hw_emu), 4 (hw)
#   Default: phase 2 (sets up Vitis HLS for csim)

PHASE=${1:-2}

echo "========================================"
echo "Vector Add - Environment Setup"
echo "========================================"

case $PHASE in
    1)
        echo "Phase 1: g++ - No Xilinx tools needed"
        echo ""
        echo "Ready to run:"
        echo "  g++ -std=c++14 -O2 -I. vector_add.cpp test_vadd.cpp -o test_vadd"
        echo "  ./test_vadd"
        ;;

    2)
        echo "Phase 2: vitis-run --mode hls (csim)"
        echo ""

        # Check if Vitis is already sourced
        if command -v vitis-run &> /dev/null; then
            echo "Vitis HLS already available: $(which vitis-run)"
        else
            # Common Vitis installation paths
            VITIS_PATHS=(
                "/tools/Xilinx/Vitis/2024.2/settings64.sh"
                "/tools/Xilinx/Vitis/2024.1/settings64.sh"
                "/opt/Xilinx/Vitis/2024.2/settings64.sh"
                "/opt/Xilinx/Vitis/2024.1/settings64.sh"
            )

            FOUND=0
            for VPATH in "${VITIS_PATHS[@]}"; do
                if [ -f "$VPATH" ]; then
                    echo "Sourcing Vitis: $VPATH"
                    source "$VPATH"
                    FOUND=1
                    break
                fi
            done

            if [ $FOUND -eq 0 ]; then
                echo "WARNING: Vitis not found in common locations"
                echo "Please manually source your Vitis installation:"
                echo "  source /path/to/Vitis/settings64.sh"
                return 1
            fi
        fi

        echo ""
        echo "Ready to run:"
        echo "  vitis-run --mode hls --tcl csim.tcl"
        ;;

    3|4)
        if [ $PHASE -eq 3 ]; then
            echo "Phase 3: hw_emu"
        else
            echo "Phase 4: hw"
        fi
        echo ""

        # Check if Vitis is already sourced
        if command -v v++ &> /dev/null; then
            echo "Vitis already available: $(which v++)"
        else
            # Common Vitis installation paths
            VITIS_PATHS=(
                "/tools/Xilinx/Vitis/2024.2/settings64.sh"
                "/tools/Xilinx/Vitis/2024.1/settings64.sh"
                "/opt/Xilinx/Vitis/2024.2/settings64.sh"
                "/opt/Xilinx/Vitis/2024.1/settings64.sh"
            )

            FOUND=0
            for VPATH in "${VITIS_PATHS[@]}"; do
                if [ -f "$VPATH" ]; then
                    echo "Sourcing Vitis: $VPATH"
                    source "$VPATH"
                    FOUND=1
                    break
                fi
            done

            if [ $FOUND -eq 0 ]; then
                echo "WARNING: Vitis not found in common locations"
                echo "Please manually source your Vitis installation:"
                echo "  source /path/to/Vitis/settings64.sh"
                return 1
            fi
        fi

        # Set emulation mode for hw_emu
        if [ $PHASE -eq 3 ]; then
            export XCL_EMULATION_MODE=hw_emu
            echo "Set XCL_EMULATION_MODE=hw_emu"
        fi

        echo ""
        echo "Ready to run:"
        if [ $PHASE -eq 3 ]; then
            echo "  ../../fpga_build_template.sh -p vector_add -k vadd -s vector_add.cpp -b u200 -t hw_emu -c"
        else
            echo "  ../../fpga_build_template.sh -p vector_add -k vadd -s vector_add.cpp -b u200 -t hw -c"
        fi
        ;;

    *)
        echo "ERROR: Invalid phase: $PHASE"
        echo "Usage: source setup_env.sh [1|2|3|4]"
        echo "  1 = Phase 1 (g++)"
        echo "  2 = Phase 2 (vitis-run --mode hls)"
        echo "  3 = Phase 3 (hw_emu)"
        echo "  4 = Phase 4 (hw)"
        return 1
        ;;
esac

echo "========================================"
echo ""