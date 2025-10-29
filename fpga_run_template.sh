#!/bin/bash
################################################################################
# FPGA Run Template Script
# Purpose: Link kernels and run FPGA designs (emulation or hardware)
# Date: 2025-10-29
################################################################################

set -e  # Exit on error

################################################################################
# CONFIGURATION - Customize these for your project
################################################################################

# Project settings
PROJECT_NAME="${PROJECT_NAME:-my_fpga_project}"
BINARY_CONTAINER="${BINARY_CONTAINER:-binary_container.xclbin}"
HOST_EXE="${HOST_EXE:-host.exe}"

# Xilinx settings
BOARD="${BOARD:-u200}"
PLATFORM="${PLATFORM:-}"  # Will be auto-detected based on BOARD
TARGET="${TARGET:-hw_emu}"  # hw_emu, hw, sw_emu

# Directory settings
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
TMP_BUILD_ROOT="/tmp/${USER}_fpga_runs"
TMP_RUN_DIR="${TMP_BUILD_ROOT}/${PROJECT_NAME}_$$"
RESULTS_DIR="${PROJECT_DIR}/results"

# Kernel settings
KERNEL_XO_FILES="${KERNEL_XO_FILES:-}"  # Space-separated .xo files
HOST_SOURCE="${HOST_SOURCE:-host.cpp}"  # Host source file

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
    print_banner "Setting Up Run Environment"

    # Source Vitis
    if [ -f "${VITIS_PATH}/settings64.sh" ]; then
        print_info "Sourcing Vitis from ${VITIS_PATH}"
        source "${VITIS_PATH}/settings64.sh"
    else
        print_error "Vitis not found at ${VITIS_PATH}"
        exit 1
    fi

    # Source XRT
    if [ -f "${XRT_PATH}/setup.sh" ]; then
        print_info "Sourcing XRT from ${XRT_PATH}"
        source "${XRT_PATH}/setup.sh"
    else
        print_error "XRT not found at ${XRT_PATH}"
        exit 1
    fi

    # Detect platform based on board
    if ! detect_platform; then
        exit 1
    fi

    # Create temporary run directory
    print_info "Creating temporary run directory: ${TMP_RUN_DIR}"
    mkdir -p "${TMP_RUN_DIR}"
    mkdir -p "${RESULTS_DIR}"

    print_success "Environment setup complete"
}

check_prerequisites() {
    print_banner "Checking Prerequisites"

    # Check if kernel .xo files exist
    if [ -z "${KERNEL_XO_FILES}" ]; then
        print_error "No kernel .xo files specified. Use -x or --xo flag."
        exit 1
    fi

    for xo_file in ${KERNEL_XO_FILES}; do
        if [ ! -f "${xo_file}" ]; then
            print_error "Kernel file not found: ${xo_file}"
            exit 1
        fi
        print_success "Found kernel: $(basename ${xo_file})"
    done

    # Check if host source exists
    if [ ! -f "${PROJECT_DIR}/${HOST_SOURCE}" ]; then
        print_error "Host source not found: ${PROJECT_DIR}/${HOST_SOURCE}"
        exit 1
    fi
    print_success "Found host source: ${HOST_SOURCE}"

    # Check disk space in /tmp
    local tmp_avail=$(df /tmp | tail -1 | awk '{print $4}')
    print_info "/tmp available space: ${tmp_avail} KB"

    if [ ${tmp_avail} -lt 10000000 ]; then
        print_error "Less than 10GB available in /tmp. Link may fail."
    fi

    print_success "Prerequisites check complete"
}

link_kernels() {
    print_banner "Linking Kernels to Binary Container"

    local start_time=$(date +%s)
    local output_xclbin="${TMP_RUN_DIR}/${BINARY_CONTAINER}"

    print_info "Project: ${PROJECT_NAME}"
    print_info "Platform: ${PLATFORM}"
    print_info "Target: ${TARGET}"
    print_info "Kernel files: ${KERNEL_XO_FILES}"
    print_info "Output: ${BINARY_CONTAINER}"

    # Run v++ linking with temp directory in /tmp
    print_info "Starting v++ linking..."
    v++ -l -t ${TARGET} \
        --platform ${PLATFORM} \
        --save-temps \
        --temp_dir "${TMP_RUN_DIR}/_x" \
        -o "${output_xclbin}" \
        ${KERNEL_XO_FILES} \
        2>&1 | tee "${TMP_RUN_DIR}/link.log"

    local link_status=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [ ${link_status} -eq 0 ]; then
        print_success "Linking completed in ${duration} seconds"

        # Copy xclbin to project directory
        cp "${output_xclbin}" "${PROJECT_DIR}/"
        print_success "Copied ${BINARY_CONTAINER} to ${PROJECT_DIR}"

        return 0
    else
        print_error "Linking failed after ${duration} seconds"
        return 1
    fi
}

compile_host() {
    print_banner "Compiling Host Code"

    local start_time=$(date +%s)
    local output_exe="${PROJECT_DIR}/${HOST_EXE}"

    print_info "Host source: ${HOST_SOURCE}"
    print_info "Output: ${HOST_EXE}"

    # Change to project directory
    cd "${PROJECT_DIR}"

    # Compile host code with XRT libraries
    print_info "Starting host compilation..."
    g++ -std=c++14 \
        -I${XILINX_XRT}/include \
        -I${XILINX_VIVADO}/include \
        -L${XILINX_XRT}/lib \
        -o "${output_exe}" \
        "${HOST_SOURCE}" \
        -lOpenCL -lpthread -lrt -lstdc++ \
        2>&1 | tee "${TMP_RUN_DIR}/host_compile.log"

    local compile_status=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [ ${compile_status} -eq 0 ]; then
        print_success "Host compilation completed in ${duration} seconds"
        return 0
    else
        print_error "Host compilation failed after ${duration} seconds"
        return 1
    fi
}

setup_emulation() {
    print_banner "Setting Up Emulation Environment"

    cd "${PROJECT_DIR}"

    # Only needed for emulation targets
    if [ "${TARGET}" == "hw_emu" ] || [ "${TARGET}" == "sw_emu" ]; then
        print_info "Generating emulation configuration..."

        emconfigutil --platform ${PLATFORM} --nd 1 2>&1 | tee "${TMP_RUN_DIR}/emconfig.log"

        if [ $? -eq 0 ]; then
            print_success "Emulation configuration generated: emconfig.json"
        else
            print_error "Failed to generate emulation configuration"
            return 1
        fi

        # Set environment variables for emulation
        export XCL_EMULATION_MODE=${TARGET}
        print_info "Set XCL_EMULATION_MODE=${TARGET}"
    else
        print_info "Hardware target - no emulation setup needed"
    fi

    return 0
}

run_application() {
    print_banner "Running Application"

    cd "${PROJECT_DIR}"

    # Set emulation mode if needed
    if [ "${TARGET}" == "hw_emu" ] || [ "${TARGET}" == "sw_emu" ]; then
        export XCL_EMULATION_MODE=${TARGET}
        print_info "Running in ${TARGET} mode"
    else
        print_info "Running on hardware"
    fi

    local start_time=$(date +%s)
    local run_log="${RESULTS_DIR}/run_${PROJECT_NAME}.log"

    print_info "Executing: ./${HOST_EXE} ${BINARY_CONTAINER}"
    print_info "Output will be saved to: ${run_log}"

    # Run the host executable
    ./${HOST_EXE} ${BINARY_CONTAINER} 2>&1 | tee "${run_log}"

    local run_status=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [ ${run_status} -eq 0 ]; then
        print_success "Application completed successfully in ${duration} seconds"
        return 0
    else
        print_error "Application failed after ${duration} seconds"
        return 1
    fi
}

extract_results() {
    print_banner "Extracting Results"

    # Copy logs to results
    if [ -f "${TMP_RUN_DIR}/link.log" ]; then
        cp "${TMP_RUN_DIR}/link.log" "${RESULTS_DIR}/${PROJECT_NAME}_link.log"
        print_success "Copied link log to results"
    fi

    if [ -f "${TMP_RUN_DIR}/host_compile.log" ]; then
        cp "${TMP_RUN_DIR}/host_compile.log" "${RESULTS_DIR}/${PROJECT_NAME}_host_compile.log"
        print_success "Copied host compile log to results"
    fi

    # Copy emulation waveforms if available
    if [ "${TARGET}" == "hw_emu" ]; then
        if [ -f "${PROJECT_DIR}/xsim.wdb" ]; then
            mkdir -p "${RESULTS_DIR}/waveforms"
            cp "${PROJECT_DIR}/xsim.wdb" "${RESULTS_DIR}/waveforms/"
            print_success "Copied waveform database to results"
        fi
    fi

    # Copy profile/timeline data if available
    if [ -f "${PROJECT_DIR}/profile_summary.csv" ]; then
        cp "${PROJECT_DIR}/profile_summary.csv" "${RESULTS_DIR}/"
        print_success "Copied profile summary to results"
    fi

    if [ -f "${PROJECT_DIR}/timeline_trace.csv" ]; then
        cp "${PROJECT_DIR}/timeline_trace.csv" "${RESULTS_DIR}/"
        print_success "Copied timeline trace to results"
    fi

    print_success "Results extraction complete"
    print_info "Results saved to: ${RESULTS_DIR}"
}

cleanup() {
    print_banner "Cleaning Up"

    # Calculate space used
    local build_size=$(du -sh "${TMP_RUN_DIR}" 2>/dev/null | awk '{print $1}')
    print_info "Temporary run directory size: ${build_size}"

    # Ask user before deleting
    if [ "${AUTO_CLEANUP}" = "yes" ]; then
        print_info "Auto-cleanup enabled, deleting ${TMP_RUN_DIR}"
        rm -rf "${TMP_RUN_DIR}"
        print_success "Cleanup complete"
    else
        echo ""
        read -p "Delete temporary run directory? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "${TMP_RUN_DIR}"
            print_success "Cleanup complete"
        else
            print_info "Temporary files preserved at: ${TMP_RUN_DIR}"
        fi
    fi
}

print_summary() {
    print_banner "Run Summary"

    echo ""
    echo "Project: ${PROJECT_NAME}"
    echo "Target: ${TARGET}"
    echo "Binary: ${PROJECT_DIR}/${BINARY_CONTAINER}"
    echo "Executable: ${PROJECT_DIR}/${HOST_EXE}"
    echo ""

    if [ -f "${PROJECT_DIR}/${BINARY_CONTAINER}" ]; then
        local xclbin_size=$(ls -lh "${PROJECT_DIR}/${BINARY_CONTAINER}" | awk '{print $5}')
        echo "Binary container: ${BINARY_CONTAINER} (${xclbin_size})"
    fi

    if [ -f "${RESULTS_DIR}/run_${PROJECT_NAME}.log" ]; then
        echo "Run log: ${RESULTS_DIR}/run_${PROJECT_NAME}.log"
    fi

    echo ""
    print_success "Run workflow complete!"
}

################################################################################
# WORKFLOW OPTIONS
################################################################################

SKIP_LINK=false
SKIP_COMPILE=false
SKIP_EMCONFIG=false
SKIP_RUN=false

################################################################################
# MAIN WORKFLOW
################################################################################

main() {
    print_banner "FPGA Run Workflow - ${PROJECT_NAME}"

    # Setup environment
    setup_environment
    check_prerequisites

    # Link kernels
    if [ "${SKIP_LINK}" = false ]; then
        if ! link_kernels; then
            print_error "Linking failed"
            exit 1
        fi
    else
        print_info "Skipping link step (using existing ${BINARY_CONTAINER})"
    fi

    # Compile host
    if [ "${SKIP_COMPILE}" = false ]; then
        if ! compile_host; then
            print_error "Host compilation failed"
            exit 1
        fi
    else
        print_info "Skipping host compilation (using existing ${HOST_EXE})"
    fi

    # Setup emulation
    if [ "${SKIP_EMCONFIG}" = false ]; then
        if ! setup_emulation; then
            print_error "Emulation setup failed"
            exit 1
        fi
    else
        print_info "Skipping emulation setup"
    fi

    # Run application
    if [ "${SKIP_RUN}" = false ]; then
        if ! run_application; then
            print_error "Application run failed"
            extract_results
            exit 1
        fi
    else
        print_info "Skipping application run"
    fi

    extract_results
    cleanup
    print_summary
    exit 0
}

################################################################################
# TRAP SIGNALS
################################################################################

trap 'print_error "Run interrupted"; exit 1' INT TERM

################################################################################
# USAGE
################################################################################

show_usage() {
    cat << EOF
FPGA Run Template Script

Usage: $0 [OPTIONS]

Options:
  -h, --help                  Show this help message
  -p, --project NAME          Project name (default: my_fpga_project)
  -x, --xo FILES              Kernel .xo files (space-separated)
  -b, --binary NAME           Binary container name (default: binary_container.xclbin)
  -H, --host FILE             Host source file (default: host.cpp)
  -e, --exe NAME              Host executable name (default: host.exe)
  -t, --target TYPE           Target: hw_emu, hw, sw_emu (default: hw_emu)
  -B, --board BOARD           Board type: u200, u250, u280, etc. (default: u200)
  -P, --platform NAME         Platform name (override auto-detect)
  -d, --dir PATH              Project directory (default: current directory)
  -c, --auto-cleanup          Automatically cleanup temp files

Workflow Control:
  --skip-link                 Skip linking (use existing .xclbin)
  --skip-compile              Skip host compilation (use existing .exe)
  --skip-emconfig             Skip emulation config
  --skip-run                  Only link and compile, don't run

Environment Variables:
  VITIS_PATH                  Path to Vitis (default: /tools/Xilinx/Vitis/2024.2)
  XRT_PATH                    Path to XRT (default: /opt/xilinx/xrt)
  PLATFORM_PATH               Path to platforms (default: /opt/xilinx/platforms)

Examples:
  # Complete workflow: link, compile, and run
  $0 -p my_project -x "kernel1.xo kernel2.xo" -H host.cpp

  # Run with U250 board
  $0 -p my_project -x kernel.xo -H host.cpp -B u250

  # Only link and compile (don't run)
  $0 -p my_project -x kernel.xo -H host.cpp --skip-run

  # Use existing binary, just run
  $0 -p my_project -x kernel.xo -H host.cpp --skip-link --skip-compile

  # Hardware target (not emulation)
  $0 -p my_project -x kernel.xo -H host.cpp -t hw

Output Files:
  \${PROJECT_DIR}/
    ├── binary_container.xclbin    (linked binary)
    ├── host.exe                    (compiled host)
    └── emconfig.json               (emulation config)

  \${PROJECT_DIR}/results/
    ├── run_<project>_log           (execution log)
    ├── <project>_link.log          (link log)
    └── <project>_host_compile.log  (host compile log)

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
        -x|--xo)
            KERNEL_XO_FILES="$2"
            shift 2
            ;;
        -b|--binary)
            BINARY_CONTAINER="$2"
            shift 2
            ;;
        -H|--host)
            HOST_SOURCE="$2"
            shift 2
            ;;
        -e|--exe)
            HOST_EXE="$2"
            shift 2
            ;;
        -t|--target)
            TARGET="$2"
            shift 2
            ;;
        -B|--board)
            BOARD="$2"
            shift 2
            ;;
        -P|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -d|--dir)
            PROJECT_DIR="$2"
            shift 2
            ;;
        -c|--auto-cleanup)
            AUTO_CLEANUP="yes"
            shift
            ;;
        --skip-link)
            SKIP_LINK=true
            shift
            ;;
        --skip-compile)
            SKIP_COMPILE=true
            shift
            ;;
        --skip-emconfig)
            SKIP_EMCONFIG=true
            shift
            ;;
        --skip-run)
            SKIP_RUN=true
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