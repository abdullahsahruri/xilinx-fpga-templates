#!/bin/bash
################################################################################
# FPGA Templates - Environment Setup
#
# Purpose: Source all necessary Xilinx tools and set platform environment
# Usage: source setup_env.sh [platform] [mode]
#
# Arguments:
#   platform: u200, u250, u280, u50, u55c, vck190 (default: u200)
#   mode:     sw_emu, hw_emu, hw (default: hw_emu)
#
# Examples:
#   source setup_env.sh                  # u200, hw_emu mode
#   source setup_env.sh u280             # u280, hw_emu mode
#   source setup_env.sh u200 hw          # u200, hw mode
################################################################################

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
PLATFORM=${1:-u200}
MODE=${2:-hw_emu}

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}FPGA Templates - Environment Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Function to find Vitis installation
find_vitis() {
    # Common Vitis installation paths
    local VITIS_PATHS=(
        "/tools/Xilinx/Vitis/2024.2"
        "/tools/Xilinx/Vitis/2024.1"
        "/opt/Xilinx/Vitis/2024.2"
        "/opt/Xilinx/Vitis/2024.1"
        "/opt/xilinx/Vitis/2024.2"
        "/opt/xilinx/Vitis/2024.1"
        "$HOME/Xilinx/Vitis/2024.2"
        "$HOME/Xilinx/Vitis/2024.1"
    )

    for VPATH in "${VITIS_PATHS[@]}"; do
        if [ -f "${VPATH}/settings64.sh" ]; then
            echo "$VPATH"
            return 0
        fi
    done

    return 1
}

# Function to find XRT installation
find_xrt() {
    # Common XRT installation paths
    local XRT_PATHS=(
        "/opt/xilinx/xrt"
        "/opt/Xilinx/xrt"
        "/usr/local/xrt"
    )

    for XPATH in "${XRT_PATHS[@]}"; do
        if [ -f "${XPATH}/setup.sh" ]; then
            echo "$XPATH"
            return 0
        fi
    done

    return 1
}

# Function to get full platform name
get_platform_full_name() {
    local board=$1
    case $board in
        u200)
            echo "xilinx_u200_gen3x16_xdma_2_202110_1"
            ;;
        u250)
            echo "xilinx_u250_gen3x16_xdma_4_1_202210_1"
            ;;
        u280)
            echo "xilinx_u280_gen3x16_xdma_1_202211_1"
            ;;
        u50)
            echo "xilinx_u50_gen3x16_xdma_5_202210_1"
            ;;
        u55c)
            echo "xilinx_u55c_gen3x16_xdma_3_202210_1"
            ;;
        vck190)
            echo "xilinx_vck190_base_202310_1"
            ;;
        *)
            echo ""
            ;;
    esac
}

# 1. Check if Vitis is already sourced
if command -v v++ &> /dev/null; then
    VITIS_VERSION=$(v++ --version 2>&1 | head -1 | awk '{print $2}')
    echo -e "${GREEN}✓ Vitis already available${NC}"
    echo "  Version: $VITIS_VERSION"
    echo "  Path: $(which v++)"
else
    # Find and source Vitis
    VITIS_PATH=$(find_vitis)
    if [ -n "$VITIS_PATH" ]; then
        echo -e "${YELLOW}→ Sourcing Vitis: ${VITIS_PATH}/settings64.sh${NC}"
        source "${VITIS_PATH}/settings64.sh" > /dev/null 2>&1

        if command -v v++ &> /dev/null; then
            VITIS_VERSION=$(v++ --version 2>&1 | head -1 | awk '{print $2}')
            echo -e "${GREEN}✓ Vitis sourced successfully${NC}"
            echo "  Version: $VITIS_VERSION"
        else
            echo -e "${RED}✗ Failed to source Vitis${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Vitis not found in common locations${NC}"
        echo ""
        echo "Please manually source your Vitis installation:"
        echo "  source /path/to/Vitis/settings64.sh"
        echo "  source setup_env.sh"
        return 1
    fi
fi

echo ""

# 2. Check if XRT is already sourced
if [ -n "$XILINX_XRT" ]; then
    echo -e "${GREEN}✓ XRT already available${NC}"
    echo "  Path: $XILINX_XRT"
else
    # Find and source XRT
    XRT_PATH=$(find_xrt)
    if [ -n "$XRT_PATH" ]; then
        echo -e "${YELLOW}→ Sourcing XRT: ${XRT_PATH}/setup.sh${NC}"
        source "${XRT_PATH}/setup.sh" > /dev/null 2>&1

        if [ -n "$XILINX_XRT" ]; then
            echo -e "${GREEN}✓ XRT sourced successfully${NC}"
            echo "  Path: $XILINX_XRT"
        else
            echo -e "${YELLOW}⚠ XRT sourcing may have failed${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ XRT not found (optional for compile-only workflows)${NC}"
    fi
fi

echo ""

# 3. Set target platform
PLATFORM_FULL=$(get_platform_full_name "$PLATFORM")

if [ -n "$PLATFORM_FULL" ]; then
    export PLATFORM_REPO_PATHS="/opt/xilinx/platforms"
    export FPGA_TARGET_PLATFORM="$PLATFORM_FULL"

    echo -e "${GREEN}✓ Target platform set${NC}"
    echo "  Board: $PLATFORM"
    echo "  Full name: $PLATFORM_FULL"
else
    echo -e "${YELLOW}⚠ Unknown platform: $PLATFORM${NC}"
    echo "  Supported: u200, u250, u280, u50, u55c, vck190"
    echo "  Continuing without platform setup..."
fi

echo ""

# 4. Set emulation mode
if [ "$MODE" = "sw_emu" ]; then
    echo -e "${RED}✗ sw_emu is no longer supported${NC}"
    echo "  sw_emu was removed in Vitis 2025.1"
    echo ""
    echo "  Use Phase 1 & 2 workflow instead:"
    echo "    Phase 1 (g++):        Fast C++ testing (seconds)"
    echo "    Phase 2 (vitis_hls):  HLS C Simulation (minutes)"
    echo "    Phase 3 (hw_emu):     Hardware emulation (hours)"
    echo "    Phase 4 (hw):         Hardware build (production)"
    return 1
fi

export XCL_EMULATION_MODE="$MODE"
echo -e "${GREEN}✓ Emulation mode set${NC}"
echo "  Mode: $MODE"

case $MODE in
    hw_emu)
        echo "  Purpose: Hardware emulation (resource estimates, performance)"
        ;;
    hw)
        echo "  Purpose: Hardware build (actual implementation)"
        ;;
    *)
        echo -e "${YELLOW}  Note: Only hw_emu and hw modes are supported${NC}"
        ;;
esac

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Environment setup complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "You can now run:"
echo "  ./fpga_build_template.sh -p myproject -k mykernel -s kernel.cpp -b $PLATFORM -t $MODE"
echo "  ./fpga_run_template.sh -p myproject -x results/kernels/mykernel.xo -H host.cpp -B $PLATFORM -t $MODE"
echo ""
echo "Extract resources:"
echo "  ./fpga_extract_resources.sh --all"
echo ""
echo "Clean up builds:"
echo "  ./fpga_cleanup_builds.sh"
echo ""