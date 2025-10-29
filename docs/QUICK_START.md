# Quick Start Guide

## Installation

```bash
# 1. Clone the repository
git clone https://github.com/abdullahsahruri/xilinx-fpga-templates.git
cd xilinx-fpga-templates

# 2. Make scripts executable
chmod +x fpga_build_template.sh fpga_run_template.sh

# 3. Ready to use!
```

## Installation Options

### Option A: Use Directly (No Setup Required)

```bash
# Run from anywhere using full path
~/xilinx-fpga-templates/fpga_build_template.sh -p my_project -k kernel -s kernel.cpp
```

### Option B: Add to PATH (Recommended)

```bash
# Add to your ~/.bashrc
echo 'export PATH=$PATH:$HOME/xilinx-fpga-templates' >> ~/.bashrc
source ~/.bashrc

# Now use from anywhere
fpga_build_template.sh -p my_project -k kernel -s kernel.cpp
```

### Option C: Create Aliases (Shortest Commands)

```bash
# Add to your ~/.bashrc
echo 'alias fpga-build="$HOME/xilinx-fpga-templates/fpga_build_template.sh"' >> ~/.bashrc
echo 'alias fpga-run="$HOME/xilinx-fpga-templates/fpga_run_template.sh"' >> ~/.bashrc
source ~/.bashrc

# Now use with short commands
fpga-build -p my_project -k kernel -s kernel.cpp
fpga-run -p my_project -x kernel.xo -H host.cpp
```

---

## Basic Usage

### Step 1: Build Kernel (HLS Compilation)

```bash
./fpga_build_template.sh \
    -p my_project \      # Project name
    -k my_kernel \       # Kernel function name
    -s kernel.cpp \      # Source file
    -b u200 \            # Target board
    -t hw_emu            # Build target

# Output: results/kernels/my_kernel.xo
```

### Step 2: Link and Run

```bash
./fpga_run_template.sh \
    -p my_project \                      # Same project name
    -x "results/kernels/my_kernel.xo" \  # Compiled kernel
    -H host.cpp \                        # Host application
    -B u200 \                            # Same board
    -t hw_emu                            # Same target

# Output: Compiled binary + execution results
```

---

## Complete Example: Vector Addition

```bash
# Assume you have:
# - vector_add.cpp (kernel)
# - host.cpp (host application)

# Build kernel
./fpga_build_template.sh \
    -p vector_add \
    -k vadd \
    -s vector_add.cpp \
    -b u200 \
    -t hw_emu \
    -c

# Link and run
./fpga_run_template.sh \
    -p vector_add \
    -x "results/kernels/vadd.xo" \
    -H host.cpp \
    -B u200 \
    -t hw_emu \
    -c

# Expected output: "TEST PASSED"
```

---

## Running the Included Example

```bash
cd examples/vector_add

# Software emulation (fastest - 1-5 minutes)
../../fpga_build_template.sh -p vector_add -k vadd -s vector_add.cpp -b u200 -t sw_emu -c
../../fpga_run_template.sh -p vector_add -x "results/kernels/vadd.xo" -H host.cpp -B u200 -t sw_emu -c

# Hardware emulation (slower - 30-60 minutes)
../../fpga_build_template.sh -p vector_add -k vadd -s vector_add.cpp -b u200 -t hw_emu -c
../../fpga_run_template.sh -p vector_add -x "results/kernels/vadd.xo" -H host.cpp -B u200 -t hw_emu -c
```

---

## Supported Platforms

| Board | Short Name | Memory | Use Case |
|-------|------------|--------|----------|
| Alveo U200 | `u200` | 64GB DDR4 | General development |
| Alveo U250 | `u250` | 64GB DDR4 | High bandwidth |
| Alveo U280 | `u280` | 8GB HBM2 + 32GB DDR4 | AI/ML workloads |
| Alveo U50 | `u50` | 8GB HBM2 | Compact form factor |
| Alveo U55C | `u55c` | 16GB HBM2 | Compute/crypto |
| Versal VCK190 | `vck190` | DDR4 + LPDDR4 | AI Engine |

**Auto-detection:** Just specify `-b u200` and the scripts find the full platform name automatically.

---

## Directory Structure After Build

```
your_project/
├── kernel.cpp                    # Your kernel (input)
├── host.cpp                      # Your host code (input)
├── results/
│   ├── kernels/
│   │   └── kernel.xo             # Compiled kernel
│   ├── reports/
│   │   └── project/kernel/       # Resource reports
│   └── logs/                     # Build/run logs
├── binary_container.xclbin       # Linked binary
├── host.exe                      # Compiled host
└── emconfig.json                 # Emulation config

/tmp/${USER}_fpga_builds/         # Temporary files (auto-cleaned)
```

**Key benefit:** Large temporary files stay in `/tmp`, avoiding disk quota issues.

---

## Next Steps

- **[Learn HLS basics](HLS_TUTORIAL.md)** - Write your first kernel
- **[Understand build targets](BUILD_TARGETS.md)** - When to use sw_emu vs hw_emu vs hw
- **[Command reference](COMMAND_REFERENCE.md)** - All available options
- **[See complete example](../examples/vector_add/README.md)** - Full code walkthrough

---

## Quick Tips

1. **Start with sw_emu** - Fast iteration for debugging
2. **Use hw_emu before hw** - Catch resource issues early
3. **Enable auto-cleanup** - Add `-c` flag to save disk space
4. **Check resources** - `cat results/reports/*/system_estimate*.xtxt`