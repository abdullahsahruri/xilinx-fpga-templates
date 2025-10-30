#!/bin/bash
################################################################################
# FPGA Build Directory Cleanup Script
#
# Purpose: Clean up temporary build directories in /tmp after resource extraction
# Usage: ./fpga_cleanup_builds.sh [options]
#
# Options:
#   --all         Clean all build directories without prompting
#   --older-than  Clean only directories older than N days (e.g., --older-than 7)
#   --dry-run     Show what would be deleted without actually deleting
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
AUTO_CLEAN=0
DRY_RUN=0
OLDER_THAN_DAYS=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            AUTO_CLEAN=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --older-than)
            OLDER_THAN_DAYS="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--all] [--dry-run] [--older-than N]"
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
    echo -e "${BLUE}→ $1${NC}"
}

# Function to convert bytes to human readable format
human_readable() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$(awk "BEGIN {printf \"%.1f\", $bytes/1024}")KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$(awk "BEGIN {printf \"%.1f\", $bytes/1048576}")MB"
    else
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1073741824}")GB"
    fi
}

# Main script
print_header "FPGA Build Directory Cleanup"

# Find all build directories for current user
TMP_DIR="/tmp/${USER}_fpga_builds"

if [ ! -d "$TMP_DIR" ]; then
    print_warning "No build directories found at: $TMP_DIR"
    echo ""
    print_info "This is normal if:"
    echo "  1. You haven't run any FPGA builds yet"
    echo "  2. All builds have already been cleaned up"
    echo "  3. Builds are stored in a different location"
    exit 0
fi

# Get list of subdirectories
BUILD_DIRS=()
while IFS= read -r -d '' dir; do
    BUILD_DIRS+=("$dir")
done < <(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

if [ ${#BUILD_DIRS[@]} -eq 0 ]; then
    print_success "No build directories to clean up!"
    exit 0
fi

# Display found directories
echo ""
print_info "Found ${#BUILD_DIRS[@]} build directory/directories:"
echo ""

TOTAL_SIZE=0
DIR_INFO=()

for dir in "${BUILD_DIRS[@]}"; do
    # Get directory size in KB
    SIZE_KB=$(du -sk "$dir" 2>/dev/null | awk '{print $1}')
    SIZE_BYTES=$((SIZE_KB * 1024))
    TOTAL_SIZE=$((TOTAL_SIZE + SIZE_BYTES))

    # Get modification time
    MOD_TIME=$(stat -c %Y "$dir" 2>/dev/null)
    MOD_DATE=$(date -d @$MOD_TIME "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")

    # Calculate age in days
    CURRENT_TIME=$(date +%s)
    AGE_DAYS=$(( (CURRENT_TIME - MOD_TIME) / 86400 ))

    # Store info
    DIR_INFO+=("$dir|$SIZE_BYTES|$MOD_DATE|$AGE_DAYS")

    # Display with color based on age
    SIZE_HUMAN=$(human_readable $SIZE_BYTES)
    DIR_NAME=$(basename "$dir")

    if [ $AGE_DAYS -lt 1 ]; then
        echo -e "  ${GREEN}$DIR_NAME${NC}  ($SIZE_HUMAN, modified: $MOD_DATE, <1 day old)"
    elif [ $AGE_DAYS -lt 7 ]; then
        echo -e "  ${YELLOW}$DIR_NAME${NC}  ($SIZE_HUMAN, modified: $MOD_DATE, $AGE_DAYS days old)"
    else
        echo -e "  ${RED}$DIR_NAME${NC}  ($SIZE_HUMAN, modified: $MOD_DATE, $AGE_DAYS days old)"
    fi
done

echo ""
TOTAL_HUMAN=$(human_readable $TOTAL_SIZE)
print_info "Total space used: $TOTAL_HUMAN"
echo ""

# Filter by age if requested
if [ $OLDER_THAN_DAYS -gt 0 ]; then
    FILTERED_DIRS=()
    FILTERED_SIZE=0

    for info in "${DIR_INFO[@]}"; do
        IFS='|' read -r dir size mod_date age <<< "$info"
        if [ $age -ge $OLDER_THAN_DAYS ]; then
            FILTERED_DIRS+=("$dir")
            FILTERED_SIZE=$((FILTERED_SIZE + size))
        fi
    done

    if [ ${#FILTERED_DIRS[@]} -eq 0 ]; then
        print_success "No directories older than $OLDER_THAN_DAYS days found!"
        exit 0
    fi

    BUILD_DIRS=("${FILTERED_DIRS[@]}")
    TOTAL_SIZE=$FILTERED_SIZE
    TOTAL_HUMAN=$(human_readable $TOTAL_SIZE)

    print_info "Filtered to ${#BUILD_DIRS[@]} directories older than $OLDER_THAN_DAYS days ($TOTAL_HUMAN)"
    echo ""
fi

# Dry run mode
if [ $DRY_RUN -eq 1 ]; then
    print_warning "DRY RUN MODE - No files will be deleted"
    echo ""
    print_info "Would delete ${#BUILD_DIRS[@]} directories ($TOTAL_HUMAN):"
    for dir in "${BUILD_DIRS[@]}"; do
        echo "  - $(basename $dir)"
    done
    exit 0
fi

# Confirm deletion
if [ $AUTO_CLEAN -eq 0 ]; then
    echo -e "${YELLOW}WARNING: This will permanently delete ${#BUILD_DIRS[@]} build directories${NC}"
    echo -e "${YELLOW}Total space to be freed: $TOTAL_HUMAN${NC}"
    echo ""
    read -p "Are you sure you want to continue? [y/N] " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Cleanup cancelled by user"
        exit 0
    fi
fi

# Perform cleanup
echo ""
print_info "Cleaning up build directories..."
echo ""

DELETED_COUNT=0
FAILED_COUNT=0

for dir in "${BUILD_DIRS[@]}"; do
    DIR_NAME=$(basename "$dir")

    if rm -rf "$dir" 2>/dev/null; then
        print_success "Deleted: $DIR_NAME"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    else
        print_error "Failed to delete: $DIR_NAME"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
done

echo ""

# Summary
if [ $DELETED_COUNT -gt 0 ]; then
    print_success "Successfully deleted $DELETED_COUNT directory/directories"
    print_success "Freed approximately $TOTAL_HUMAN of space"
fi

if [ $FAILED_COUNT -gt 0 ]; then
    print_error "Failed to delete $FAILED_COUNT directory/directories"
fi

# Check if parent directory is now empty and can be removed
if [ -d "$TMP_DIR" ] && [ -z "$(ls -A $TMP_DIR 2>/dev/null)" ]; then
    if rmdir "$TMP_DIR" 2>/dev/null; then
        print_success "Removed empty parent directory: $TMP_DIR"
    fi
fi

echo ""
print_header "Cleanup Complete"