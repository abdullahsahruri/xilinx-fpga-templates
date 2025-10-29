# FPGA Run Template - User Guide

## Overview

This template script (`fpga_run_template.sh`) handles the **link-compile-run** workflow for Xilinx FPGA designs. It works with the output from `fpga_build_template.sh` (or any .xo kernel files) to:

1. **Link** kernels (.xo) into binary container (.xclbin)
2. **Compile** host application code
3. **Setup** emulation environment (if needed)
4. **Run** the application on emulation or hardware

## Complete Workflow

```
Step 1: BUILD (fpga_build_template.sh)
  kernel.cpp → HLS synthesis → kernel.xo

Step 2: RUN (fpga_run_template.sh)
  kernel.xo + host.cpp → linking + compilation → execution
```

## Quick Start

### 1. Basic Run Workflow

```bash
# Assuming you have kernel.xo from previous build
./fpga_run_template.sh \
    -p my_project \
    -x "kernel.xo" \
    -H host.cpp
```

### 2. Multiple Kernels

```bash
# Link multiple kernels into one binary
./fpga_run_template.sh \
    -p multi_kernel \
    -x "kernel1.xo kernel2.xo kernel3.xo" \
    -H host.cpp
```

### 3. Full Example (Build + Run)

```bash
# Step 1: Build kernel
./fpga_build_template.sh \
    -p hdc_project \
    -k hdc_kernel \
    -s hdc_kernel.cpp \
    -b u200 \
    -t hw_emu

# Step 2: Link and run
./fpga_run_template.sh \
    -p hdc_project \
    -x "results/kernels/hdc_kernel.xo" \
    -H host.cpp \
    -t hw_emu \
    -B u200
```

## Understanding Build Targets: sw_emu, hw_emu, and hw

When developing FPGA applications, you need to choose between three target types. **Understanding when and why to use each target is critical** for efficient development.

### Why Multiple Targets Exist

FPGA development is fundamentally different from traditional software development:

1. **Hardware builds take hours** - Full FPGA compilation can take 2-6 hours
2. **Debugging is harder** - Can't use traditional debuggers on hardware
3. **Iteration is expensive** - Finding a bug after a 4-hour build is costly
4. **Performance is hardware-dependent** - Software simulation can't predict real timing

**Solution:** Xilinx provides three targets that trade off accuracy for speed, allowing iterative development without constant hardware builds.

### Target Types Explained

#### 1. Software Emulation (`sw_emu`) - "Does it work?"

**What it does:**
- Runs your kernel as **pure C++ software** (no hardware synthesis)
- Host and kernel both execute on CPU
- No FPGA-specific behavior simulated
- Fastest execution, quickest to build

**Why use it:**
```
✓ Verify basic functionality (input → output correctness)
✓ Test different algorithms quickly
✓ Debug with standard C++ debuggers (gdb, printf)
✓ Catch obvious bugs (crashes, wrong results)
✓ Iterate on algorithm logic rapidly
```

**Why NOT use it:**
```
✗ No performance insights
✗ No resource utilization data
✗ HLS pragmas are ignored
✗ Timing completely unrealistic
```

**Build time:** 1-5 minutes
**Run time:** Fast (runs on CPU)

**Use when:**
- Starting a new kernel
- Making major algorithmic changes
- Debugging functional issues
- Testing with large datasets

**Example workflow:**
```bash
# Quick iteration loop
while [ bugs exist ]; do
    # Edit kernel.cpp
    vim kernel.cpp

    # Build and run in minutes
    ./fpga_build_template.sh -t sw_emu ...
    ./fpga_run_template.sh -t sw_emu ...

    # Results wrong? Fix and repeat immediately
done
```

---

#### 2. Hardware Emulation (`hw_emu`) - "How fast is it?"

**What it does:**
- Performs **full HLS synthesis** (C++ → RTL)
- Runs **RTL simulation** of actual FPGA hardware
- Accurate cycle-by-cycle behavior
- Simulates memory interfaces, AXI buses, kernels

**Why use it:**
```
✓ Accurate performance prediction
✓ Validates HLS pragmas (PIPELINE, UNROLL, DATAFLOW)
✓ Shows actual resource usage (LUTs, FFs, BRAM)
✓ Generates waveforms for detailed analysis
✓ Identifies memory bottlenecks
✓ Tests kernel-to-kernel communication
✓ 95% confidence before hardware build
```

**Why NOT use it:**
```
✗ Very slow execution (1000x-10000x slower than real hardware)
✗ Limited dataset sizes (minutes → hours with large data)
✗ Still not 100% accurate (place & route not done)
```

**Build time:** 30-60 minutes
**Run time:** Very slow (RTL simulation overhead)

**Use when:**
- Functional correctness verified (sw_emu passed)
- Optimizing performance with HLS pragmas
- Need resource utilization estimates
- Before committing to multi-hour hardware build
- Analyzing timing with waveforms

**Example workflow:**
```bash
# Optimization loop
# 1. Start with baseline
./fpga_build_template.sh -t hw_emu -p baseline -k kernel -s kernel.cpp
./fpga_run_template.sh -t hw_emu -p baseline -x kernel.xo -H host.cpp

# Output: 100 cycles per iteration, 50,000 LUTs

# 2. Add PIPELINE pragma
vim kernel.cpp  # Add #pragma HLS PIPELINE II=1

./fpga_build_template.sh -t hw_emu -p optimized -k kernel -s kernel.cpp
./fpga_run_template.sh -t hw_emu -p optimized -x kernel.xo -H host.cpp

# Output: 10 cycles per iteration, 75,000 LUTs

# 3. Validated! Now build for hardware
./fpga_build_template.sh -t hw -p final -k kernel -s kernel.cpp
```

**Performance analysis:**
```bash
# After hw_emu run
vitis_analyzer profile_summary.csv  # See kernel execution time
vitis_analyzer timeline_trace.csv   # See data transfers vs compute
vivado xsim.wdb                      # View detailed waveforms
```

---

#### 3. Hardware (`hw`) - "Deployment ready"

**What it does:**
- **Full FPGA compilation** (synthesis + place & route)
- Generates actual **bitstream** for FPGA
- Runs on **real hardware** (requires physical FPGA card)
- Exact production performance

**Why use it:**
```
✓ Real hardware execution (fastest possible)
✓ True end-to-end performance measurement
✓ Deployment-ready bitstream
✓ Validates actual place & route timing closure
✓ Tests real I/O (PCIe, DDR, HBM)
```

**Why NOT use it:**
```
✗ Extremely long build time (2-6 hours)
✗ Requires physical FPGA hardware
✗ Routing may fail (needs redesign)
✗ No waveforms or detailed debug
✗ Expensive iteration (hours per try)
```

**Build time:** 2-6 hours
**Run time:** Real-time (actual hardware speed)

**Use when:**
- hw_emu results validated
- Ready for final performance testing
- Need deployment bitstream
- Customer deliverable
- Publishing benchmark results

**Example workflow:**
```bash
# Only after hw_emu validation!

# Friday afternoon: Start hardware build
./fpga_build_template.sh -t hw -p production -k kernel -s kernel.cpp

# Monday morning: Build complete, test on hardware
./fpga_run_template.sh -t hw -p production -x kernel.xo -H host.cpp

# Measure real performance
time ./host.exe binary_container.xclbin
```

---

### Recommended Development Workflow

**Follow this sequence to minimize total development time:**

```
Stage 1: Algorithm Development (sw_emu)
│  ┌──────────────────────────────────┐
│  │ Write initial kernel             │
│  │ Test basic functionality         │
│  │ Fix functional bugs              │
│  │ Iterate rapidly (minutes)        │
│  └──────────────────────────────────┘
│       sw_emu runs: 10-50 iterations
│       Time spent: Hours to days
│       Goal: Correct results
│
▼
Stage 2: Performance Optimization (hw_emu)
│  ┌──────────────────────────────────┐
│  │ Add HLS pragmas                  │
│  │ Optimize for parallelism         │
│  │ Check resource usage             │
│  │ Validate timing                  │
│  └──────────────────────────────────┘
│       hw_emu runs: 5-15 iterations
│       Time spent: Days to week
│       Goal: Optimal performance/resources
│
▼
Stage 3: Hardware Validation (hw)
│  ┌──────────────────────────────────┐
│  │ Build final bitstream            │
│  │ Test on real hardware            │
│  │ Measure real performance         │
│  │ Deliver to production            │
│  └──────────────────────────────────┘
│       hw runs: 1-3 builds
│       Time spent: Days (due to build time)
│       Goal: Deployment
```

**Time savings example:**

| Approach | Total Time | Success Rate |
|----------|------------|--------------|
| ❌ **Bad:** Jump to `hw` immediately | 10+ days (5+ failed builds × 4 hours) | Low |
| ✅ **Good:** sw_emu → hw_emu → hw | 3-5 days (iterate in emu, 1-2 hw builds) | High |

---

### Real-World Scenarios

#### Scenario 1: New Feature Development

```bash
# Day 1-2: Get it working (sw_emu)
for i in {1..20}; do
    vim kernel.cpp  # Add new feature
    ./fpga_build_template.sh -t sw_emu ...
    ./fpga_run_template.sh -t sw_emu ...
done

# Day 3-4: Make it fast (hw_emu)
for i in {1..5}; do
    vim kernel.cpp  # Add HLS pragmas
    ./fpga_build_template.sh -t hw_emu ...
    ./fpga_run_template.sh -t hw_emu ...
    vitis_analyzer profile_summary.csv
done

# Day 5: Deploy (hw)
./fpga_build_template.sh -t hw ...  # Start before lunch
# ... go work on documentation ...
./fpga_run_template.sh -t hw ...    # Test after lunch tomorrow
```

#### Scenario 2: Bug Found in Production

```bash
# Production hw build shows wrong results

# Step 1: Reproduce in sw_emu (minutes)
./fpga_build_template.sh -t sw_emu ...
./fpga_run_template.sh -t sw_emu ...
# Bug reproduced!

# Step 2: Debug with gdb
gdb --args ./host.exe binary_container.xclbin
# Found: Off-by-one error in loop

# Step 3: Fix and verify (sw_emu)
vim kernel.cpp
./fpga_build_template.sh -t sw_emu ...
./fpga_run_template.sh -t sw_emu ...
# Fixed!

# Step 4: Validate timing unchanged (hw_emu)
./fpga_build_template.sh -t hw_emu ...
./fpga_run_template.sh -t hw_emu ...
# Performance unchanged, resources same

# Step 5: Rebuild for production (hw)
./fpga_build_template.sh -t hw ...
# Deploy fixed bitstream
```

#### Scenario 3: Resource Exceeded Error

```bash
# hw build fails: "Routing failed - too many LUTs"

# Step 1: Check resources in hw_emu
./fpga_build_template.sh -t hw_emu -p debug ...
grep "LUT" results/reports/*/system_estimate*.xtxt
# Output: 1,200,000 LUTs used (device has 1,182,240)

# Step 2: Reduce parallelization (sw_emu for quick test)
vim kernel.cpp  # Change UNROLL factor=32 → factor=16
./fpga_build_template.sh -t sw_emu -p reduced ...
./fpga_run_template.sh -t sw_emu -p reduced ...
# Still works functionally

# Step 3: Check new resources (hw_emu)
./fpga_build_template.sh -t hw_emu -p reduced ...
grep "LUT" results/reports/*/system_estimate*.xtxt
# Output: 750,000 LUTs used ✓

# Step 4: Now hw build will succeed
./fpga_build_template.sh -t hw -p final ...
```

---

### Quick Decision Chart

**Choose your target based on your question:**

| Your Question | Use This Target |
|---------------|-----------------|
| "Does my algorithm work?" | `sw_emu` |
| "Is the output correct?" | `sw_emu` |
| "Where is this crash happening?" | `sw_emu` |
| "How many LUTs will this use?" | `hw_emu` |
| "How fast will this run?" | `hw_emu` |
| "Do my HLS pragmas work?" | `hw_emu` |
| "Why is this slow?" | `hw_emu` |
| "Will this route successfully?" | `hw_emu` (then `hw` to confirm) |
| "What's the real-world performance?" | `hw` |
| "Ready for production?" | `hw` |

---

### Common Mistakes to Avoid

❌ **WRONG:** Building `hw` first
✅ **RIGHT:** Validate in `sw_emu`, optimize in `hw_emu`, then build `hw`

❌ **WRONG:** Testing large datasets in `hw_emu`
✅ **RIGHT:** Use small representative data in `hw_emu`, full dataset in `hw`

❌ **WRONG:** Skipping `hw_emu` to save time
✅ **RIGHT:** `hw_emu` catches issues that would waste hours in failed `hw` builds

❌ **WRONG:** Using `sw_emu` for performance tuning
✅ **RIGHT:** Only use `hw_emu` or `hw` for performance measurement

---

## Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `-h, --help` | Show help message | - |
| `-p, --project NAME` | Project name | `my_fpga_project` |
| `-x, --xo FILES` | Kernel .xo files (space-separated, quoted) | Required |
| `-b, --binary NAME` | Output binary container name | `binary_container.xclbin` |
| `-H, --host FILE` | Host source file | `host.cpp` |
| `-e, --exe NAME` | Host executable name | `host.exe` |
| `-t, --target TYPE` | Target: `hw_emu`, `hw`, `sw_emu` | `hw_emu` |
| `-B, --board BOARD` | Board type | `u200` |
| `-P, --platform NAME` | Override platform string | Auto-detected |
| `-d, --dir PATH` | Project directory | Current directory |
| `-c, --auto-cleanup` | Auto-cleanup temp files | Manual prompt |

### Workflow Control Options

| Option | Effect |
|--------|--------|
| `--skip-link` | Skip linking (use existing .xclbin) |
| `--skip-compile` | Skip host compilation (use existing .exe) |
| `--skip-emconfig` | Skip emulation config setup |
| `--skip-run` | Only link and compile, don't execute |

## Workflow Steps Explained

### Step 1: Linking (.xo → .xclbin)

Links one or more kernel objects into a single binary container:

```bash
v++ -l -t hw_emu \
    --platform xilinx_u200* \
    -o binary_container.xclbin \
    kernel1.xo kernel2.xo
```

**What it does:**
- Combines multiple kernels
- Places and routes on FPGA
- Generates bitstream (for hw target)
- Creates .xclbin file

**Time estimates:**
- `sw_emu`: 1-5 minutes
- `hw_emu`: 30-60 minutes
- `hw`: 2-6 hours

### Step 2: Host Compilation (host.cpp → host.exe)

Compiles the host application that will control the FPGA:

```bash
g++ -std=c++14 \
    -I${XILINX_XRT}/include \
    -L${XILINX_XRT}/lib \
    -o host.exe \
    host.cpp \
    -lOpenCL -lpthread
```

**What it does:**
- Links XRT runtime libraries
- Creates executable that loads .xclbin
- Handles data transfers to/from FPGA

### Step 3: Emulation Setup

For `hw_emu` or `sw_emu` targets only:

```bash
emconfigutil --platform xilinx_u200* --nd 1
export XCL_EMULATION_MODE=hw_emu
```

**What it does:**
- Generates `emconfig.json` (device emulation config)
- Sets environment for emulation runtime

### Step 4: Execution

Runs the host application:

```bash
./host.exe binary_container.xclbin
```

**What happens:**
- Host loads .xclbin to device (or emulator)
- Transfers input data to FPGA
- Executes kernel(s)
- Retrieves results
- Displays output

## Learning from Xilinx Official Examples

AMD/Xilinx provides extensive example repositories that work seamlessly with these templates. Use these as learning resources and starting points for your projects.

### Official Xilinx/AMD GitHub Repositories

#### 1. Vitis Acceleration Examples
**Repository:** [github.com/Xilinx/Vitis_Accel_Examples](https://github.com/Xilinx/Vitis_Accel_Examples)

**What it contains:**
- Complete host + kernel examples for Alveo platforms (U200, U250, U280, etc.)
- XRT Native API demonstrations
- Performance optimization patterns
- Multi-kernel and streaming examples

**Key examples to try:**

| Example | Location | What it demonstrates |
|---------|----------|---------------------|
| **Hello World XRT** | `host_xrt/hello_world_xrt/` | Basic XRT API usage, device management, buffer operations |
| **Hello World Python** | `host_xrt/hello_world_py/` | Python host code with HLS kernel |
| **Vector Addition** | `host_xrt/hello_world/` | HLS Dataflow, task-level parallelism |
| **Multiple Devices** | `sys_opt/multiple_devices/` | Using multiple FPGAs simultaneously |
| **P2P Transfer** | `sys_opt/p2p_fpga2fpga/` | Direct FPGA-to-FPGA communication |

**Using with our templates:**
```bash
# Clone the repository
git clone https://github.com/Xilinx/Vitis_Accel_Examples.git
cd Vitis_Accel_Examples
git checkout 2024.1  # Match your Vitis version

# Navigate to hello_world example
cd host_xrt/hello_world

# Build kernel using our template
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

---

#### 2. Vitis HLS Introductory Examples
**Repository:** [github.com/Xilinx/Vitis-HLS-Introductory-Examples](https://github.com/Xilinx/Vitis-HLS-Introductory-Examples)

**What it contains:**
- HLS-specific kernel development examples
- Optimization technique demonstrations
- Pragma usage patterns (PIPELINE, DATAFLOW, UNROLL, ARRAY_PARTITION)
- Interface protocol examples (AXI, AXI-Stream)

**Categories:**

| Category | Key Examples | Learn About |
|----------|--------------|-------------|
| **Pipelining** | Loop pipelining, function pipelining | `#pragma HLS PIPELINE` usage |
| **Array Optimization** | Complete partitioning, block-cyclic | `#pragma HLS ARRAY_PARTITION` |
| **Task-Level Parallelism** | Dataflow with hls::task | `#pragma HLS DATAFLOW` |
| **Modeling** | Arbitrary precision, vectorization | C++ synthesis techniques |
| **Interface** | AXI Master, AXI-Stream | Memory and streaming interfaces |
| **Misc** | FFT, FIR filters, RTL blackbox | Real-world patterns |

**Example workflow:**
```bash
# Clone the repository
git clone https://github.com/Xilinx/Vitis-HLS-Introductory-Examples.git
cd Vitis-HLS-Introductory-Examples

# Example: Try array partitioning
cd Array/array_partition

# Build with sw_emu for quick test
/path/to/fpga_build_template.sh \
    -p array_partition_example \
    -k array_partition \
    -s array_partition.cpp \
    -b u200 \
    -t sw_emu

# Build with hw_emu to see resource impact
/path/to/fpga_build_template.sh \
    -p array_partition_example \
    -k array_partition \
    -s array_partition.cpp \
    -b u200 \
    -t hw_emu

# Compare resource usage
grep "LUT" results/reports/*/system_estimate*.xtxt
```

---

#### 3. Vitis Tutorials (Comprehensive Learning Path)
**Repository:** [github.com/Xilinx/Vitis-Tutorials](https://github.com/Xilinx/Vitis-Tutorials)

**What it contains:**
- Step-by-step tutorials for HLS and acceleration
- Getting started guides
- Hardware acceleration workflows
- Performance analysis tutorials

**Key tutorial paths:**

| Tutorial Path | Branch | Description |
|--------------|--------|-------------|
| `Getting_Started/Vitis_HLS/` | 2024.1 | Introduction to HLS workflow |
| `Hardware_Acceleration/Introduction/` | 2024.1 | Building accelerators for Alveo |
| `Hardware_Acceleration/Design_Tutorials/` | 2024.1 | Real-world acceleration projects |
| `Hardware_Acceleration/Feature_Tutorials/` | 2024.1 | Specific Vitis features |

**Recommended learning sequence:**
```bash
# Clone tutorials
git clone https://github.com/Xilinx/Vitis-Tutorials.git
cd Vitis-Tutorials
git checkout 2024.1

# Start with HLS basics
cd Getting_Started/Vitis_HLS/

# Follow along, building with our templates:
# 1. Start with sw_emu to understand functionality
# 2. Move to hw_emu to see performance/resources
# 3. Build hw when ready for real hardware
```

---

### Practical Example: Hello World XRT

Let's walk through running Xilinx's official Hello World example using our templates:

#### Step 1: Get the Example
```bash
git clone https://github.com/Xilinx/Vitis_Accel_Examples.git
cd Vitis_Accel_Examples
git checkout 2024.1
cd host_xrt/hello_world
```

#### Step 2: Examine the Code
```bash
# Check the kernel (vector addition with dataflow)
cat src/vadd.cpp

# Check the host code (XRT Native API)
cat src/host.cpp
```

**Kernel highlights (`src/vadd.cpp`):**
```cpp
extern "C" {
void vadd(const unsigned int* in1,
          const unsigned int* in2,
          unsigned int* out,
          int size) {
    #pragma HLS INTERFACE m_axi port=in1 bundle=gmem0
    #pragma HLS INTERFACE m_axi port=in2 bundle=gmem1
    #pragma HLS INTERFACE m_axi port=out bundle=gmem0

    read: for (int i = 0; i < size; i++) {
        #pragma HLS PIPELINE II=1
        out[i] = in1[i] + in2[i];
    }
}
}
```

**Host code highlights (`src/host.cpp`):**
```cpp
// Open device and load xclbin
auto device = xrt::device(0);
auto uuid = device.load_xclbin(xclbin_file);

// Create kernel
auto kernel = xrt::kernel(device, uuid, "vadd");

// Allocate buffers
auto in1_bo = xrt::bo(device, size_bytes, kernel.group_id(0));
auto in2_bo = xrt::bo(device, size_bytes, kernel.group_id(1));
auto out_bo = xrt::bo(device, size_bytes, kernel.group_id(2));

// Run kernel
auto run = kernel(in1_bo, in2_bo, out_bo, DATA_SIZE);
run.wait();
```

#### Step 3: Build with Our Template (sw_emu)
```bash
# Quick functional test
/path/to/fpga_build_template.sh \
    -p hello_world_vadd \
    -k vadd \
    -s src/vadd.cpp \
    -b u200 \
    -t sw_emu \
    -c

# Output: results/kernels/vadd.xo (built in minutes)
```

#### Step 4: Build with Our Template (hw_emu)
```bash
# Performance validation
/path/to/fpga_build_template.sh \
    -p hello_world_vadd \
    -k vadd \
    -s src/vadd.cpp \
    -b u200 \
    -t hw_emu \
    -c

# Check resources
cat results/reports/hello_world_vadd/vadd/system_estimate_vadd.xtxt
```

#### Step 5: Link and Run
```bash
# Link kernel and run with host
/path/to/fpga_run_template.sh \
    -p hello_world_vadd \
    -x "results/kernels/vadd.xo" \
    -H src/host.cpp \
    -B u200 \
    -t hw_emu \
    -c

# Expected output: "TEST PASSED"
```

---

### More Examples to Explore

#### Matrix Multiplication (Array Partitioning)
```bash
cd Vitis-HLS-Introductory-Examples/Array/matrix_multiply

# Compare different partitioning strategies
# 1. No partitioning
/path/to/fpga_build_template.sh -p matmul_baseline -k matmul -s matmul.cpp -t hw_emu

# 2. With partitioning (edit matmul.cpp to add pragmas)
#    #pragma HLS ARRAY_PARTITION variable=a block factor=16
/path/to/fpga_build_template.sh -p matmul_optimized -k matmul -s matmul.cpp -t hw_emu

# Compare resource usage
diff results/reports/matmul_baseline/*/system_estimate* \
     results/reports/matmul_optimized/*/system_estimate*
```

#### FIR Filter (Pipelining)
```bash
cd Vitis-HLS-Introductory-Examples/Pipelining/fir_filter

# Build without pipelining
/path/to/fpga_build_template.sh -p fir_no_pipeline -k fir -s fir.cpp -t hw_emu

# Build with pipelining (modify fir.cpp)
#    #pragma HLS PIPELINE II=1
/path/to/fpga_build_template.sh -p fir_pipelined -k fir -s fir.cpp -t hw_emu

# Compare latency in synthesis reports
```

#### Multi-Kernel Example
```bash
cd Vitis_Accel_Examples/sys_opt/multiple_compute_units

# Build multiple instances of same kernel
/path/to/fpga_build_template.sh -p multi_cu -k compute -s src/compute.cpp -t hw_emu

# Link with multiple compute units (requires v++ link flags)
/path/to/fpga_run_template.sh \
    -p multi_cu \
    -x "results/kernels/compute.xo results/kernels/compute.xo" \
    -H src/host.cpp \
    -t hw_emu
```

---

### Example Naming Conventions

Xilinx examples follow consistent patterns:

| Pattern | Location | Description |
|---------|----------|-------------|
| `src/kernel_name.cpp` | Kernel source | HLS C++ kernel code |
| `src/host.cpp` | Host source | XRT host application |
| `Makefile` | Build automation | Xilinx's build system |
| `description.json` | Metadata | Example metadata |
| `utils.mk` | Build utilities | Shared build functions |

**Note:** Our templates replace the Makefile approach with simpler command-line scripts.

---

### Platform Support in Examples

Most Xilinx examples support these Alveo platforms:

| Platform | Board | Memory | Notes |
|----------|-------|--------|-------|
| `xilinx_u200*` | Alveo U200 | DDR4 | Most common development platform |
| `xilinx_u250*` | Alveo U250 | DDR4 + HBM | High bandwidth applications |
| `xilinx_u280*` | Alveo U280 | HBM2 | AI/ML workloads |
| `xilinx_u50*` | Alveo U50 | DDR4 | Compact form factor |
| `xilinx_u55c*` | Alveo U55C | HBM2 | Crypto/compute |

**Excluded:** NoDMA platforms (e.g., `u50_nodma`) - these require special handling.

---

### Adapting Xilinx Examples to Your Project

**Strategy 1: Start from Xilinx, adapt incrementally**
```bash
# 1. Copy Xilinx example
cp -r Vitis_Accel_Examples/host_xrt/hello_world my_project
cd my_project

# 2. Modify kernel (src/vadd.cpp → src/my_kernel.cpp)
vim src/my_kernel.cpp

# 3. Build with sw_emu (fast iteration)
/path/to/fpga_build_template.sh -t sw_emu ...

# 4. Modify host (src/host.cpp)
vim src/host.cpp

# 5. Test your changes
/path/to/fpga_run_template.sh -t sw_emu ...
```

**Strategy 2: Mix and match**
```bash
# Use Xilinx kernel with your host
/path/to/fpga_run_template.sh \
    -x "Vitis_Accel_Examples/.../vadd.xo" \
    -H my_custom_host.cpp

# Use your kernel with Xilinx host
/path/to/fpga_run_template.sh \
    -x "my_kernel.xo" \
    -H "Vitis_Accel_Examples/.../host.cpp"
```

---

### Additional Resources

**Official Documentation:**
- [Vitis Accel Examples Documentation (2024.1)](https://xilinx.github.io/Vitis_Accel_Examples/2024.1/html/index.html)
- [Vitis HLS User Guide](https://docs.xilinx.com/r/en-US/ug1399-vitis-hls)
- [XRT Documentation](https://xilinx.github.io/XRT/)

**Community Resources:**
- [Xilinx Forums - Vitis](https://support.xilinx.com/s/topic/0TO2E000000YKY3WAO/vitis-acceleration)
- [AMD Developer Zone](https://developer.amd.com/xilinx/)

**Version Compatibility:**
Always checkout the branch matching your Vitis version:
```bash
git checkout 2024.1  # For Vitis 2024.1
git checkout 2023.2  # For Vitis 2023.2
```

---

## Examples

### Example 1: Single Kernel Emulation

```bash
# Directory structure:
# my_project/
# ├── results/kernels/vector_add.xo  (from build step)
# └── host.cpp

cd my_project

/path/to/fpga_run_template.sh \
    -p vector_add \
    -x "results/kernels/vector_add.xo" \
    -H host.cpp \
    -t hw_emu \
    -B u200

# Output:
# - binary_container.xclbin
# - host.exe
# - emconfig.json
# - results/run_vector_add.log
```

### Example 2: Multiple Kernels (Pipeline)

```bash
# Link encoder and decoder kernels
./fpga_run_template.sh \
    -p codec_pipeline \
    -x "encoder.xo decoder.xo" \
    -H host_pipeline.cpp \
    -e codec.exe \
    -b pipeline.xclbin \
    -t hw_emu
```

### Example 3: Hardware Execution (Real FPGA)

```bash
# Build for hardware first (takes hours)
./fpga_build_template.sh \
    -p inference \
    -k nn_kernel \
    -s neural_net.cpp \
    -t hw \
    -b u250

# Then link and run on actual U250 card
./fpga_run_template.sh \
    -p inference \
    -x "results/kernels/nn_kernel.xo" \
    -H host_inference.cpp \
    -t hw \
    -B u250

# Note: Requires actual U250 card installed in system
```

### Example 4: Quick Re-runs (Skip Link/Compile)

```bash
# First run: full workflow
./fpga_run_template.sh -p test -x kernel.xo -H host.cpp

# Subsequent runs: use existing binaries
./fpga_run_template.sh \
    -p test \
    -x kernel.xo \
    -H host.cpp \
    --skip-link \
    --skip-compile

# This just re-executes the application
```

### Example 5: Link Only (Debug Placement/Routing)

```bash
# Only link, don't compile or run
./fpga_run_template.sh \
    -p routing_test \
    -x "kernel1.xo kernel2.xo kernel3.xo" \
    -H host.cpp \
    --skip-run

# Check if linking succeeds and review reports
ls -lh binary_container.xclbin
cat results/routing_test_link.log
```

## Host Code Requirements

Your host code must follow the OpenCL/XRT programming model:

### Minimal Host Code Template

```cpp
#include <iostream>
#include <fstream>
#include <CL/cl.h>

// Read binary file
std::vector<char> read_binary_file(const std::string& filename) {
    std::ifstream file(filename, std::ios::binary | std::ios::ate);
    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);
    std::vector<char> buffer(size);
    file.read(buffer.data(), size);
    return buffer;
}

int main(int argc, char** argv) {
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <xclbin>" << std::endl;
        return 1;
    }

    // 1. Get platform and device
    cl_platform_id platform;
    clGetPlatformIDs(1, &platform, nullptr);

    cl_device_id device;
    clGetDeviceIDs(platform, CL_DEVICE_TYPE_ACCELERATOR, 1, &device, nullptr);

    // 2. Create context and command queue
    cl_context context = clCreateContext(nullptr, 1, &device, nullptr, nullptr, nullptr);
    cl_command_queue queue = clCreateCommandQueue(context, device, 0, nullptr);

    // 3. Load xclbin
    std::vector<char> binary = read_binary_file(argv[1]);
    size_t binary_size = binary.size();
    const unsigned char* binary_ptr = (const unsigned char*)binary.data();

    cl_program program = clCreateProgramWithBinary(
        context, 1, &device, &binary_size, &binary_ptr, nullptr, nullptr
    );
    clBuildProgram(program, 1, &device, nullptr, nullptr, nullptr);

    // 4. Create kernel
    cl_kernel kernel = clCreateKernel(program, "your_kernel_name", nullptr);

    // 5. Allocate buffers and set arguments
    // ... (your application-specific code)

    // 6. Execute kernel
    clEnqueueTask(queue, kernel, 0, nullptr, nullptr);
    clFinish(queue);

    // 7. Read results
    // ... (your application-specific code)

    // 8. Cleanup
    clReleaseKernel(kernel);
    clReleaseProgram(program);
    clReleaseCommandQueue(queue);
    clReleaseContext(context);

    std::cout << "Execution complete!" << std::endl;
    return 0;
}
```

### Host Code with XRT Native API

For modern designs, use XRT native API (C++):

```cpp
#include <xrt/xrt_device.h>
#include <xrt/xrt_kernel.h>
#include <xrt/xrt_bo.h>

int main(int argc, char** argv) {
    // 1. Load device and xclbin
    auto device = xrt::device(0);
    auto uuid = device.load_xclbin(argv[1]);

    // 2. Create kernel
    auto kernel = xrt::kernel(device, uuid, "your_kernel_name");

    // 3. Allocate buffers
    size_t data_size = 1024 * sizeof(int);
    auto input_bo = xrt::bo(device, data_size, kernel.group_id(0));
    auto output_bo = xrt::bo(device, data_size, kernel.group_id(1));

    // 4. Map and populate input
    auto input_map = input_bo.map<int*>();
    for (int i = 0; i < 1024; i++) {
        input_map[i] = i;
    }
    input_bo.sync(XCL_BO_SYNC_BO_TO_DEVICE);

    // 5. Execute kernel
    auto run = kernel(input_bo, output_bo, 1024);
    run.wait();

    // 6. Read results
    auto output_map = output_bo.map<int*>();
    output_bo.sync(XCL_BO_SYNC_BO_FROM_DEVICE);

    // Process results...

    return 0;
}
```

## Output Files

### In Project Directory

```
project_dir/
├── binary_container.xclbin    # Linked FPGA binary
├── host.exe                    # Compiled host application
├── emconfig.json               # Emulation config (hw_emu/sw_emu only)
├── profile_summary.csv         # Profiling data (if enabled)
├── timeline_trace.csv          # Timeline data (if enabled)
└── xsim.wdb                    # Waveform database (hw_emu only)
```

### In Results Directory

```
results/
├── run_<project>.log              # Execution output
├── <project>_link.log             # Linking log
├── <project>_host_compile.log     # Host compilation log
└── waveforms/                     # Waveform files (hw_emu)
    └── xsim.wdb
```

## Profiling and Debug

### Enable Profiling

Modify the script to add profiling flags:

```bash
# In run template, add to v++ link command:
v++ -l -t hw_emu \
    --profile.data all:all:all \
    --profile.exec all:all:all \
    ...
```

Then analyze with Vitis Analyzer:

```bash
vitis_analyzer profile_summary.csv
vitis_analyzer timeline_trace.csv
```

### View Waveforms (hw_emu only)

```bash
# After hw_emu run
vivado xsim.wdb

# Or
xsim -gui -wdb xsim.wdb
```

### Enable Debug Prints

In host code:

```cpp
// Set environment before running
setenv("XCL_EMULATION_MODE", "hw_emu");
setenv("XRT_VERBOSITY", "7");  // Max verbosity

// Or from shell
export XRT_VERBOSITY=7
./host.exe binary_container.xclbin
```

## Target Comparison

| Feature | sw_emu | hw_emu | hw |
|---------|--------|--------|-----|
| **Speed** | Very fast | Slow | Real-time |
| **Build time** | Minutes | ~1 hour | 2-6 hours |
| **Accuracy** | Functional only | Cycle-accurate | Exact |
| **HLS synthesis** | No | Yes | Yes |
| **Place & route** | No | No | Yes |
| **Waveforms** | No | Yes | No |
| **Profiling** | Basic | Detailed | Real hardware |
| **Hardware needed** | None | None | FPGA card |
| **Use case** | Quick functional test | Performance validation | Deployment |

## Troubleshooting

### Error: "No kernel .xo files specified"

**Cause:** Missing `-x` flag

**Solution:**
```bash
./fpga_run_template.sh ... -x "kernel.xo"
```

### Error: "Kernel file not found: kernel.xo"

**Cause:** Wrong path to .xo file

**Solution:** Use absolute or correct relative path
```bash
# If .xo is in results/kernels/
-x "results/kernels/kernel.xo"

# Or use absolute path
-x "/full/path/to/kernel.xo"
```

### Error: "undefined reference to clCreateContext"

**Cause:** Missing OpenCL libraries during host compilation

**Solution:** The script automatically links `-lOpenCL`. If still failing, check XRT installation:
```bash
echo $XILINX_XRT
ls $XILINX_XRT/lib/libOpenCL.so
```

### Error: "Could not find platform"

**Cause:** XCL_EMULATION_MODE not set or wrong platform

**Solution:**
```bash
# For emulation
export XCL_EMULATION_MODE=hw_emu

# Verify platform
platforminfo --list
```

### Linking Takes Very Long (hw target)

**Expected:** Linking for `hw` target involves full place & route and can take 2-6 hours.

**Tips:**
- Use `hw_emu` during development
- Monitor progress: `tail -f /tmp/${USER}_fpga_runs/*/link.log`
- Consider implementing partial reconfiguration for faster iterations

### Emulation Runs but No Output

**Possible causes:**
1. Kernel not being called from host
2. Host code errors
3. Data not synced properly

**Debug:**
```bash
# Check execution log
cat results/run_<project>.log

# Enable verbose XRT output
export XRT_VERBOSITY=7
./host.exe binary_container.xclbin
```

### Error: "Error writing file" during link

**Cause:** Disk quota or /tmp full

**Solution:**
```bash
# Check space
df -h /tmp

# Clean old builds
rm -rf /tmp/${USER}_fpga_runs/*

# Or modify script to use different location
```

## Performance Tips

### 1. Use Appropriate Target for Development

```bash
# Development cycle
sw_emu → hw_emu → hw

# Don't jump straight to hw!
```

### 2. Profile Before Hardware Build

```bash
# Profile in hw_emu first
./fpga_run_template.sh ... -t hw_emu
vitis_analyzer profile_summary.csv

# Identify bottlenecks, optimize kernel
# Then build for hardware
```

### 3. Incremental Linking

```bash
# If only host code changed
./fpga_run_template.sh ... --skip-link

# If only running with different data
./fpga_run_template.sh ... --skip-link --skip-compile
```

### 4. Parallel Development

```bash
# Developer 1: Works on kernel optimization
./fpga_build_template.sh -p kernel_opt ...

# Developer 2: Works on host code
# (uses existing .xo from developer 1)
./fpga_run_template.sh -x shared/kernel.xo ...
```

## Integration with Build Template

### Complete Project Workflow

```bash
#!/bin/bash
# complete_workflow.sh

PROJECT="my_accelerator"
KERNEL_SOURCE="accel_kernel.cpp"
HOST_SOURCE="host.cpp"
BOARD="u200"
TARGET="hw_emu"

# Step 1: Build kernel
echo "=== Building kernel ==="
./fpga_build_template.sh \
    -p ${PROJECT} \
    -k accel_kernel \
    -s ${KERNEL_SOURCE} \
    -b ${BOARD} \
    -t ${TARGET} \
    -c

# Step 2: Link and run
echo "=== Linking and running ==="
./fpga_run_template.sh \
    -p ${PROJECT} \
    -x "results/kernels/accel_kernel.xo" \
    -H ${HOST_SOURCE} \
    -B ${BOARD} \
    -t ${TARGET} \
    -c

echo "=== Workflow complete ==="
ls -lh results/
```

### Makefile Integration

```makefile
PROJECT = my_project
KERNEL = my_kernel
KERNEL_SRC = kernel.cpp
HOST_SRC = host.cpp
BOARD = u200
TARGET = hw_emu

BUILD_SCRIPT = /path/to/fpga_build_template.sh
RUN_SCRIPT = /path/to/fpga_run_template.sh

.PHONY: all build run clean

all: build run

build:
	$(BUILD_SCRIPT) -p $(PROJECT) -k $(KERNEL) -s $(KERNEL_SRC) \
		-b $(BOARD) -t $(TARGET) -c

run:
	$(RUN_SCRIPT) -p $(PROJECT) -x "results/kernels/$(KERNEL).xo" \
		-H $(HOST_SRC) -B $(BOARD) -t $(TARGET) -c

clean:
	rm -rf results *.xclbin *.exe emconfig.json
	rm -rf /tmp/${USER}_fpga_builds/$(PROJECT)_*
	rm -rf /tmp/${USER}_fpga_runs/$(PROJECT)_*

rerun:
	$(RUN_SCRIPT) -p $(PROJECT) -x "results/kernels/$(KERNEL).xo" \
		-H $(HOST_SRC) -B $(BOARD) -t $(TARGET) \
		--skip-link --skip-compile
```

## Best Practices

1. **Always test with sw_emu first**
   - Catches obvious functional bugs quickly
   - No build time

2. **Validate performance with hw_emu**
   - Cycle-accurate timing
   - Identifies performance bottlenecks
   - Enables waveform analysis

3. **Keep host and kernel separate**
   - Easier to iterate on each independently
   - Reuse kernels with different hosts

4. **Version control your binaries for hw builds**
   - Hardware builds take hours
   - Archive .xclbin files
   - Document build configurations

5. **Use profiling data**
   - Identify data transfer bottlenecks
   - Optimize kernel execution time
   - Balance compute vs. communication

## FAQ

**Q: Do I need to rebuild kernels if I only change host code?**
A: No. Use `--skip-link` to reuse existing .xclbin and just recompile host.

**Q: Can I use kernels built on one machine and run on another?**
A: Yes, .xo and .xclbin files are portable (same platform/target). Copy them along with your host code.

**Q: How do I pass arguments to my host application?**
A: The script passes the .xclbin path as argv[1]. Add more arguments after:
```bash
# Modify your host code to accept additional args
./host.exe binary_container.xclbin arg2 arg3

# Or modify the script's run_application() function
```

**Q: Why is hw_emu so slow?**
A: It's running RTL simulation of the entire FPGA fabric. This is inherently slow but accurate. Use small test datasets for hw_emu.

**Q: Can I use this for Verilog/VHDL kernels?**
A: Yes! If you have RTL kernels packaged as .xo files, the run template works identically. The build template is HLS-specific, but linking/running is the same.

**Q: How do I enable profiling?**
A: Modify the `link_kernels()` function in the script to add:
```bash
--profile.data all:all:all \
--profile.exec all:all:all
```

## Support

For Xilinx-specific issues:
- [Vitis Application Acceleration Documentation](https://docs.xilinx.com/r/en-US/ug1393-vitis-application-acceleration)
- [XRT Documentation](https://xilinx.github.io/XRT/)

## Version History

- **v1.0** (2025-10-29): Initial release
  - Complete link-compile-run workflow
  - Multi-kernel support
  - Emulation and hardware target support
  - Workflow control flags (skip steps)
  - /tmp temporary file management