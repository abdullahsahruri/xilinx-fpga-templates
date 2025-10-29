# Command Reference

## Build Template (`fpga_build_template.sh`)

Compiles HLS kernels from C++ source to `.xo` (compiled kernel object).

### Basic Syntax

```bash
./fpga_build_template.sh [OPTIONS]
```

### Required Options

| Option | Description | Example |
|--------|-------------|---------|
| `-p, --project NAME` | Project name for organizing results | `-p my_project` |
| `-k, --kernel NAME` | Kernel function name (must match C++ function) | `-k vadd` |
| `-s, --source FILE` | Source file containing kernel code | `-s kernel.cpp` |

### Common Options

| Option | Description | Default | Example |
|--------|-------------|---------|---------|
| `-b, --board BOARD` | Target board (u200, u250, u280, u50, u55c, vck190) | - | `-b u200` |
| `-t, --target TYPE` | Build target (sw_emu, hw_emu, hw) | `hw_emu` | `-t hw_emu` |
| `-c, --auto-cleanup` | Auto-cleanup temporary files after build | Off | `-c` |

### Optional Options

| Option | Description | Default | Example |
|--------|-------------|---------|---------|
| `-d, --dir PATH` | Project directory | Current dir | `-d /path/to/project` |
| `-o, --optimize LEVEL` | Optimization level (0-3) | `3` | `-o 3` |
| `-P, --platform NAME` | Override platform string | Auto-detect | `-P xilinx_u200_...` |
| `-h, --help` | Show help message | - | `-h` |

### Examples

**Basic build:**
```bash
./fpga_build_template.sh \
    -p vector_add \
    -k vadd \
    -s vector_add.cpp \
    -b u200 \
    -t hw_emu
```

**With auto-cleanup:**
```bash
./fpga_build_template.sh \
    -p my_kernel \
    -k process_data \
    -s kernel.cpp \
    -b u280 \
    -t hw_emu \
    -c
```

**Software emulation (fast testing):**
```bash
./fpga_build_template.sh \
    -p debug \
    -k kernel \
    -s kernel.cpp \
    -b u200 \
    -t sw_emu \
    -c
```

**Hardware build (production):**
```bash
./fpga_build_template.sh \
    -p production \
    -k kernel \
    -s kernel.cpp \
    -b u200 \
    -t hw
```

### Output Files

```
results/
├── kernels/
│   └── kernel_name.xo          # Compiled kernel
├── reports/
│   └── project_name/
│       └── kernel_name/
│           ├── system_estimate_kernel.xtxt  # Resource estimates
│           └── hls_synthesis_report.rpt     # Detailed HLS report
└── logs/
    └── project_name_build.log  # Build log
```

---

## Run Template (`fpga_run_template.sh`)

Links kernels, compiles host, and executes the application.

### Basic Syntax

```bash
./fpga_run_template.sh [OPTIONS]
```

### Required Options

| Option | Description | Example |
|--------|-------------|---------|
| `-p, --project NAME` | Project name (should match build) | `-p my_project` |
| `-x, --xo FILES` | Kernel .xo files (space-separated, quoted if multiple) | `-x "kernel.xo"` |
| `-H, --host FILE` | Host source file (.cpp) | `-H host.cpp` |

### Common Options

| Option | Description | Default | Example |
|--------|-------------|---------|---------|
| `-B, --board BOARD` | Target board (same as build) | - | `-B u200` |
| `-t, --target TYPE` | Build target (same as build) | `hw_emu` | `-t hw_emu` |
| `-c, --auto-cleanup` | Auto-cleanup temporary files | Off | `-c` |

### Workflow Control Options

| Option | Description | Use Case |
|--------|-------------|----------|
| `--skip-link` | Skip linking (use existing .xclbin) | Host code changed only |
| `--skip-compile` | Skip host compilation (use existing .exe) | Just re-run |
| `--skip-run` | Only link and compile, don't execute | Build artifacts only |

### Optional Options

| Option | Description | Default | Example |
|--------|-------------|---------|---------|
| `-b, --binary NAME` | Binary container name | `binary_container.xclbin` | `-b my_app.xclbin` |
| `-e, --exe NAME` | Host executable name | `host.exe` | `-e my_app.exe` |
| `-d, --dir PATH` | Project directory | Current dir | `-d /path/to/project` |
| `-h, --help` | Show help message | - | `-h` |

### Examples

**Basic run:**
```bash
./fpga_run_template.sh \
    -p vector_add \
    -x "results/kernels/vadd.xo" \
    -H host.cpp \
    -B u200 \
    -t hw_emu
```

**Multiple kernels:**
```bash
./fpga_run_template.sh \
    -p pipeline \
    -x "results/kernels/encode.xo results/kernels/decode.xo" \
    -H host.cpp \
    -B u250 \
    -t hw_emu \
    -c
```

**Re-compile host only (kernel unchanged):**
```bash
# Initial build
./fpga_run_template.sh -p test -x "kernel.xo" -H host.cpp -B u200 -t hw_emu

# Modified host code? Skip linking (saves 30+ minutes!)
./fpga_run_template.sh -p test -x "kernel.xo" -H host_v2.cpp -B u200 -t hw_emu --skip-link
```

**Just re-run (no rebuild):**
```bash
./fpga_run_template.sh -p test -x "kernel.xo" -H host.cpp --skip-link --skip-compile -t hw_emu
```

**Build artifacts only (don't run):**
```bash
./fpga_run_template.sh -p test -x "kernel.xo" -H host.cpp -B u200 -t hw --skip-run
```

### Output Files

```
project_directory/
├── binary_container.xclbin     # Linked FPGA binary
├── host.exe                    # Compiled host executable
├── emconfig.json               # Emulation configuration
└── results/
    └── logs/
        ├── project_link.log    # Linking log
        └── run_project.log     # Execution log
```

---

## Common Flag Combinations

### Development (Fast Iteration)

```bash
# Build + run with cleanup
./fpga_build_template.sh -p dev -k kernel -s kernel.cpp -b u200 -t sw_emu -c
./fpga_run_template.sh -p dev -x "results/kernels/kernel.xo" -H host.cpp -B u200 -t sw_emu -c
```

### Optimization (Check Resources)

```bash
# Build for hw_emu
./fpga_build_template.sh -p opt -k kernel -s kernel.cpp -b u200 -t hw_emu -c

# Check resources before running
grep "LUT\|FF\|BRAM\|DSP" results/reports/opt/kernel/system_estimate*.xtxt

# Run
./fpga_run_template.sh -p opt -x "results/kernels/kernel.xo" -H host.cpp -B u200 -t hw_emu -c
```

### Production (Hardware Build)

```bash
# Build for hardware (takes 2-6 hours)
./fpga_build_template.sh -p prod -k kernel -s kernel.cpp -b u200 -t hw -c

# Run on real FPGA
./fpga_run_template.sh -p prod -x "results/kernels/kernel.xo" -H host.cpp -B u200 -t hw -c

# Archive the build
tar -czf prod_v1.0.tar.gz results/ *.xclbin host.exe
```

---

## Board Selection

### Supported Boards

| Flag | Board | Platform Auto-Detected |
|------|-------|----------------------|
| `-b u200` | Alveo U200 | `xilinx_u200_gen3x16_xdma_*` |
| `-b u250` | Alveo U250 | `xilinx_u250_gen3x16_xdma_*` |
| `-b u280` | Alveo U280 | `xilinx_u280_xdma_*` |
| `-b u50` | Alveo U50 | `xilinx_u50_gen3x16_xdma_*` |
| `-b u55c` | Alveo U55C | `xilinx_u55c_gen3x16_xdma_*` |
| `-b vck190` | Versal VCK190 | `xilinx_vck190_*` |

### Custom Platform

```bash
# Use -P to specify exact platform
./fpga_build_template.sh \
    -p test \
    -k kernel \
    -s kernel.cpp \
    -P xilinx_u200_gen3x16_xdma_2_202110_1 \
    -t hw_emu
```

---

## Environment Variables

### Override Default Paths

```bash
# Custom Vitis installation
export VITIS_PATH=/custom/vitis/2024.2
./fpga_build_template.sh ...

# Custom XRT installation
export XRT_PATH=/custom/xrt
./fpga_run_template.sh ...

# Custom platform location
export PLATFORM_PATH=/custom/platforms
./fpga_build_template.sh ...
```

---

## Error Messages

### Common Errors and Solutions

**"Platform not found"**
```bash
# Check available platforms
platforminfo --list

# Use -P to specify exact platform
./fpga_build_template.sh -P xilinx_u200_gen3x16_xdma_2_202110_1 ...
```

**"Vitis not found"**
```bash
# Set VITIS_PATH
export VITIS_PATH=/tools/Xilinx/Vitis/2024.2
./fpga_build_template.sh ...
```

**"Disk quota exceeded"**
```bash
# Check /tmp space
df -h /tmp

# Clean old builds
rm -rf /tmp/${USER}_fpga_builds/*
rm -rf /tmp/${USER}_fpga_runs/*

# Always use -c flag for auto-cleanup
./fpga_build_template.sh -c ...
```

**"Kernel not found in xclbin"**
```bash
# Ensure kernel name matches
# In kernel: void vadd(...)
# In command: -k vadd
```

---

## Tips and Tricks

### Save Time with --skip Flags

```bash
# Initial build and run
./fpga_run_template.sh -p test -x kernel.xo -H host.cpp -B u200 -t hw_emu

# Modified host only? Skip linking (saves 30-60 minutes)
./fpga_run_template.sh -p test -x kernel.xo -H host_v2.cpp -B u200 -t hw_emu --skip-link

# Just testing different data? Skip everything (instant run)
./fpga_run_template.sh -p test -x kernel.xo -H host.cpp --skip-link --skip-compile -t hw_emu
```

### Check Resources Before Hardware Build

```bash
# Build hw_emu first
./fpga_build_template.sh -p test -k kernel -s kernel.cpp -b u200 -t hw_emu -c

# Check if it fits
cat results/reports/test/kernel/system_estimate_kernel.xtxt

# If resources look good, build hardware
./fpga_build_template.sh -p test -k kernel -s kernel.cpp -b u200 -t hw -c
```

### Always Use Auto-Cleanup

```bash
# Add -c flag to save disk space
./fpga_build_template.sh ... -c
./fpga_run_template.sh ... -c
```

---

## Next Steps

- [Quick start guide](QUICK_START.md) - Get started quickly
- [HLS tutorial](HLS_TUTORIAL.md) - Learn HLS programming
- [Build targets explained](BUILD_TARGETS.md) - When to use each target
- [Advanced usage](ADVANCED_USAGE.md) - Makefiles, CI/CD, profiling