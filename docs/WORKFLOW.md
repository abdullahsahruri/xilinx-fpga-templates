# Complete FPGA Development Workflow

This guide shows the **complete end-to-end workflow** from environment setup to final cleanup using the FPGA templates.

---

## Overview: The Complete Workflow

```
1. Setup Environment     → source setup_env.sh
2. Build Kernel          → fpga_build_template.sh
3. Link & Run            → fpga_run_template.sh
4. Extract Resources     → fpga_extract_resources.sh
5. Cleanup Temp Files    → fpga_cleanup_builds.sh
```

---

## Step 1: Setup Environment (Optional)

The scripts auto-source Vitis/XRT, but you can setup manually for consistency:

```bash
# Source the environment setup script
source setup_env.sh [platform] [mode]

# Examples:
source setup_env.sh                  # Default: u200, hw_emu
source setup_env.sh u280 hw_emu      # U280 board, hw_emu mode
source setup_env.sh u200 hw          # U200 board, hw mode
```

**What it does:**
- ✓ Sources Vitis (2024.2, 2024.1, etc.)
- ✓ Sources XRT (Xilinx Runtime)
- ✓ Sets `FPGA_TARGET_PLATFORM` environment variable
- ✓ Sets `XCL_EMULATION_MODE` (sw_emu, hw_emu, hw)

**Skip this step if:** The build scripts will auto-detect and source tools automatically.

---

## Step 2: Build Kernel (HLS Compilation)

Compile your kernel source code to a Xilinx object file (`.xo`):

```bash
./fpga_build_template.sh \
    -p <project_name> \
    -k <kernel_function_name> \
    -s <source_file.cpp> \
    -b <board> \
    -t <target>

# Example:
./fpga_build_template.sh \
    -p my_accelerator \
    -k process_data \
    -s kernel.cpp \
    -b u200 \
    -t hw_emu
```

**Common Options:**
- `-p` : Project name (used for output directories)
- `-k` : Kernel function name (must match `extern "C"` function in code)
- `-s` : Source file path
- `-b` : Board: `u200`, `u250`, `u280`, `u50`, `u55c`, `vck190`
- `-t` : Target: `sw_emu`, `hw_emu`, `hw`

**Output:**
- `results/kernels/<kernel_name>.xo` - Compiled kernel object

**Time Estimates:**
- sw_emu: 1-5 minutes
- hw_emu: 15-60 minutes
- hw: 2-6 hours

---

## Step 3: Link and Run

Link the kernel with the host application and execute:

```bash
./fpga_run_template.sh \
    -p <project_name> \
    -x "results/kernels/<kernel_name>.xo" \
    -H <host_source.cpp> \
    -B <board> \
    -t <target>

# Example:
./fpga_run_template.sh \
    -p my_accelerator \
    -x "results/kernels/process_data.xo" \
    -H host.cpp \
    -B u200 \
    -t hw_emu
```

**What it does:**
1. Links kernel(s) into an XCLBIN binary
2. Compiles host application
3. Runs the host application (sw_emu/hw_emu modes)

**Output:**
- `binary_container.xclbin` - Linked FPGA binary
- `host.exe` - Compiled host executable
- Execution results in console

---

## Step 4: Extract Resources

After hw_emu or hw builds, extract resource utilization data:

```bash
# Interactive mode - select builds
./fpga_extract_resources.sh

# Extract all builds
./fpga_extract_resources.sh --all

# Extract specific project
./fpga_extract_resources.sh --project my_accelerator

# Save to file
./fpga_extract_resources.sh --all --output resources.txt

# Export as CSV for spreadsheet
./fpga_extract_resources.sh --all --format csv --output resources.csv

# Export as Markdown table for documentation
./fpga_extract_resources.sh --all --format markdown --output resources.md
```

**What it extracts:**
- Build type (hw_emu or hw)
- Target and estimated clock frequencies
- Resource utilization (LUT, FF, DSP, BRAM, URAM)
- **For hw builds:** Both estimated and actual post-implementation resources

**Example Output (text format):**
```
Build: my_accelerator_hw
Type: hw
  Target Clock:    300MHz
  Est. Frequency:  411MHz

  Estimated Resources (system_estimate):
    FF:    183148
    LUT:   196173
    DSP:   0
    BRAM:  17
    URAM:  0

  Actual Resources (post-implementation):
    FF:    185234
    LUT:   198456
    DSP:   0
    BRAM:  18
    URAM:  0
```

---

## Step 5: Cleanup Temporary Files

After extracting resource data, clean up `/tmp` build files to free disk space:

```bash
# Interactive cleanup (recommended)
./fpga_cleanup_builds.sh

# Automatic cleanup (no confirmation)
./fpga_cleanup_builds.sh --all

# Clean only old builds (older than 7 days)
./fpga_cleanup_builds.sh --older-than 7

# Preview what would be deleted
./fpga_cleanup_builds.sh --dry-run
```

**What it does:**
- Lists all build directories in `/tmp/${USER}_fpga_builds/`
- Shows size and age of each directory
- Safely removes selected directories
- Reports total space freed

**⚠️ Important:** Only run cleanup AFTER extracting resources. Once deleted, reports cannot be recovered!

---

## Complete Example: Vector Addition

Here's a complete workflow from start to finish:

```bash
# Navigate to templates directory
cd xilinx-fpga-templates

# Step 1: Setup environment (optional)
source setup_env.sh u200 hw_emu

# Step 2: Build kernel
./fpga_build_template.sh \
    -p vector_add \
    -k vadd \
    -s examples/vector_add/vector_add.cpp \
    -b u200 \
    -t hw_emu

# Step 3: Link and run
./fpga_run_template.sh \
    -p vector_add \
    -x "results/kernels/vadd.xo" \
    -H examples/vector_add/host.cpp \
    -B u200 \
    -t hw_emu

# Expected output: "TEST PASSED"

# Step 4: Extract resources
./fpga_extract_resources.sh --project vector_add

# Step 5: Cleanup
./fpga_cleanup_builds.sh --project vector_add
```

---

## Workflow for Different Targets

### Development Workflow (Recommended)

```bash
# Phase 1: Quick testing with sw_emu (1-5 minutes)
./fpga_build_template.sh -p myproject -k mykernel -s kernel.cpp -b u200 -t sw_emu
./fpga_run_template.sh -p myproject -x "results/kernels/mykernel.xo" -H host.cpp -B u200 -t sw_emu
# Fix bugs, iterate quickly

# Phase 2: Resource validation with hw_emu (30-60 minutes)
./fpga_build_template.sh -p myproject -k mykernel -s kernel.cpp -b u200 -t hw_emu
./fpga_run_template.sh -p myproject -x "results/kernels/mykernel.xo" -H host.cpp -B u200 -t hw_emu
./fpga_extract_resources.sh --project myproject  # Check resource usage

# Phase 3: Production build with hw (2-6 hours)
./fpga_build_template.sh -p myproject -k mykernel -s kernel.cpp -b u200 -t hw
./fpga_run_template.sh -p myproject -x "results/kernels/mykernel.xo" -H host.cpp -B u200 -t hw --skip-run
./fpga_extract_resources.sh --project myproject  # Get actual implementation resources

# Phase 4: Cleanup
./fpga_extract_resources.sh --all --output final_resources.txt
./fpga_cleanup_builds.sh --all
```

---

## Advanced: 4-Phase Workflow (Vitis 2024.2+)

For optimal development speed, use the **NEW 4-phase workflow** that replaces deprecated sw_emu:

```
Phase 1: g++ (seconds)        → Algorithm correctness
Phase 2: vitis_hls csim (min) → Synthesizability validation
Phase 3: hw_emu (hours)       → System integration
Phase 4: hw (production)      → Deployment
```

**Time savings: 96% faster than old workflow!**

See [CSIM_GUIDE.md](CSIM_GUIDE.md) for complete 4-phase workflow details.

---

## Directory Structure After Complete Workflow

```
your_project/
├── kernel.cpp                           # Your kernel (input)
├── host.cpp                             # Your host code (input)
│
├── results/                             # Build outputs
│   ├── kernels/
│   │   └── kernel.xo                    # Compiled kernel
│   ├── reports/
│   │   └── project/
│   │       ├── kernel_csynth.rpt       # HLS synthesis report
│   │       └── system_estimate*.xtxt   # Resource estimates
│   └── logs/                            # Build logs
│
├── binary_container.xclbin              # Linked FPGA binary
├── host.exe                             # Compiled host
├── emconfig.json                        # Emulation config
│
└── resources.txt                        # Extracted resource data

/tmp/${USER}_fpga_builds/                # Temporary files
└── project_timestamp/                   # Build artifacts (cleanup after extraction)
```

---

## Quick Reference: All Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `setup_env.sh` | Setup Vitis/XRT environment | Before building (optional) |
| `fpga_build_template.sh` | Compile kernel to .xo | Always (first step) |
| `fpga_run_template.sh` | Link + compile + run | After kernel build |
| `fpga_extract_resources.sh` | Get resource utilization | After hw_emu or hw build |
| `fpga_cleanup_builds.sh` | Free disk space | After extracting resources |

---

## Best Practices

1. **Always run sw_emu first** - Catch functional bugs early (1-5 min vs hours)
2. **Check resources in hw_emu** - Verify utilization before hw build (saves hours)
3. **Extract resources before cleanup** - You can't recover deleted reports
4. **Use consistent project names** - Makes resource tracking easier
5. **Save resource reports** - Track changes across iterations

---

## Troubleshooting

**"Platform not found"**
```bash
source setup_env.sh u200  # Explicit platform setup
platforminfo --list        # Check available platforms
```

**"Disk quota exceeded"**
```bash
./fpga_cleanup_builds.sh --older-than 7  # Clean old builds
du -sh /tmp/${USER}_fpga_builds/*        # Check disk usage
```

**"Build failed"**
```bash
cat results/logs/<project>/*.log         # Check build logs
cat /tmp/${USER}_fpga_builds/*/logs/*.log # Check temp logs
```

**"Missing resources after build"**
```bash
# Resources are in /tmp until cleanup
./fpga_extract_resources.sh --all        # Extract before cleanup
```

---

## Next Steps

- **[Quick Start Guide](QUICK_START.md)** - Basic installation and usage
- **[HLS Tutorial](HLS_TUTORIAL.md)** - Learn to write HLS kernels
- **[CSIM Guide](CSIM_GUIDE.md)** - 4-phase workflow details
- **[Build Targets](BUILD_TARGETS.md)** - sw_emu vs hw_emu vs hw explained
- **[Command Reference](COMMAND_REFERENCE.md)** - All command options

---

## Complete Workflow Checklist

- [ ] Clone repository: `git clone https://github.com/abdullahsahruri/xilinx-fpga-templates.git`
- [ ] Setup environment: `source setup_env.sh u200 hw_emu`
- [ ] Build kernel: `./fpga_build_template.sh -p myproject -k mykernel -s kernel.cpp -b u200 -t hw_emu`
- [ ] Link & run: `./fpga_run_template.sh -p myproject -x results/kernels/mykernel.xo -H host.cpp -B u200 -t hw_emu`
- [ ] Extract resources: `./fpga_extract_resources.sh --project myproject --output resources.txt`
- [ ] Cleanup: `./fpga_cleanup_builds.sh`

**You're ready to accelerate your FPGA development!** 🚀