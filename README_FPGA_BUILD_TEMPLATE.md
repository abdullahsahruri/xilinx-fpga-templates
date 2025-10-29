# FPGA Build Template - User Guide

## Overview

This template script (`fpga_build_template.sh`) provides a standardized workflow for building Xilinx FPGA designs using Vitis HLS. It automatically handles:

- Environment setup (Vitis, XRT)
- Platform detection for various Alveo boards
- Temporary file management in `/tmp` (avoids home directory quota issues)
- Result extraction and organization
- Resource utilization reporting

## Quick Start

### 1. Copy the Template to Your Project

```bash
# Navigate to your project directory
cd /path/to/your/project

# Copy the template script
cp /home/C00535644/xilinx/fpga_build_template.sh .

# Make it executable
chmod +x fpga_build_template.sh
```

### 2. Basic Usage

```bash
# Build with default settings (U200 board, hw_emu target)
./fpga_build_template.sh -p my_project -k my_kernel -s kernel.cpp

# Build for U250 board
./fpga_build_template.sh -p my_project -k my_kernel -s kernel.cpp -b u250

# Build for hardware target (actual FPGA)
./fpga_build_template.sh -p my_project -k my_kernel -s kernel.cpp -t hw

# With auto-cleanup of temporary files
./fpga_build_template.sh -p my_project -k my_kernel -s kernel.cpp -c
```

## Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `-h, --help` | Show help message | - |
| `-p, --project NAME` | Project name | `my_fpga_project` |
| `-k, --kernel NAME` | Kernel function name | `my_kernel` |
| `-s, --source FILE` | Source file (relative to project dir) | `kernel.cpp` |
| `-t, --target TYPE` | Target: `hw_emu`, `hw`, `sw_emu` | `hw_emu` |
| `-b, --board BOARD` | Board type (see below) | `u200` |
| `-P, --platform NAME` | Override platform string | Auto-detected |
| `-o, --optimize LEVEL` | Optimization level (0-3) | `3` |
| `-d, --dir PATH` | Project directory | Current directory |
| `-c, --auto-cleanup` | Auto-cleanup temp files | Manual prompt |

## Supported Boards

The script automatically detects the full platform string for these common boards:

| Board | Description | Auto-detected Platform Pattern |
|-------|-------------|-------------------------------|
| `u200` | Alveo U200 Data Center Accelerator | `xilinx_u200*` |
| `u250` | Alveo U250 Data Center Accelerator | `xilinx_u250*` |
| `u280` | Alveo U280 Data Center Accelerator | `xilinx_u280*` |
| `u50` | Alveo U50 Data Center Accelerator | `xilinx_u50*` |
| `u55c` | Alveo U55C Data Center Accelerator | `xilinx_u55c*` |
| `vck190` | Versal VCK190 Evaluation Kit | `xilinx_vck190*` |

For custom platforms, pass the full platform string:
```bash
./fpga_build_template.sh -p my_project -k my_kernel -s kernel.cpp -b xilinx_custom_platform_v1_0
```

## Environment Variables

You can override default paths using environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `VITIS_PATH` | Vitis installation path | `/tools/Xilinx/Vitis/2024.2` |
| `XRT_PATH` | XRT installation path | `/opt/xilinx/xrt` |
| `PLATFORM_PATH` | Platform repository path | `/opt/xilinx/platforms` |

Example:
```bash
export VITIS_PATH=/custom/vitis/path
./fpga_build_template.sh -p my_project -k my_kernel -s kernel.cpp
```

## Directory Structure

### Input (Your Project)
```
your_project/
├── kernel.cpp          # Your HLS kernel source
├── kernel.h            # Optional headers
└── ...
```

### Output (Created by Script)
```
your_project/
└── results/
    ├── kernels/                      # Final .xo kernel objects
    │   └── my_kernel.xo
    ├── reports/                      # HLS synthesis reports
    │   └── my_project/
    │       └── my_kernel/
    │           ├── system_estimate_my_kernel.xtxt
    │           └── ...
    └── logs/                         # Build logs
        └── my_project_build.log

/tmp/${USER}_fpga_builds/            # Temporary (cleaned up)
└── my_project_<PID>/
    ├── _x/                          # Vitis temp files (multi-GB)
    └── build.log
```

**Key Benefits:**
- Only **small result files** stored in home directory (reports, logs, .xo files)
- **Large temporary files** (multi-GB) stored in `/tmp`
- Avoids home directory quota issues
- Easy cleanup after build

## Build Targets

### 1. Software Emulation (`sw_emu`)
- Fast functional verification
- Runs kernel as software
- No hardware synthesis
- **Build time:** Minutes
- **Use for:** Quick functionality testing

```bash
./fpga_build_template.sh -p my_project -k my_kernel -s kernel.cpp -t sw_emu
```

### 2. Hardware Emulation (`hw_emu`)
- RTL-level simulation
- Accurate performance modeling
- HLS synthesis performed
- **Build time:** 30-60 minutes
- **Use for:** Performance validation before hardware build

```bash
./fpga_build_template.sh -p my_project -k my_kernel -s kernel.cpp -t hw_emu
```

### 3. Hardware (`hw`)
- Full FPGA bitstream generation
- Runs on actual hardware
- Complete place & route
- **Build time:** 2-6 hours
- **Use for:** Final deployment

```bash
./fpga_build_template.sh -p my_project -k my_kernel -s kernel.cpp -t hw
```

## Examples

### Example 1: Basic HDC Kernel Build
```bash
# Project structure:
# hdc_project/
# ├── hdc_kernel.cpp
# └── hdc_config.h

cd hdc_project
/path/to/fpga_build_template.sh \
    -p hdc_classifier \
    -k hdc_kernel_integrated \
    -s hdc_kernel.cpp \
    -b u200 \
    -t hw_emu

# Results will be in: hdc_project/results/
```

### Example 2: Matrix Multiply for U280
```bash
cd matrix_mult
/path/to/fpga_build_template.sh \
    -p matmul \
    -k mmult \
    -s matmul.cpp \
    -b u280 \
    -t hw_emu \
    -o 3 \
    -c  # Auto-cleanup
```

### Example 3: Custom Platform
```bash
# Using a custom platform not in the auto-detect list
cd custom_project
/path/to/fpga_build_template.sh \
    -p my_custom_design \
    -k custom_kernel \
    -s kernel.cpp \
    -b xilinx_vck5000_gen4x8_qdma_2_202220_1
```

### Example 4: Multiple Kernels (Sequential Builds)
```bash
cd multi_kernel_project

# Build kernel 1
./fpga_build_template.sh -p encoder -k encode_kernel -s encode.cpp -b u250

# Build kernel 2
./fpga_build_template.sh -p decoder -k decode_kernel -s decode.cpp -b u250

# Results organized by project name:
# results/
# ├── kernels/
# │   ├── encode_kernel.xo
# │   └── decode_kernel.xo
# └── reports/
#     ├── encoder/
#     └── decoder/
```

## Workflow Steps

The script executes these steps automatically:

1. **Environment Setup**
   - Source Vitis settings (`settings64.sh`)
   - Source XRT runtime (`setup.sh`)
   - Detect platform based on board type

2. **Prerequisites Check**
   - Verify source file exists
   - Check `/tmp` disk space (requires ~5GB minimum)
   - Check home directory space

3. **HLS Synthesis**
   - Run `v++ -c` compilation
   - All temp files redirected to `/tmp`
   - Save build log

4. **Extract Results**
   - Copy `.xo` kernel to `results/kernels/`
   - Copy HLS reports to `results/reports/`
   - Copy build log to `results/logs/`
   - Display resource utilization summary

5. **Cleanup**
   - Prompt to delete temporary files (or auto-cleanup with `-c`)
   - Show build summary

## Resource Utilization Reporting

After build, the script automatically extracts resource estimates:

```
[INFO] Resource Utilization:
hdc_kernel_integrated_1  hdc_kernel_integrated  350218  386083  0  17  0
                                                  ^^^^^^  ^^^^^^     ^^
                                                    FFs    LUTs   BRAMs
```

Full detailed reports available in:
```
results/reports/<project_name>/<kernel_name>/system_estimate_<kernel_name>.xtxt
```

## Troubleshooting

### Error: "Vitis not found at /tools/Xilinx/Vitis/2024.2"

**Solution:** Set custom Vitis path
```bash
export VITIS_PATH=/your/vitis/path
./fpga_build_template.sh ...
```

### Error: "Could not detect platform for board: u200"

**Cause:** Platform files not in standard locations

**Solution 1:** Set platform path
```bash
export PLATFORM_PATH=/path/to/platforms
./fpga_build_template.sh ...
```

**Solution 2:** Manually specify platform
```bash
./fpga_build_template.sh ... -P xilinx_u200_gen3x16_xdma_2_202110_1
```

**Solution 3:** List available platforms
```bash
platforminfo --list
# OR
ls /opt/xilinx/platforms/
ls /opt/xilinx/xrt/platforms/
```

### Error: "Less than 5GB available in /tmp"

**Cause:** Insufficient temp space

**Solution:** Clean up `/tmp` or use different temp location
```bash
# Clean old builds
rm -rf /tmp/${USER}_fpga_builds/*

# OR modify script to use different location
# Edit TMP_BUILD_ROOT="/scratch/${USER}_fpga_builds"
```

### Error: "Disk quota exceeded"

**Cause:** Results directory filling home quota

**Solution:** Use different results location
```bash
# Build from a directory with more space
mkdir -p /scratch/my_builds
cd /scratch/my_builds
/path/to/fpga_build_template.sh -d $(pwd) ...

# Results will go to /scratch/my_builds/results/
```

### Build Completes but No .xo File

**Cause:** HLS synthesis failed

**Check logs:**
```bash
cat results/logs/<project_name>_build.log
# OR
cat /tmp/${USER}_fpga_builds/<project_name>_*/build.log
```

**Common issues:**
- Syntax errors in HLS code
- Unsupported C++ constructs
- Missing HLS pragmas
- Platform incompatibilities

## Performance Tips

### 1. Use Appropriate Optimization Levels

```bash
# Faster build, lower performance
-o 0

# Balanced (default)
-o 2

# Best performance, longer build
-o 3
```

### 2. Iterate with `hw_emu` First

```bash
# Fast iteration during development
-t hw_emu

# Only build hardware after validation
-t hw
```

### 3. Enable Auto-Cleanup

```bash
# Saves time - don't wait for cleanup prompt
-c
```

### 4. Parallel Builds (Different Terminals)

```bash
# Terminal 1
./fpga_build_template.sh -p design1 -k kernel1 -s k1.cpp &

# Terminal 2
./fpga_build_template.sh -p design2 -k kernel2 -s k2.cpp &

# Temporary directories are process-isolated (PID in name)
```

## Advanced Usage

### Modifying the Script for Your Needs

The script is designed to be a **template** - feel free to customize:

```bash
# 1. Copy and modify for your specific workflow
cp fpga_build_template.sh my_custom_build.sh

# 2. Add project-specific configurations
# Edit the CONFIGURATION section:
PROJECT_NAME="${PROJECT_NAME:-my_default_project}"
KERNEL_NAME="${KERNEL_NAME:-my_default_kernel}"

# 3. Add custom build flags
# Edit the run_hls_synthesis function:
v++ -c -t ${TARGET} \
    --platform ${PLATFORM} \
    --custom_flag value \    # Your additions
    ...
```

### Integration with Makefiles

```makefile
# Makefile
TEMPLATE = /path/to/fpga_build_template.sh

.PHONY: build_hw_emu build_hw clean

build_hw_emu:
	$(TEMPLATE) -p $(PROJECT) -k $(KERNEL) -s $(SOURCE) -b u200 -t hw_emu -c

build_hw:
	$(TEMPLATE) -p $(PROJECT) -k $(KERNEL) -s $(SOURCE) -b u200 -t hw -c

clean:
	rm -rf results
	rm -rf /tmp/${USER}_fpga_builds/$(PROJECT)_*
```

### Using with Environment Modules

```bash
# If your system uses environment modules
module load xilinx/vitis/2024.2
module load xilinx/xrt/2.17

# Then run script (VITIS_PATH and XRT_PATH will be set by modules)
./fpga_build_template.sh -p my_project -k my_kernel -s kernel.cpp
```

## Best Practices

1. **Always version control your source code**
   ```bash
   git add kernel.cpp kernel.h
   git commit -m "HDC kernel v1.0"
   ```

2. **Keep build logs for reproducibility**
   ```bash
   # Logs are automatically saved to results/logs/
   # Archive important builds:
   tar -czf my_project_v1.0_results.tar.gz results/
   ```

3. **Test with `hw_emu` before `hw`**
   - Saves hours of build time
   - Catches most issues early

4. **Monitor resource utilization**
   - Check `system_estimate_*.xtxt` files
   - Ensure design fits on target device
   - Look for routing issues early

5. **Clean up old builds regularly**
   ```bash
   # Remove builds older than 7 days
   find /tmp/${USER}_fpga_builds/ -type d -mtime +7 -exec rm -rf {} \;
   ```

## Common Patterns

### Pattern 1: Iterative Optimization
```bash
# 1. Start with baseline
./fpga_build_template.sh -p baseline -k kernel -s kernel.cpp -t hw_emu

# 2. Add optimizations
# (edit kernel.cpp, add HLS pragmas)

# 3. Compare resources
./fpga_build_template.sh -p optimized -k kernel -s kernel.cpp -t hw_emu

# 4. Compare reports
diff results/reports/baseline/kernel/system_estimate_kernel.xtxt \
     results/reports/optimized/kernel/system_estimate_kernel.xtxt
```

### Pattern 2: Multi-Board Validation
```bash
# Test same kernel on multiple boards
for board in u200 u250 u280; do
    ./fpga_build_template.sh \
        -p mykernel_${board} \
        -k my_kernel \
        -s kernel.cpp \
        -b ${board} \
        -t hw_emu \
        -c
done

# Compare resource usage across boards
ls -lh results/kernels/
```

### Pattern 3: CI/CD Integration
```bash
#!/bin/bash
# ci_build.sh - Automated testing pipeline

set -e

# Build
./fpga_build_template.sh -p ci_build -k kernel -s kernel.cpp -t hw_emu -c

# Check resources
python check_resources.py results/reports/ci_build/kernel/system_estimate_kernel.xtxt

# Run tests
# (add your test harness here)

echo "CI build passed!"
```

## FAQ

**Q: Can I use this for host code compilation?**
A: No, this script only compiles HLS kernels (`.xo` generation). For host code, use standard `g++` or `xcpp`.

**Q: Why use `/tmp` instead of home directory?**
A: FPGA builds generate multi-GB temporary files. Using `/tmp` avoids home directory quota issues while keeping small result files organized in your project.

**Q: Can I run multiple builds simultaneously?**
A: Yes! Each build creates a unique temp directory using the process ID (`/tmp/${USER}_fpga_builds/project_<PID>`).

**Q: How do I link multiple kernels into one xclbin?**
A: This script generates individual `.xo` files. Use `v++ -l` separately to link multiple kernels:
```bash
v++ -l -t hw --platform xilinx_u200* \
    -o binary_container.xclbin \
    results/kernels/kernel1.xo \
    results/kernels/kernel2.xo
```

**Q: What if my kernel has dependencies (header files, libraries)?**
A: Ensure all dependencies are in your project directory. The script runs from `PROJECT_DIR`, so relative includes work:
```cpp
#include "my_header.h"  // Works if in same directory
```

For external libraries, modify the `run_hls_synthesis` function to add include paths:
```bash
v++ -c ... \
    -I/path/to/includes \
    -L/path/to/libs \
    -l mylib
```

## Support and Contributions

This template script was created for the Xilinx FPGA user community. Feel free to:
- Modify for your specific needs
- Share improvements with your team
- Report issues or suggestions

For Xilinx-specific questions, consult:
- [Vitis Unified Software Platform Documentation](https://docs.xilinx.com/r/en-US/ug1416-vitis-documentation)
- [Vitis HLS User Guide](https://docs.xilinx.com/r/en-US/ug1399-vitis-hls)

## Version History

- **v1.0** (2025-10-29): Initial release
  - Basic v++ HLS compilation workflow
  - Multi-board support (U200, U250, U280, U50, U55C, VCK190)
  - Automatic platform detection
  - /tmp temporary file management
  - Result extraction and organization