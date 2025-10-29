# FPGA Build & Run Templates for Xilinx Vitis

> **Simplified, reusable shell scripts for building and running Xilinx FPGA designs with Vitis HLS**

A complete workflow automation for Xilinx/AMD Alveo FPGA development that handles HLS compilation, kernel linking, host compilation, and execution - with automatic platform detection, /tmp-based builds to avoid disk quota issues, and seamless integration with official Xilinx examples.

---

## 🎯 Problem Statement

FPGA development with Xilinx Vitis involves complex workflows:
- **Long build times** (2-6 hours for hardware builds)
- **Disk quota issues** (multi-GB temporary files filling home directories)
- **Complex build commands** (remembering v++ flags, platform strings, environment setup)
- **Iterative debugging** (choosing between sw_emu, hw_emu, hw targets)
- **Platform management** (different boards: U200, U250, U280, etc.)

**This toolkit solves these problems** with simple, reusable scripts that automate the entire workflow.

---

## ✨ Features

### 🔧 Build Template (`fpga_build_template.sh`)
- ✅ **HLS Kernel Compilation** - Compile C++/HLS to .xo kernel objects
- ✅ **Automatic Platform Detection** - Supports U200, U250, U280, U50, U55C, VCK190
- ✅ **Environment Setup** - Auto-sources Vitis and XRT
- ✅ **/tmp Temporary Files** - Avoids home directory quota issues
- ✅ **Resource Reporting** - Automatic LUT/FF/BRAM extraction
- ✅ **Multi-Target Support** - sw_emu, hw_emu, hw

### 🚀 Run Template (`fpga_run_template.sh`)
- ✅ **Kernel Linking** - Link multiple .xo files into .xclbin
- ✅ **Host Compilation** - Compile host code with XRT libraries
- ✅ **Emulation Setup** - Automatic emconfig.json generation
- ✅ **Execution** - Run applications on emulation or hardware
- ✅ **Workflow Control** - Skip individual steps (--skip-link, --skip-compile, --skip-run)
- ✅ **Result Organization** - Clean separation of temporary and final files

### 📚 Comprehensive Documentation
- 📖 Detailed user guides for both templates
- 🎓 Explanation of sw_emu vs hw_emu vs hw
- 💡 Real-world scenarios and troubleshooting
- 🔗 Integration with official Xilinx examples
- 📋 Best practices and optimization tips

---

## 📦 What's Included

```
.
├── fpga_build_template.sh           # HLS build script (kernel.cpp → kernel.xo)
├── fpga_run_template.sh             # Link/run script (.xo + host.cpp → execution)
├── README.md                         # This file (main documentation)
├── README_FPGA_BUILD_TEMPLATE.md    # Detailed build template guide
└── README_FPGA_RUN_TEMPLATE.md      # Detailed run template guide
```

---

## 🚀 Quick Start

### Installation

```bash
# 1. Clone the templates
git clone https://github.com/abdullahsahruri/xilinx-fpga-templates.git
cd xilinx-fpga-templates

# 2. Make scripts executable
chmod +x fpga_build_template.sh fpga_run_template.sh

# 3. Ready to use! Run from this directory or add to your PATH
```

**Option A: Use directly** (no PATH needed)
```bash
# Run from anywhere using full path
~/xilinx-fpga-templates/fpga_build_template.sh -p my_project -k kernel -s kernel.cpp
```

**Option B: Add to your personal PATH** (recommended)
```bash
# Add to your ~/.bashrc or ~/.bash_profile
echo 'export PATH=$PATH:$HOME/xilinx-fpga-templates' >> ~/.bashrc
source ~/.bashrc

# Now use from anywhere
fpga_build_template.sh -p my_project -k kernel -s kernel.cpp
```

**Option C: Create aliases** (for shorter commands)
```bash
# Add to your ~/.bashrc
echo 'alias fpga-build="$HOME/xilinx-fpga-templates/fpga_build_template.sh"' >> ~/.bashrc
echo 'alias fpga-run="$HOME/xilinx-fpga-templates/fpga_run_template.sh"' >> ~/.bashrc
source ~/.bashrc

# Now use with short commands
fpga-build -p my_project -k kernel -s kernel.cpp
fpga-run -p my_project -x kernel.xo -H host.cpp
```

### Basic Usage

#### Step 1: Build Kernel (HLS Compilation)

```bash
./fpga_build_template.sh \
    -p my_project \
    -k my_kernel \
    -s kernel.cpp \
    -b u200 \
    -t hw_emu

# Output: results/kernels/my_kernel.xo
```

#### Step 2: Link and Run

```bash
./fpga_run_template.sh \
    -p my_project \
    -x "results/kernels/my_kernel.xo" \
    -H host.cpp \
    -B u200 \
    -t hw_emu

# Output: Compiled binary, execution results
```

### Complete Example: Vector Addition

```bash
# Assume you have:
# - vector_add.cpp (kernel)
# - host.cpp (host application)

# Build kernel for hardware emulation
./fpga_build_template.sh \
    -p vector_add \          # Project name for organizing results
    -k vadd \                # Kernel function name in your code
    -s vector_add.cpp \      # Source file containing kernel
    -b u200 \                # Target board (Alveo U200)
    -t hw_emu \              # Hardware emulation (validates performance)
    -c                       # Auto-cleanup temporary files

# Link kernel and run
./fpga_run_template.sh \
    -p vector_add \          # Same project name
    -x "results/kernels/vadd.xo" \  # Compiled kernel from build step
    -H host.cpp \            # Host application source
    -B u200 \                # Same target board
    -t hw_emu \              # Same target (hardware emulation)
    -c                       # Auto-cleanup temporary files

# Expected output: "TEST PASSED"
```

---

## 🎓 Understanding Build Targets

### sw_emu (Software Emulation) - "Does it work?"
- **Build time:** 1-5 minutes
- **Purpose:** Verify functional correctness
- **Use when:** Debugging algorithms, testing logic
- **No** hardware synthesis

```bash
# Fast iteration for debugging
./fpga_build_template.sh -t sw_emu -p debug -k kernel -s kernel.cpp
./fpga_run_template.sh -t sw_emu -p debug -x kernel.xo -H host.cpp
```

### hw_emu (Hardware Emulation) - "How fast is it?"
- **Build time:** 30-60 minutes
- **Purpose:** Performance validation, resource estimation
- **Use when:** Optimizing HLS pragmas, checking resources
- **Full** HLS synthesis + RTL simulation

```bash
# Performance validation
./fpga_build_template.sh -t hw_emu -p optimized -k kernel -s kernel.cpp
./fpga_run_template.sh -t hw_emu -p optimized -x kernel.xo -H host.cpp

# Check resources
grep "LUT" results/reports/*/system_estimate*.xtxt
```

### hw (Hardware) - "Production ready"
- **Build time:** 2-6 hours
- **Purpose:** Final deployment, real performance
- **Use when:** After hw_emu validation, for production
- **Full** FPGA compilation (place & route)

```bash
# Final hardware build (start before lunch!)
./fpga_build_template.sh -t hw -p production -k kernel -s kernel.cpp

# Run on actual FPGA
./fpga_run_template.sh -t hw -p production -x kernel.xo -H host.cpp
```

### 📊 Development Workflow

```
Stage 1: sw_emu (minutes)
  ├─ Write initial kernel
  ├─ Test functionality
  ├─ Fix bugs rapidly
  └─ Iterate 10-50 times
      ↓
Stage 2: hw_emu (hours)
  ├─ Add HLS pragmas
  ├─ Optimize performance
  ├─ Check resources
  └─ Iterate 5-15 times
      ↓
Stage 3: hw (days)
  ├─ Build final bitstream
  ├─ Test on hardware
  └─ Deploy (1-3 builds)
```

**Time Savings:** Following this workflow saves **5-10 days** compared to building hardware directly.

---

## 📋 Command Reference

### Build Template Options

```bash
./fpga_build_template.sh [OPTIONS]

Required:
  -p, --project NAME      Project name
  -k, --kernel NAME       Kernel function name
  -s, --source FILE       Source file (.cpp)

Common:
  -b, --board BOARD       Board: u200, u250, u280, u50, u55c, vck190
  -t, --target TYPE       Target: sw_emu, hw_emu, hw (default: hw_emu)
  -c, --auto-cleanup      Auto-cleanup temp files

Optional:
  -d, --dir PATH          Project directory (default: current)
  -o, --optimize LEVEL    Optimization level 0-3 (default: 3)
  -P, --platform NAME     Override platform string
```

### Run Template Options

```bash
./fpga_run_template.sh [OPTIONS]

Required:
  -p, --project NAME      Project name
  -x, --xo FILES          Kernel .xo files (space-separated, quoted)
  -H, --host FILE         Host source file (.cpp)

Common:
  -B, --board BOARD       Board: u200, u250, u280, etc.
  -t, --target TYPE       Target: sw_emu, hw_emu, hw
  -c, --auto-cleanup      Auto-cleanup temp files

Workflow Control:
  --skip-link             Skip linking (use existing .xclbin)
  --skip-compile          Skip host compilation (use existing .exe)
  --skip-run              Only link and compile, don't execute

Optional:
  -b, --binary NAME       Binary container name (default: binary_container.xclbin)
  -e, --exe NAME          Host executable name (default: host.exe)
  -d, --dir PATH          Project directory
```

---

## 🌟 Usage Examples

### Example 1: Quick Re-runs (Development Iteration)

```bash
# Initial build and run
./fpga_build_template.sh -p dev -k kernel -s kernel.cpp -t hw_emu
./fpga_run_template.sh -p dev -x results/kernels/kernel.xo -H host.cpp -t hw_emu

# Modified host code only? Skip linking
./fpga_run_template.sh -p dev -x results/kernels/kernel.xo -H host_v2.cpp --skip-link -t hw_emu

# Just re-run with different data? Skip everything
./fpga_run_template.sh -p dev -x kernel.xo -H host.cpp --skip-link --skip-compile -t hw_emu
```

---

## 🔗 Integration with Xilinx Examples

These templates work seamlessly with official AMD/Xilinx repositories:

### Vitis Acceleration Examples

```bash
# Clone official examples
git clone https://github.com/Xilinx/Vitis_Accel_Examples.git
cd Vitis_Accel_Examples
git checkout 2024.1

# Navigate to hello_world
cd host_xrt/hello_world

# Build using our template
/path/to/fpga_build_template.sh \
    -p hello_world_xrt \
    -k vadd \
    -s src/vadd.cpp \
    -b u200 \
    -t hw_emu

# Run using our template
/path/to/fpga_run_template.sh \
    -p hello_world_xrt \
    -x "results/kernels/vadd.xo" \
    -H src/host.cpp \
    -B u200 \
    -t hw_emu
```

**Official repositories to explore:**
- [Vitis_Accel_Examples](https://github.com/Xilinx/Vitis_Accel_Examples) - Host+kernel examples for Alveo
- [Vitis-HLS-Introductory-Examples](https://github.com/Xilinx/Vitis-HLS-Introductory-Examples) - HLS optimization techniques
- [Vitis-Tutorials](https://github.com/Xilinx/Vitis-Tutorials) - Comprehensive learning paths

See [README_FPGA_RUN_TEMPLATE.md](README_FPGA_RUN_TEMPLATE.md#learning-from-xilinx-official-examples) for detailed integration guide.

---

## 📁 Directory Structure

### Input (Your Project)
```
your_project/
├── kernel.cpp          # Your HLS kernel
├── host.cpp            # Your host application
└── kernel.h            # Optional headers
```

### Output (Generated by Templates)
```
your_project/
├── results/
│   ├── kernels/
│   │   └── my_kernel.xo              # Compiled kernel
│   ├── reports/
│   │   └── my_project/
│   │       └── my_kernel/
│   │           ├── system_estimate_my_kernel.xtxt
│   │           └── hls_synthesis_report.rpt
│   └── logs/
│       ├── my_project_build.log      # Build log
│       ├── my_project_link.log       # Link log
│       └── run_my_project.log        # Execution log
├── binary_container.xclbin            # Linked binary (from run template)
├── host.exe                           # Compiled host (from run template)
└── emconfig.json                      # Emulation config (from run template)

/tmp/${USER}_fpga_builds/              # Temporary build files (auto-cleaned)
└── my_project_<PID>/
    └── _x/                            # Multi-GB temporary files

/tmp/${USER}_fpga_runs/                # Temporary run files (auto-cleaned)
└── my_project_<PID>/
    └── _x/                            # Linking temporary files
```

**Key Benefits:**
- ✅ Small result files in home directory (reports, logs, .xo, .xclbin)
- ✅ Large temporary files in /tmp (avoids disk quota)
- ✅ Easy cleanup after builds
- ✅ Organized, predictable structure

---

## 🎯 Supported Platforms

| Board | Platform | Memory | Use Case |
|-------|----------|--------|----------|
| **U200** | `xilinx_u200_gen3x16_xdma_*` | 64GB DDR4 | General development |
| **U250** | `xilinx_u250_gen3x16_xdma_*` | 64GB DDR4 | High bandwidth apps |
| **U280** | `xilinx_u280_xdma_*` | 8GB HBM2 + 32GB DDR4 | AI/ML workloads |
| **U50** | `xilinx_u50_gen3x16_xdma_*` | 8GB HBM2 | Compact form factor |
| **U55C** | `xilinx_u55c_gen3x16_xdma_*` | 16GB HBM2 | Compute/crypto |
| **VCK190** | `xilinx_vck190_*` | DDR4 + LPDDR4 | Versal AI engine |

**Auto-detection:** Just specify `-b u200` or `-B u280` - the scripts automatically find the full platform string.

**Custom platforms:** Use `-P platform_full_name` to override.

---

## 🛠️ Advanced Usage

### Environment Variables

Override default paths:

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

### Makefile Integration

```makefile
PROJECT = my_fpga_app
KERNEL = accel_kernel
KERNEL_SRC = kernel.cpp
HOST_SRC = host.cpp
BOARD = u200
TARGET = hw_emu

BUILD = /path/to/fpga_build_template.sh
RUN = /path/to/fpga_run_template.sh

.PHONY: all build run clean hw

all: build run

build:
	$(BUILD) -p $(PROJECT) -k $(KERNEL) -s $(KERNEL_SRC) \
		-b $(BOARD) -t $(TARGET) -c

run:
	$(RUN) -p $(PROJECT) -x "results/kernels/$(KERNEL).xo" \
		-H $(HOST_SRC) -B $(BOARD) -t $(TARGET) -c

hw: TARGET = hw
hw: build

clean:
	rm -rf results *.xclbin *.exe emconfig.json
	rm -rf /tmp/${USER}_fpga_builds/$(PROJECT)_*
	rm -rf /tmp/${USER}_fpga_runs/$(PROJECT)_*
```

Usage:
```bash
make build      # Build kernel
make run        # Link and run
make hw         # Build for hardware
make clean      # Clean all artifacts
```

### CI/CD Integration

```bash
#!/bin/bash
# ci_fpga_build.sh - Automated CI pipeline

set -e

PROJECT="ci_build"
KERNEL="test_kernel"

# Stage 1: Quick functional test (sw_emu)
echo "=== Stage 1: Functional Test ==="
./fpga_build_template.sh -p ${PROJECT}_swemu -k ${KERNEL} -s kernel.cpp -t sw_emu -c
./fpga_run_template.sh -p ${PROJECT}_swemu -x results/kernels/${KERNEL}.xo -H host.cpp -t sw_emu -c

# Stage 2: Performance validation (hw_emu)
echo "=== Stage 2: Performance Validation ==="
./fpga_build_template.sh -p ${PROJECT}_hwemu -k ${KERNEL} -s kernel.cpp -t hw_emu -c

# Check resource usage
LUT_COUNT=$(grep -oP 'LUT.*\K[0-9]+' results/reports/*/system_estimate*.xtxt | head -1)
if [ "$LUT_COUNT" -gt 1000000 ]; then
    echo "ERROR: Resource usage too high (${LUT_COUNT} LUTs)"
    exit 1
fi

./fpga_run_template.sh -p ${PROJECT}_hwemu -x results/kernels/${KERNEL}.xo -H host.cpp -t hw_emu -c

echo "=== CI Pipeline Passed ==="
```

---

## 📖 Documentation

### Quick References
- **This file (README.md)**: Overview and quick start
- **[README_FPGA_BUILD_TEMPLATE.md](README_FPGA_BUILD_TEMPLATE.md)**: Detailed build template guide
- **[README_FPGA_RUN_TEMPLATE.md](README_FPGA_RUN_TEMPLATE.md)**: Detailed run template guide

### Topics Covered in Detailed Docs

**Build Template Guide:**
- Complete option reference
- Board detection and platform management
- Resource utilization reporting
- Performance tips and optimization
- Troubleshooting common issues

**Run Template Guide:**
- Why sw_emu vs hw_emu vs hw (with scenarios)
- Linking multiple kernels
- Host code requirements (OpenCL vs XRT Native API)
- Profiling and debugging
- Integration with Xilinx examples
- Real-world development workflows

---

## ❓ FAQ

**Q: Do I need to modify the scripts for my project?**
A: No! The scripts are completely generic. Just specify your project name, kernel name, and source files as command-line arguments.

**Q: Can I use these with existing Makefiles?**
A: Yes. You can call these scripts from Makefiles, CI/CD pipelines, or other automation tools.

**Q: What if I have a custom platform not listed?**
A: Use `-P platform_full_name` to specify the exact platform string.

**Q: How do I add custom v++ flags?**
A: Edit the `run_hls_synthesis()` or `link_kernels()` functions in the scripts to add your flags.

**Q: Do these work with RTL kernels (Verilog/VHDL)?**
A: The build template is HLS-specific, but the run template works with any .xo files (HLS or RTL).

**Q: Can I run multiple builds in parallel?**
A: Yes! Each build creates a unique temp directory using the process ID, so they won't conflict.

**Q: How do I clean up old builds?**
A: Use `-c` flag for auto-cleanup, or manually: `rm -rf /tmp/${USER}_fpga_builds/*`

**Q: What versions of Vitis are supported?**
A: Tested with Vitis 2023.2 and 2024.1+. Should work with any recent Vitis version.

---

## 🐛 Troubleshooting

### "Platform not found"
```bash
# Check available platforms
platforminfo --list

# Or specify exact platform
./fpga_build_template.sh -P xilinx_u200_gen3x16_xdma_2_202110_1 ...
```

### "Disk quota exceeded"
```bash
# Check /tmp space
df -h /tmp

# Clean old builds
rm -rf /tmp/${USER}_fpga_builds/*
rm -rf /tmp/${USER}_fpga_runs/*
```

### "Vitis not found"
```bash
# Set custom Vitis path
export VITIS_PATH=/tools/Xilinx/Vitis/2024.2
./fpga_build_template.sh ...
```

### "Build fails with syntax errors"
```bash
# Test with sw_emu first (fast iteration)
./fpga_build_template.sh -t sw_emu ...
# Fix syntax errors in kernel.cpp
# Then try hw_emu
./fpga_build_template.sh -t hw_emu ...
```

### "Routing failed - too many resources"
```bash
# Check resources in hw_emu first
./fpga_build_template.sh -t hw_emu ...
grep "LUT" results/reports/*/system_estimate*.xtxt

# If too high, reduce parallelization
# Edit kernel: factor=32 → factor=16
vim kernel.cpp

# Rebuild and check
./fpga_build_template.sh -t hw_emu ...
```

See detailed troubleshooting in the individual README files.

---

## 🎓 Best Practices

1. **Always start with sw_emu**
   - Catch functional bugs quickly (minutes, not hours)
   - Use for algorithm development and debugging

2. **Validate with hw_emu before hw**
   - Check resource usage and performance
   - Saves hours of wasted hardware builds

3. **Use appropriate dataset sizes**
   - sw_emu: Any size (runs on CPU)
   - hw_emu: Small representative datasets (RTL simulation is slow)
   - hw: Full datasets (real hardware speed)

4. **Enable auto-cleanup** (`-c` flag)
   - Saves disk space
   - Keeps /tmp clean

5. **Version control your kernels, not binaries**
   - .xo and .xclbin files are large
   - Commit source code (.cpp, .h)
   - Document build configurations

6. **Archive important hardware builds**
   - Hardware builds take hours
   - Save .xclbin files for important milestones
   ```bash
   tar -czf production_v1.0_hw.tar.gz results/ *.xclbin
   ```

7. **Use profiling data**
   - Modify scripts to add `--profile.data all:all:all`
   - Analyze with `vitis_analyzer profile_summary.csv`
   - Optimize based on bottlenecks

---

## 🤝 Contributing

Contributions are welcome! Areas for improvement:

- [ ] Additional board support (Versal, Zynq UltraScale+)
- [ ] Pre-built host code templates
- [ ] Automated resource checking with warnings
- [ ] Integration with Vivado for RTL kernels
- [ ] Docker container support
- [ ] Automated performance regression testing

---

## 📄 License

This project is provided as-is for educational and research purposes. Use at your own discretion.

For Xilinx/AMD tool licenses, refer to your Vitis installation agreement.

---

## 🙏 Acknowledgments

- **AMD/Xilinx** for Vitis HLS and comprehensive documentation
- **Xilinx Example Repositories**: [Vitis_Accel_Examples](https://github.com/Xilinx/Vitis_Accel_Examples), [Vitis-HLS-Introductory-Examples](https://github.com/Xilinx/Vitis-HLS-Introductory-Examples)
- FPGA developer community for feedback and testing

---

## 📞 Support

**For template issues:**
- Open an issue in this repository
- Check detailed documentation in README_FPGA_*.md files

**For Xilinx Vitis issues:**
- [Vitis Documentation](https://docs.xilinx.com/r/en-US/ug1416-vitis-documentation)
- [Xilinx Forums](https://support.xilinx.com/s/topic/0TO2E000000YKY3WAO/vitis-acceleration)
- [AMD Developer Zone](https://developer.amd.com/xilinx/)

---

## 🚀 Quick Links

- [Build Template Documentation](README_FPGA_BUILD_TEMPLATE.md) - HLS compilation details
- [Run Template Documentation](README_FPGA_RUN_TEMPLATE.md) - Linking and execution details
- [Vitis HLS User Guide](https://docs.xilinx.com/r/en-US/ug1399-vitis-hls) - Official HLS documentation
- [XRT Documentation](https://xilinx.github.io/XRT/) - Xilinx Runtime Library

---

<p align="center">
  <strong>Built with ❤️ for the FPGA development community</strong>
</p>

<p align="center">
  <sub>Simplifying FPGA workflows, one script at a time</sub>
</p>