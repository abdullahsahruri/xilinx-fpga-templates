#!/bin/bash
################################################################################
# FPGA Build Template Script
# Purpose: Build Xilinx FPGA designs using /tmp to avoid home directory quota
# Author: Created for C00535644
# Date: 2025-10-29
################################################################################

set -e  # Exit on error

################################################################################
# CONFIGURATION - Customize these for your project
################################################################################

# Project settings
PROJECT_NAME="${PROJECT_NAME:-my_fpga_project}"
KERNEL_NAME="${KERNEL_NAME:-my_kernel}"
SOURCE_FILE="${SOURCE_FILE:-kernel.cpp}"

# Xilinx settings
BOARD="${BOARD:-u200}"  # Default board: u200, u250, u280, u50, u55c, vck190, or custom
PLATFORM="${PLATFORM:-}"  # Will be auto-detected based on BOARD
TARGET="${TARGET:-hw_emu}"  # hw_emu, hw, sw_emu
OPTIMIZE_LEVEL="${OPTIMIZE_LEVEL:-3}"

# Directory settings
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
TMP_BUILD_ROOT="/tmp/${USER}_fpga_builds"
TMP_BUILD_DIR="${TMP_BUILD_ROOT}/${PROJECT_NAME}_$$"
RESULTS_DIR="${PROJECT_DIR}/results"

# Xilinx tools
VITIS_PATH="${VITIS_PATH:-/tools/Xilinx/Vitis/2024.2}"
XRT_PATH="${XRT_PATH:-/opt/xilinx/xrt}"
PLATFORM_PATH="${PLATFORM_PATH:-/opt/xilinx/platforms}"

################################################################################
# FUNCTIONS
################################################################################

print_banner() {
    echo "═══════════════════════════════════════════════════════════════════"
    echo "$1"
    echo "═══════════════════════════════════════════════════════════════════"
}

print_info() {
    echo "[INFO] $1"
}

print_error() {
    echo "[ERROR] $1" >&2
}

print_success() {
    echo "[✓] $1"
}

detect_platform() {
    print_info "Detecting platform for board: ${BOARD}"

    # Platform naming patterns for common boards
    case "${BOARD}" in
        u200)
            PLATFORM_PATTERN="xilinx_u200*"
            ;;
        u250)
            PLATFORM_PATTERN="xilinx_u250*"
            ;;
        u280)
            PLATFORM_PATTERN="xilinx_u280*"
            ;;
        u50)
            PLATFORM_PATTERN="xilinx_u50*"
            ;;
        u55c)
            PLATFORM_PATTERN="xilinx_u55c*"
            ;;
        vck190)
            PLATFORM_PATTERN="xilinx_vck190*"
            ;;
        *)
            # Custom platform - use as-is
            PLATFORM="${BOARD}"
            print_info "Using custom platform: ${PLATFORM}"
            return 0
            ;;
    esac

    # Search for platform in XRT and platform directories
    local found_platform=""

    # Try XRT platforms first
    if [ -d "${XRT_PATH}/platforms" ]; then
        found_platform=$(ls -d ${XRT_PATH}/platforms/${PLATFORM_PATTERN} 2>/dev/null | head -1 | xargs basename)
    fi

    # Try system platforms
    if [ -z "${found_platform}" ] && [ -d "${PLATFORM_PATH}" ]; then
        found_platform=$(ls -d ${PLATFORM_PATH}/${PLATFORM_PATTERN} 2>/dev/null | head -1 | xargs basename)
    fi

    # Try platforminfo
    if [ -z "${found_platform}" ]; then
        found_platform=$(platforminfo --list 2>/dev/null | grep -i "${BOARD}" | head -1 | awk '{print $1}')
    fi

    if [ -n "${found_platform}" ]; then
        PLATFORM="${found_platform}"
        print_success "Detected platform: ${PLATFORM}"
        return 0
    else
        print_error "Could not detect platform for board: ${BOARD}"
        print_info "Available platforms:"
        platforminfo --list 2>/dev/null || ls ${PLATFORM_PATH}/ ${XRT_PATH}/platforms/ 2>/dev/null
        return 1
    fi
}

setup_environment() {
    print_banner "Setting Up Build Environment"

    # Source Vitis
    if [ -f "${VITIS_PATH}/settings64.sh" ]; then
        print_info "Sourcing Vitis from ${VITIS_PATH}"
        source "${VITIS_PATH}/settings64.sh"
    else
        print_error "Vitis not found at ${VITIS_PATH}"
        exit 1
    fi

    # Source XRT if available
    if [ -f "${XRT_PATH}/setup.sh" ]; then
        print_info "Sourcing XRT from ${XRT_PATH}"
        source "${XRT_PATH}/setup.sh"
    fi

    # Detect platform based on board
    if ! detect_platform; then
        exit 1
    fi

    # Create temporary build directory
    print_info "Creating temporary build directory: ${TMP_BUILD_DIR}"
    mkdir -p "${TMP_BUILD_DIR}"
    mkdir -p "${RESULTS_DIR}"

    # Create results subdirectories
    mkdir -p "${RESULTS_DIR}/reports"
    mkdir -p "${RESULTS_DIR}/logs"
    mkdir -p "${RESULTS_DIR}/kernels"

    print_success "Environment setup complete"
}

check_prerequisites() {
    print_banner "Checking Prerequisites"

    # Check if source file exists
    if [ ! -f "${PROJECT_DIR}/${SOURCE_FILE}" ]; then
        print_error "Source file not found: ${PROJECT_DIR}/${SOURCE_FILE}"
        exit 1
    fi
    print_success "Source file found: ${SOURCE_FILE}"

    # Check disk space in /tmp
    local tmp_avail=$(df /tmp | tail -1 | awk '{print $4}')
    print_info "/tmp available space: ${tmp_avail} KB"

    if [ ${tmp_avail} -lt 5000000 ]; then
        print_error "Less than 5GB available in /tmp. Build may fail."
    fi

    # Check home directory space
    local home_avail=$(df "${HOME}" | tail -1 | awk '{print $4}')
    print_info "Home directory available: ${home_avail} KB"

    print_success "Prerequisites check complete"
}

run_hls_synthesis() {
    print_banner "Running HLS Synthesis"

    local start_time=$(date +%s)
    local output_xo="${TMP_BUILD_DIR}/${KERNEL_NAME}.xo"

    print_info "Project: ${PROJECT_NAME}"
    print_info "Kernel: ${KERNEL_NAME}"
    print_info "Source: ${SOURCE_FILE}"
    print_info "Platform: ${PLATFORM}"
    print_info "Target: ${TARGET}"
    print_info "Build directory: ${TMP_BUILD_DIR}"

    # Check for sw_emu deprecation
    if [ "${TARGET}" == "sw_emu" ]; then
        echo ""
        echo "╔═══════════════════════════════════════════════════════════════════════╗"
        echo "║                          DEPRECATION WARNING                          ║"
        echo "╠═══════════════════════════════════════════════════════════════════════╣"
        echo "║  sw_emu is DEPRECATED starting Vitis 2024.2                           ║"
        echo "║  sw_emu will be REMOVED in Vitis 2025.1                               ║"
        echo "║                                                                       ║"
        echo "║  RECOMMENDED: Use HLS C Simulation instead                            ║"
        echo "║    g++ -std=c++14 -I. kernel.cpp kernel_test.cpp -o test && ./test   ║"
        echo "║                                                                       ║"
        echo "║  Benefits:                                                            ║"
        echo "║    - 60x faster (seconds vs minutes)                                  ║"
        echo "║    - Standard C++ debugging (gdb, valgrind)                           ║"
        echo "║    - No Xilinx tool overhead                                          ║"
        echo "║    - CI/CD friendly                                                   ║"
        echo "║                                                                       ║"
        echo "║  Migration Guide: docs/SW_EMU_MIGRATION.md                            ║"
        echo "║  Xilinx Answer Record: 000036790                                      ║"
        echo "╚═══════════════════════════════════════════════════════════════════════╝"
        echo ""
        read -p "Continue with deprecated sw_emu build? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Build cancelled. Please migrate to HLS C Simulation."
            exit 0
        fi
    fi

    # Change to project directory (where source files are)
    cd "${PROJECT_DIR}"

    # Run v++ compilation with temp directory in /tmp
    print_info "Starting v++ compilation..."
    v++ -c -t ${TARGET} \
        --platform ${PLATFORM} \
        --save-temps \
        --temp_dir "${TMP_BUILD_DIR}/_x" \
        --optimize ${OPTIMIZE_LEVEL} \
        -k ${KERNEL_NAME} \
        -o "${output_xo}" \
        "${SOURCE_FILE}" \
        2>&1 | tee "${TMP_BUILD_DIR}/build.log"

    local build_status=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [ ${build_status} -eq 0 ]; then
        print_success "HLS synthesis completed in ${duration} seconds"
        return 0
    else
        print_error "HLS synthesis failed after ${duration} seconds"
        return 1
    fi
}

extract_results() {
    print_banner "Extracting Results"

    # Copy final .xo file to results
    if [ -f "${TMP_BUILD_DIR}/${KERNEL_NAME}.xo" ]; then
        cp "${TMP_BUILD_DIR}/${KERNEL_NAME}.xo" "${RESULTS_DIR}/kernels/"
        print_success "Copied ${KERNEL_NAME}.xo to results"
    fi

    # Copy HLS reports (try both locations: v++ puts reports in ${TMP_BUILD_DIR}/reports/)
    local reports_found=0

    # First try: ${TMP_BUILD_DIR}/reports/ (where v++ actually puts them)
    if [ -d "${TMP_BUILD_DIR}/reports" ]; then
        cp -r "${TMP_BUILD_DIR}/reports" "${RESULTS_DIR}/reports/${PROJECT_NAME}"
        print_success "Copied HLS reports from ${TMP_BUILD_DIR}/reports/"
        reports_found=1
    fi

    # Second try: ${TMP_BUILD_DIR}/_x/reports/ (legacy location)
    if [ -d "${TMP_BUILD_DIR}/_x/reports" ] && [ $reports_found -eq 0 ]; then
        cp -r "${TMP_BUILD_DIR}/_x/reports" "${RESULTS_DIR}/reports/${PROJECT_NAME}"
        print_success "Copied HLS reports from ${TMP_BUILD_DIR}/_x/reports/"
        reports_found=1
    fi

    if [ $reports_found -eq 0 ]; then
        print_info "No HLS reports found (this is normal for sw_emu)"
    fi

    # Copy logs
    if [ -f "${TMP_BUILD_DIR}/build.log" ]; then
        cp "${TMP_BUILD_DIR}/build.log" "${RESULTS_DIR}/logs/${PROJECT_NAME}_build.log"
        print_success "Copied build log to results"
    fi

    # Extract and display resource utilization (try both locations)
    local system_estimate=""

    # Try finding system estimate report
    if [ -d "${TMP_BUILD_DIR}/reports" ]; then
        system_estimate=$(find "${TMP_BUILD_DIR}/reports" -name "system_estimate_*.xtxt" 2>/dev/null | head -1)
    fi

    if [ -z "${system_estimate}" ] && [ -d "${TMP_BUILD_DIR}/_x/reports" ]; then
        system_estimate=$(find "${TMP_BUILD_DIR}/_x/reports" -name "system_estimate_*.xtxt" 2>/dev/null | head -1)
    fi

    if [ -n "${system_estimate}" ] && [ -f "${system_estimate}" ]; then
        print_info "Found system estimate: ${system_estimate}"
        print_info "Resource Utilization Summary:"
        echo ""

        # Save to a summary file
        local resource_summary="${RESULTS_DIR}/reports/${PROJECT_NAME}_resources.txt"
        echo "Resource Utilization for ${KERNEL_NAME}" > "${resource_summary}"
        echo "Generated: $(date)" >> "${resource_summary}"
        echo "===========================================" >> "${resource_summary}"
        cat "${system_estimate}" >> "${resource_summary}"

        # Display key resource lines
        grep -E "BRAM|DSP|FF|LUT|URAM" "${system_estimate}" | head -10 || \
        cat "${system_estimate}" | head -20

        echo ""
        print_success "Full resource report saved to: ${resource_summary}"
    else
        print_info "No system estimate report found (normal for sw_emu target)"
    fi

    print_success "Results extraction complete"
    print_info "Results saved to: ${RESULTS_DIR}"
}

cleanup() {
    print_banner "Cleaning Up"

    # Calculate space used
    local build_size=$(du -sh "${TMP_BUILD_DIR}" 2>/dev/null | awk '{print $1}')
    print_info "Temporary build directory size: ${build_size}"

    # Ask user before deleting
    if [ "${AUTO_CLEANUP}" = "yes" ]; then
        print_info "Auto-cleanup enabled, deleting ${TMP_BUILD_DIR}"
        rm -rf "${TMP_BUILD_DIR}"
        print_success "Cleanup complete"
    else
        echo ""
        read -p "Delete temporary build directory? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "${TMP_BUILD_DIR}"
            print_success "Cleanup complete"
        else
            print_info "Temporary files preserved at: ${TMP_BUILD_DIR}"
        fi
    fi
}

print_summary() {
    print_banner "Build Summary"

    echo ""
    echo "Project: ${PROJECT_NAME}"
    echo "Kernel: ${KERNEL_NAME}"
    echo "Results directory: ${RESULTS_DIR}"
    echo ""

    if [ -f "${RESULTS_DIR}/kernels/${KERNEL_NAME}.xo" ]; then
        local xo_size=$(ls -lh "${RESULTS_DIR}/kernels/${KERNEL_NAME}.xo" | awk '{print $5}')
        echo "Output kernel: ${RESULTS_DIR}/kernels/${KERNEL_NAME}.xo (${xo_size})"
    fi

    if [ -d "${RESULTS_DIR}/reports/${PROJECT_NAME}" ]; then
        local report_count=$(find "${RESULTS_DIR}/reports/${PROJECT_NAME}" -name "*.rpt" | wc -l)
        echo "Reports: ${report_count} files in ${RESULTS_DIR}/reports/${PROJECT_NAME}"
    fi

    echo ""
    print_success "Build workflow complete!"
}

################################################################################
# MAIN WORKFLOW
################################################################################

main() {
    print_banner "FPGA Build Workflow - ${PROJECT_NAME}"

    # Run workflow steps
    setup_environment
    check_prerequisites

    if run_hls_synthesis; then
        extract_results
        cleanup
        print_summary
        exit 0
    else
        print_error "Build failed. Check logs at ${TMP_BUILD_DIR}/build.log"
        print_info "Temporary files preserved at: ${TMP_BUILD_DIR}"
        exit 1
    fi
}

################################################################################
# TRAP SIGNALS
################################################################################

# Cleanup on exit/interrupt
trap 'print_error "Build interrupted"; exit 1' INT TERM

################################################################################
# USAGE
################################################################################

show_usage() {
    cat << EOF
FPGA Build Template Script

Usage: $0 [OPTIONS]

Options:
  -h, --help              Show this help message
  -p, --project NAME      Project name (default: my_fpga_project)
  -k, --kernel NAME       Kernel name (default: my_kernel)
  -s, --source FILE       Source file (default: kernel.cpp)
  -t, --target TYPE       Target type: hw_emu, hw, sw_emu (default: hw_emu)
  -P, --platform NAME     Platform name (default: xilinx_u200_gen3x16_xdma_2_202110_1)
  -o, --optimize LEVEL    Optimization level 0-3 (default: 3)
  -d, --dir PATH          Project directory (default: current directory)
  -b, --board BOARD       Board type: u200, u250, u280, etc. (default: u200)
  -c, --auto-cleanup      Automatically cleanup temp files

Environment Variables:
  VITIS_PATH              Path to Vitis installation (default: /tools/Xilinx/Vitis/2024.2)
  XRT_PATH                Path to XRT installation (default: /opt/xilinx/xrt)
  PLATFORM_PATH           Path to platforms (default: /opt/xilinx/platforms)

Examples:
  # Basic usage with default U200 board
  $0 -p my_project -k my_kernel -s kernel.cpp

  # Using U250 board
  $0 -p my_project -k my_kernel -s kernel.cpp -b u250

  # Full customization
  $0 -p my_project -k my_kernel -s kernel.cpp -t hw_emu -o 3 -b u200

  # With auto-cleanup
  $0 -p my_project -k my_kernel -s kernel.cpp -c

Directory Structure Created:
  \$HOME/results/
    ├── kernels/         (.xo files)
    ├── reports/         (HLS synthesis reports)
    └── logs/            (Build logs)

  /tmp/\${USER}_fpga_builds/  (temporary, auto-cleaned)

EOF
}

################################################################################
# PARSE ARGUMENTS
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -p|--project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -k|--kernel)
            KERNEL_NAME="$2"
            shift 2
            ;;
        -s|--source)
            SOURCE_FILE="$2"
            shift 2
            ;;
        -t|--target)
            TARGET="$2"
            shift 2
            ;;
        -P|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -o|--optimize)
            OPTIMIZE_LEVEL="$2"
            shift 2
            ;;
        -d|--dir)
            PROJECT_DIR="$2"
            shift 2
            ;;
        -b|--board)
            BOARD="$2"
            shift 2
            ;;
        -c|--auto-cleanup)
            AUTO_CLEANUP="yes"
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Run main workflow
main