#!/bin/bash
################################################################################
# FPGA Resource Extraction Script
#
# Purpose: Extract resource utilization reports from /tmp build directories
# Usage: ./fpga_extract_resources.sh [options]
#
# Options:
#   --project NAME    Extract resources for specific project
#   --all             Extract resources from all builds
#   --output FILE     Save results to specified file
#   --format FORMAT   Output format: text, csv, markdown (default: text)
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
PROJECT_NAME=""
EXTRACT_ALL=0
OUTPUT_FILE=""
FORMAT="text"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        --all)
            EXTRACT_ALL=1
            shift
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --project NAME    Extract resources for specific project"
            echo "  --all             Extract resources from all builds"
            echo "  --output FILE     Save results to specified file"
            echo "  --format FORMAT   Output format: text, csv, markdown (default: text)"
            echo ""
            echo "Examples:"
            echo "  $0 --all                           # Extract all builds"
            echo "  $0 --project vector_add            # Extract specific project"
            echo "  $0 --all --output resources.txt    # Save to file"
            echo "  $0 --all --format csv              # CSV output"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}→ $1${NC}"
}

# Function to extract implementation resources (hw builds only)
extract_implementation_resources() {
    local build_dir="$1"

    # Look for implementation utilization reports
    local impl_report=$(find "$build_dir" -name "*utilization_routed.rpt" -o -name "*utilization_placed.rpt" 2>/dev/null | head -1)

    if [ -z "$impl_report" ] || [ ! -f "$impl_report" ]; then
        return 1
    fi

    # Extract actual resource usage from implementation report
    local lut_line=$(grep -E "CLB LUTs" "$impl_report" | head -1)
    local ff_line=$(grep -E "CLB Registers|Slice Registers" "$impl_report" | head -1)
    local bram_line=$(grep -E "Block RAM Tile" "$impl_report" | head -1)
    local dsp_line=$(grep -E "DSPs" "$impl_report" | head -1)
    local uram_line=$(grep -E "URAM" "$impl_report" | head -1)

    # Parse numbers (format: "| Resource | Used | Available | Utilization% |")
    local impl_lut=$(echo "$lut_line" | awk '{print $4}')
    local impl_ff=$(echo "$ff_line" | awk '{print $4}')
    local impl_bram=$(echo "$bram_line" | awk '{print $5}')
    local impl_dsp=$(echo "$dsp_line" | awk '{print $4}')
    local impl_uram=$(echo "$uram_line" | awk '{print $4}')

    # Return values in a format that can be parsed
    echo "$impl_lut,$impl_ff,$impl_dsp,$impl_bram,$impl_uram"
    return 0
}

# Function to extract resources from a report file
extract_resources() {
    local report_file="$1"
    local build_name="$2"
    local build_dir="$3"

    if [ ! -f "$report_file" ]; then
        print_error "Report file not found: $report_file"
        return 1
    fi

    # Extract key information from system estimate
    local target_clock=$(grep "Target Clock:" "$report_file" | awk '{print $3}')
    local est_freq=$(grep "Estimated Frequency" "$report_file" | tail -1 | awk '{print $NF}')

    # Extract area information (look for the summary line with all resources)
    local area_line=$(grep -A 100 "Area Information" "$report_file" | grep -E "^[^-].*[0-9]+.*[0-9]+.*[0-9]+.*[0-9]+.*[0-9]+" | tail -1)

    if [ -z "$area_line" ]; then
        print_warning "Could not parse area information from report"
        return 1
    fi

    # Parse estimated resource numbers (FF, LUT, DSP, BRAM, URAM)
    local ff=$(echo "$area_line" | awk '{print $4}')
    local lut=$(echo "$area_line" | awk '{print $5}')
    local dsp=$(echo "$area_line" | awk '{print $6}')
    local bram=$(echo "$area_line" | awk '{print $7}')
    local uram=$(echo "$area_line" | awk '{print $8}')

    # Try to get implementation resources (for hw builds)
    local impl_resources=$(extract_implementation_resources "$build_dir")
    local has_impl=0
    local impl_lut="" impl_ff="" impl_dsp="" impl_bram="" impl_uram=""

    if [ -n "$impl_resources" ]; then
        has_impl=1
        IFS=',' read -r impl_lut impl_ff impl_dsp impl_bram impl_uram <<< "$impl_resources"
    fi

    # Determine build type
    local build_type="hw_emu"
    if [ $has_impl -eq 1 ]; then
        build_type="hw"
    fi

    # Output based on format
    case $FORMAT in
        csv)
            if [ $has_impl -eq 1 ]; then
                echo "$build_name,hw,$impl_ff,$impl_lut,$impl_dsp,$impl_bram,$impl_uram,$target_clock,$est_freq"
            else
                echo "$build_name,hw_emu,$ff,$lut,$dsp,$bram,$uram,$target_clock,$est_freq"
            fi
            ;;
        markdown)
            if [ $has_impl -eq 1 ]; then
                echo "| $build_name | hw | $impl_lut | $impl_ff | $impl_dsp | $impl_bram | $impl_uram | $target_clock | $est_freq |"
            else
                echo "| $build_name | hw_emu | $lut | $ff | $dsp | $bram | $uram | $target_clock | $est_freq |"
            fi
            ;;
        text)
            echo ""
            echo "Build: $build_name"
            echo "Type: $build_type"
            echo "----------------------------------------"
            echo "  Target Clock:    $target_clock"
            echo "  Est. Frequency:  $est_freq"
            echo ""

            if [ $has_impl -eq 1 ]; then
                echo "  Estimated Resources (system_estimate):"
                echo "    FF:    $ff"
                echo "    LUT:   $lut"
                echo "    DSP:   $dsp"
                echo "    BRAM:  $bram"
                echo "    URAM:  $uram"
                echo ""
                echo "  Actual Resources (post-implementation):"
                echo "    FF:    $impl_ff"
                echo "    LUT:   $impl_lut"
                echo "    DSP:   $impl_dsp"
                echo "    BRAM:  $impl_bram"
                echo "    URAM:  $impl_uram"
            else
                echo "  Resources (estimated):"
                echo "    FF:    $ff"
                echo "    LUT:   $lut"
                echo "    DSP:   $dsp"
                echo "    BRAM:  $bram"
                echo "    URAM:  $uram"
            fi
            echo "----------------------------------------"
            ;;
    esac

    return 0
}

# Function to display detailed report
display_detailed_report() {
    local report_file="$1"
    local build_name="$2"

    echo ""
    print_header "Detailed Report: $build_name"
    echo ""

    # Display timing information
    echo -e "${CYAN}Timing Information:${NC}"
    grep -A 20 "Timing Information" "$report_file" | head -25

    echo ""
    echo -e "${CYAN}Area Information:${NC}"
    grep -A 20 "Area Information" "$report_file" | head -25

    echo ""
}

# Main script
print_header "FPGA Resource Extraction"

# Find all build directories
TMP_DIR="/tmp/${USER}_fpga_builds"

if [ ! -d "$TMP_DIR" ]; then
    print_warning "No build directories found at: $TMP_DIR"
    echo ""
    print_info "This is normal if:"
    echo "  1. You haven't run any FPGA builds yet"
    echo "  2. All builds have been cleaned up"
    echo "  3. Builds are stored in a different location"
    exit 0
fi

# Find report files
if [ $EXTRACT_ALL -eq 1 ]; then
    REPORT_FILES=$(find "$TMP_DIR" -name "system_estimate_*.xtxt" 2>/dev/null)
elif [ -n "$PROJECT_NAME" ]; then
    REPORT_FILES=$(find "$TMP_DIR" -path "*${PROJECT_NAME}*" -name "system_estimate_*.xtxt" 2>/dev/null)
else
    # Interactive mode - show available builds
    echo ""
    print_info "Available builds in $TMP_DIR:"
    echo ""

    BUILD_DIRS=($(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null))

    if [ ${#BUILD_DIRS[@]} -eq 0 ]; then
        print_warning "No build directories found"
        exit 0
    fi

    for i in "${!BUILD_DIRS[@]}"; do
        build_name=$(basename "${BUILD_DIRS[$i]}")
        echo "  [$i] $build_name"
    done

    echo ""
    read -p "Select build number (or 'all' for all builds): " selection

    if [ "$selection" = "all" ]; then
        REPORT_FILES=$(find "$TMP_DIR" -name "system_estimate_*.xtxt" 2>/dev/null)
    elif [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -lt "${#BUILD_DIRS[@]}" ]; then
        REPORT_FILES=$(find "${BUILD_DIRS[$selection]}" -name "system_estimate_*.xtxt" 2>/dev/null)
    else
        print_error "Invalid selection"
        exit 1
    fi
fi

if [ -z "$REPORT_FILES" ]; then
    print_warning "No system estimate reports found"
    echo ""
    print_info "Reports are generated during hw_emu and hw builds"
    print_info "Make sure your build completed successfully"
    exit 0
fi

# Count reports
REPORT_COUNT=$(echo "$REPORT_FILES" | wc -l)
print_success "Found $REPORT_COUNT report(s)"
echo ""

# Set up output
if [ -n "$OUTPUT_FILE" ]; then
    exec > >(tee "$OUTPUT_FILE")
fi

# Print header for CSV/Markdown formats
case $FORMAT in
    csv)
        echo "Build,Type,FF,LUT,DSP,BRAM,URAM,Target_Clock,Est_Frequency"
        ;;
    markdown)
        echo "| Build | Type | LUT | FF | DSP | BRAM | URAM | Target Clock | Est. Freq |"
        echo "|-------|------|-----|----|----|------|------|--------------|-----------|"
        ;;
esac

# Extract resources from each report
EXTRACTED=0
while IFS= read -r report_file; do
    # Get build name from path
    build_dir=$(dirname "$(dirname "$report_file")")
    build_name=$(basename "$build_dir")

    if extract_resources "$report_file" "$build_name" "$build_dir"; then
        EXTRACTED=$((EXTRACTED + 1))

        # For text format, optionally show detailed report
        if [ "$FORMAT" = "text" ] && [ $REPORT_COUNT -eq 1 ]; then
            display_detailed_report "$report_file" "$build_name"
        fi
    fi
done <<< "$REPORT_FILES"

echo ""
print_success "Extracted resources from $EXTRACTED build(s)"

if [ -n "$OUTPUT_FILE" ]; then
    print_success "Results saved to: $OUTPUT_FILE"
fi

echo ""
print_info "Tip: Use --format csv to export data for spreadsheet analysis"
print_info "Tip: Use --format markdown to generate documentation tables"

exit 0