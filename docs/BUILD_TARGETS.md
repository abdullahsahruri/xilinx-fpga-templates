# Understanding Build Targets: HLS C Sim, hw_emu, hw

## IMPORTANT: sw_emu Deprecation Notice

**Starting Vitis 2024.2:** Software emulation (sw_emu) is DEPRECATED and will be removed in Vitis 2025.1.

**New Workflow for Alveo/Data Center Cards:**
- **HLS C Simulation** - Fast kernel-only functional testing (seconds to minutes)
- **hw_emu** - Full system simulation with accurate hardware behavior (30-60 minutes)
- **hw** - Production bitstream for actual FPGA (2-6 hours)

**Migration Guide:**
- Replace all `sw_emu` usage with **HLS C Simulation** for kernel testing
- Use `hw_emu` for full system verification (host + kernel interaction)
- See Xilinx Answer Record 000036790 for details

---

## Overview

Vitis supports the following development flow for Alveo/data center applications:

| Stage | Tool/Target | Build Time | Purpose | What It Does |
|-------|------------|-----------|---------|--------------|
| **Kernel Testing** | HLS C Sim | Seconds | Functional correctness | Tests kernel function in isolation with C++ testbench |
| **System Testing** | hw_emu | 30-60 min | Full system validation | HLS synthesis + RTL simulation + host code |
| **Deployment** | hw | 2-6 hours | Production | Full FPGA place & route bitstream |

**Key insight:** Use HLS C Sim for rapid iteration, hw_emu for system verification, hw for deployment.

---

## HLS C Simulation (Recommended for Kernel Testing)

### "Does my kernel function work?"

**What happens:**
```
Your kernel function → Compiled with g++ → Tested with C++ testbench → Runs natively on CPU
```

### Characteristics
-  **Very Fast:** Seconds to compile and run
-  **Where:** Pure C++ compilation (no Xilinx tools needed)
-  **Good for:** Kernel logic correctness, debugging, rapid iteration
-  **Not good for:** Testing host-kernel interaction, XRT API testing

### When to Use

**Initial kernel development - Test kernel logic in isolation**

```bash
# Create simple testbench to test your kernel function
cat > kernel_test.cpp << 'EOF'
#include "kernel.h"
#include <iostream>
#include <cassert>

int main() {
    // Prepare test data
    const int N = 100;
    int input[N], output[N], expected[N];

    for (int i = 0; i < N; i++) {
        input[i] = i;
        expected[i] = i * 2;  // Whatever your kernel should compute
    }

    // Call kernel function directly (no XRT, no host code)
    my_kernel(input, output, N);

    // Verify results
    for (int i = 0; i < N; i++) {
        assert(output[i] == expected[i] && "Kernel output mismatch!");
    }

    std::cout << "PASS: All tests passed!" << std::endl;
    return 0;
}
EOF

# Compile and run (takes seconds!)
g++ -std=c++14 -I. kernel.cpp kernel_test.cpp -o test
./test
```

**Advantages:**
- **Fastest iteration:** Seconds instead of minutes
- **Standard C++ debugging:** Use gdb, valgrind, AddressSanitizer
- **No Xilinx overhead:** Pure C++ compilation
- **Isolates kernel logic:** Test your algorithm without XRT complexity
- **CI/CD friendly:** Easy to automate in test pipelines

### Example Workflow

```bash
# 1. Write kernel function
vim kernel.cpp

# 2. Write testbench
vim kernel_test.cpp

# 3. Compile and test (seconds!)
g++ -std=c++14 -I. kernel.cpp kernel_test.cpp -o test && ./test

# 4. Found a bug? Fix and retest immediately (only 2-3 seconds!)
vim kernel.cpp
g++ -std=c++14 -I. kernel.cpp kernel_test.cpp -o test && ./test

# 5. Debug with gdb if needed
g++ -g -std=c++14 -I. kernel.cpp kernel_test.cpp -o test
gdb ./test
(gdb) break my_kernel
(gdb) run
(gdb) print input[0]
```

**Typical iterations:** 20-100+ times during initial kernel development

**When to move on:** Once your kernel logic is correct with HLS C Sim, move to hw_emu to test the full system (host + kernel + XRT).

---

## sw_emu (Software Emulation) - DEPRECATED

**DEPRECATED:** Starting Vitis 2024.2, this target is deprecated and will be REMOVED in Vitis 2025.1.

**Migration:** Use **HLS C Simulation** (above) for kernel functional testing instead.

### Why Deprecated?

Xilinx is streamlining the development flow:
- **Old:** sw_emu → hw_emu → hw
- **New:** HLS C Sim → hw_emu → hw

HLS C Simulation is faster, uses standard C++ tools, and better isolates kernel logic.

### Legacy Information (for reference only)

<details>
<summary>Click to expand legacy sw_emu documentation</summary>

### "Does it work?" (Legacy)

**What happens:**
```
Your C++ kernel → Compiled as CPU code → Runs with XRT emulation
```

### Characteristics
-  **Fast:** 1-5 minutes to build
-  **Where:** Runs on CPU (no FPGA synthesis)
-  **Good for:** Algorithm correctness (DEPRECATED - use HLS C Sim)
-  **Not good for:** New projects (will be removed in 2025.1)

### When to Use (Legacy)

**Do NOT use for new projects.** Use HLS C Simulation instead.

If you must use it for legacy reasons:
```bash
./fpga_build_template.sh -p dev -k kernel -s kernel.cpp -t sw_emu -c
./fpga_run_template.sh -p dev -x results/kernels/kernel.xo -H host.cpp -t sw_emu -c
```

**Migration note:** If you see deprecation warnings, switch to HLS C Sim + hw_emu workflow.

</details>

---

## hw_emu (Hardware Emulation)

### "How fast is it? Will it fit?"

**What happens:**
```
Your C++ kernel → HLS synthesis → RTL generation → RTL simulation
```

### Characteristics
-  **Moderate:** 30-60 minutes to build
-  **Where:** Full hardware synthesis, simulated execution
-  **Good for:** Performance tuning, resource estimation, optimization
-  **Not good for:** Rapid iteration (too slow)

### When to Use

 **After sw_emu passes** - Algorithm is correct, now optimize
```bash
./fpga_build_template.sh -p opt -k kernel -s kernel.cpp -t hw_emu -c
```

 **Checking resource usage**
```bash
# After build completes
cat results/reports/opt/kernel/system_estimate_kernel.xtxt

# Look for:
# - LUT usage (should be < 1M on U200)
# - FF usage (should be < 2M on U200)
# - BRAM usage (should be < 2000 on U200)
```

 **Validating HLS pragmas** - Does PIPELINE help? Is II=1 achieved?

 **Performance estimation** - Check latency and throughput

### Example Workflow

```bash
# 1. Add optimization pragmas
vim kernel.cpp  # Add #pragma HLS PIPELINE II=1

# 2. Build with hw_emu
./fpga_build_template.sh -t hw_emu -p opt -k kernel -s kernel.cpp -c

# 3. Check resources
grep "LUT\|FF\|BRAM" results/reports/opt/kernel/system_estimate*.xtxt

# 4. Run simulation
./fpga_run_template.sh -t hw_emu -p opt -x results/kernels/kernel.xo -H host.cpp -c

# 5. Too many resources? Reduce parallelization and rebuild
# 6. Performance not good enough? Add more pragmas and rebuild
```

**Typical iterations:** 5-15 times during optimization

---

## hw (Hardware)

### "Production ready"

**What happens:**
```
Your C++ kernel → HLS synthesis → RTL generation → Place & Route → Bitstream
```

### Characteristics
-  **Slow:** 2-6 hours to build
-  **Where:** Full FPGA compilation (place & route)
-  **Good for:** Final deployment, real performance measurement
-  **Not good for:** Debugging, iteration (way too slow)

### When to Use

 **After hw_emu passes** - Design is optimized and fits
```bash
./fpga_build_template.sh -p prod -k kernel -s kernel.cpp -t hw -c
```

 **Final performance testing** - Measure real-world speed

 **Production deployment** - Create bitstreams for deployment

 **Never use for debugging** - Use sw_emu instead

### Example Workflow

```bash
# 1. Verify everything works in hw_emu
./fpga_build_template.sh -t hw_emu -p final -k kernel -s kernel.cpp -c
./fpga_run_template.sh -t hw_emu -p final -x results/kernels/kernel.xo -H host.cpp -c

# 2. Check resources are reasonable
cat results/reports/final/kernel/system_estimate_kernel.xtxt

# 3. Start hardware build (go get lunch!)
./fpga_build_template.sh -t hw -p final -k kernel -s kernel.cpp -c

# 4. After 2-6 hours, run on real FPGA
./fpga_run_template.sh -t hw -p final -x results/kernels/kernel.xo -H host.cpp -c

# 5. Archive the build
tar -czf final_v1.0_hw.tar.gz results/ *.xclbin
```

**Typical iterations:** 1-3 builds total

---

## Recommended Development Flow (NEW - Vitis 2024.2+)

```
┌─────────────────────────────────────────────────────────────┐
│  Phase 1: Rapid Algorithm Development                       │
│  Tool: g++ (standard C++ compiler)                          │
│  Time: Seconds per iteration                                │
│  Goal: Get kernel logic working                             │
│  Iterations: 20-100+                                        │
├─────────────────────────────────────────────────────────────┤
│  • Write kernel function (no HLS pragmas yet)               │
│  • Write C++ testbench                                      │
│  • Compile: g++ kernel.cpp test.cpp -o test                 │
│  • Test and debug with standard C++ tools (gdb, valgrind)   │
│  • Fix bugs in SECONDS (not minutes!)                       │
│  • Test edge cases and verify algorithm correctness         │
└──────────────┬──────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 2: Synthesizability Validation                       │
│  Tool: vitis-run --mode hls (C Simulation)                             │
│  Time: 1-5 minutes                                          │
│  Goal: Verify code CAN BE SYNTHESIZED to hardware           │
│  Iterations: 1-3 times (only when algorithm is correct)     │
├─────────────────────────────────────────────────────────────┤
│  • Add HLS pragmas (PIPELINE, ARRAY_PARTITION, etc.)        │
│  • Run vitis-run hls to CHECK SYNTHESIZABILITY             │
│  • Catch HLS-specific issues (unsupported C++ features)     │
│  • Fix pragma errors and synthesis warnings                 │
│  • Validate pragmas don't break functionality               │
│  • (Optional) Capture waveforms if needed                   │
└──────────────┬──────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 3: System Integration & Optimization                 │
│  Tool: v++ hw_emu                                           │
│  Time: 30-60 minutes per build                              │
│  Goal: Optimize hardware implementation                     │
│  Iterations: 5-15                                           │
├─────────────────────────────────────────────────────────────┤
│  • Build with hw_emu (full HLS synthesis + RTL simulation)  │
│  • Check resource usage (LUT, FF, BRAM, DSP)                │
│  • Test host + kernel interaction with XRT                  │
│  • Validate performance estimates                           │
│  • Tune pragmas to balance resources vs throughput          │
└──────────────┬──────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 4: Production Deployment                             │
│  Tool: v++ hw                                               │
│  Time: 2-6 hours per build                                  │
│  Goal: Deploy to FPGA hardware                              │
│  Iterations: 1-3                                            │
├─────────────────────────────────────────────────────────────┤
│  • Build final bitstream (full place & route)               │
│  • Test on real FPGA hardware                               │
│  • Measure actual performance                               │
│  • Archive bitstream for deployment                         │
└─────────────────────────────────────────────────────────────┘
```

### Key Differences Between Tools

| Phase | Tool | Purpose | What it Validates |
|-------|------|---------|-------------------|
| 1 | **g++** | Algorithm correctness | Does my logic work? |
| 2 | **vitis-run hls** | Synthesizability | Can this be turned into hardware? |
| 3 | **hw_emu** | System integration | Does it fit? How fast is it? |
| 4 | **hw** | Production | Real hardware performance |

**Important:** Phase 2 (vitis-run hls) is for **checking synthesizability**, NOT just testing. Use g++ for rapid testing.

---

## Time Savings Example

###  Wrong Way: Building hw Every Time

```
Iteration 1: hw build (4 hours) → Find bug → Fix
Iteration 2: hw build (4 hours) → Optimize → Check resources
Iteration 3: hw build (4 hours) → Too many LUTs → Fix
Iteration 4: hw build (4 hours) → Performance low → Optimize
Iteration 5: hw build (4 hours) → Finally works!

Total time: 20 hours (2.5 days)
```

###  Right Way: Using sw_emu → hw_emu → hw

```
sw_emu iterations (10x @ 3 min each) = 30 minutes → Algorithm correct
hw_emu iterations (5x @ 45 min each) = 4 hours → Optimized
hw build (1x @ 4 hours) = 4 hours → Production ready

Total time: 8.5 hours (1 day)
Saved: 11.5 hours (58% faster!)
```

---

## Common Mistakes to Avoid

###  Mistake 1: Using hw for Debugging

```bash
# This is WRONG - wasting hours!
./fpga_build_template.sh -t hw ...  # 4 hours later...
# Error: syntax error in kernel.cpp
# Fix and rebuild... another 4 hours wasted!
```

** Instead:**
```bash
# Start with sw_emu - fix bugs in minutes
./fpga_build_template.sh -t sw_emu ...  # 3 minutes
# Fix bugs quickly, then move to hw_emu
```

###  Mistake 2: Skipping hw_emu

```bash
# This is WRONG
./fpga_build_template.sh -t sw_emu ...  # Works!
./fpga_build_template.sh -t hw ...      # 4 hours later...
# Error: Routing failed - too many LUTs!
```

** Instead:**
```bash
# Use hw_emu to catch resource issues early
./fpga_build_template.sh -t sw_emu ...  # Works!
./fpga_build_template.sh -t hw_emu ...  # 45 min - shows resource usage
grep "LUT" results/reports/*/system_estimate*.xtxt  # Check before hw build
./fpga_build_template.sh -t hw ...      # Now confident it will work!
```

###  Mistake 3: Large Datasets in hw_emu

```bash
# hw_emu is RTL simulation - very slow for large data
./fpga_run_template.sh -t hw_emu ... # Takes hours to simulate!
```

** Instead:**
```bash
# Use small representative datasets in hw_emu
# Use full datasets only in sw_emu and hw
```

---

## Quick Reference

### When to Use Each Target

| Situation | Use | Command |
|-----------|-----|---------|
| First time writing kernel | sw_emu | `-t sw_emu` |
| Debugging algorithm | sw_emu | `-t sw_emu` |
| Testing host code | sw_emu | `-t sw_emu` |
| Adding HLS pragmas | hw_emu | `-t hw_emu` |
| Checking resources | hw_emu | `-t hw_emu` |
| Optimizing performance | hw_emu | `-t hw_emu` |
| Final validation | hw_emu | `-t hw_emu` |
| Production build | hw | `-t hw` |
| Real FPGA testing | hw | `-t hw` |

### Quick Commands

```bash
# sw_emu: Quick test
./fpga_build_template.sh -t sw_emu -p test -k kernel -s kernel.cpp -c
./fpga_run_template.sh -t sw_emu -p test -x results/kernels/kernel.xo -H host.cpp -c

# hw_emu: Check resources
./fpga_build_template.sh -t hw_emu -p test -k kernel -s kernel.cpp -c
grep "LUT\|FF\|BRAM" results/reports/test/kernel/system_estimate*.xtxt

# hw: Production
./fpga_build_template.sh -t hw -p prod -k kernel -s kernel.cpp -c
```

---

## Next Steps

- [HLS tutorial](HLS_TUTORIAL.md) - Learn HLS programming
- [Quick start](QUICK_START.md) - Basic usage examples
- [Command reference](COMMAND_REFERENCE.md) - All options