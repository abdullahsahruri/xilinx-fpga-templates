# Understanding Build Targets: sw_emu, hw_emu, hw

## Overview

Vitis supports three build targets for iterative development:

| Target | Build Time | Purpose | What It Does |
|--------|-----------|---------|--------------|
| **sw_emu** | 1-5 min | Functional testing | Runs kernel as CPU code |
| **hw_emu** | 30-60 min | Performance validation | Full HLS synthesis + RTL simulation |
| **hw** | 2-6 hours | Production | Full FPGA place & route |

**Key insight:** Use the right target at the right time to save days of development time.

---

## sw_emu (Software Emulation)

### "Does it work?"

**What happens:**
```
Your C++ kernel → Compiled as CPU code → Runs on host processor
```

### Characteristics
- ⚡ **Fast:** 1-5 minutes to build
- 💻 **Where:** Runs on CPU (no FPGA synthesis)
- ✅ **Good for:** Algorithm correctness, debugging logic
- ❌ **Not good for:** Performance estimation, resource usage

### When to Use

✅ **Initial development**
```bash
./fpga_build_template.sh -p dev -k kernel -s kernel.cpp -t sw_emu -c
./fpga_run_template.sh -p dev -x results/kernels/kernel.xo -H host.cpp -t sw_emu -c
```

✅ **Rapid bug fixing** - Fix bugs in minutes, not hours
✅ **Testing new algorithms** - Validate correctness quickly
✅ **Debugging host-kernel communication**

### Example Workflow

```bash
# Write kernel
vim kernel.cpp

# Test quickly
./fpga_build_template.sh -t sw_emu -p test -k kernel -s kernel.cpp -c
./fpga_run_template.sh -t sw_emu -p test -x results/kernels/kernel.xo -H host.cpp -c

# Found a bug? Fix and repeat (only takes 2-3 minutes!)
vim kernel.cpp
./fpga_build_template.sh -t sw_emu -p test -k kernel -s kernel.cpp -c
./fpga_run_template.sh -t sw_emu -p test -x results/kernels/kernel.xo -H host.cpp -c
```

**Typical iterations:** 10-50 times during initial development

---

## hw_emu (Hardware Emulation)

### "How fast is it? Will it fit?"

**What happens:**
```
Your C++ kernel → HLS synthesis → RTL generation → RTL simulation
```

### Characteristics
- ⏱️ **Moderate:** 30-60 minutes to build
- 🔧 **Where:** Full hardware synthesis, simulated execution
- ✅ **Good for:** Performance tuning, resource estimation, optimization
- ❌ **Not good for:** Rapid iteration (too slow)

### When to Use

✅ **After sw_emu passes** - Algorithm is correct, now optimize
```bash
./fpga_build_template.sh -p opt -k kernel -s kernel.cpp -t hw_emu -c
```

✅ **Checking resource usage**
```bash
# After build completes
cat results/reports/opt/kernel/system_estimate_kernel.xtxt

# Look for:
# - LUT usage (should be < 1M on U200)
# - FF usage (should be < 2M on U200)
# - BRAM usage (should be < 2000 on U200)
```

✅ **Validating HLS pragmas** - Does PIPELINE help? Is II=1 achieved?

✅ **Performance estimation** - Check latency and throughput

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
- 🐌 **Slow:** 2-6 hours to build
- 🏭 **Where:** Full FPGA compilation (place & route)
- ✅ **Good for:** Final deployment, real performance measurement
- ❌ **Not good for:** Debugging, iteration (way too slow)

### When to Use

✅ **After hw_emu passes** - Design is optimized and fits
```bash
./fpga_build_template.sh -p prod -k kernel -s kernel.cpp -t hw -c
```

✅ **Final performance testing** - Measure real-world speed

✅ **Production deployment** - Create bitstreams for deployment

❌ **Never use for debugging** - Use sw_emu instead

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

## Recommended Development Flow

```
┌────────────────────────────────────────────┐
│  Phase 1: Algorithm Development            │
│  Target: sw_emu (minutes)                  │
│  Goal: Get it working                      │
│  Iterations: 10-50                         │
├────────────────────────────────────────────┤
│  • Write initial kernel (no pragmas)       │
│  • Test with small datasets                │
│  • Fix bugs rapidly                        │
│  • Test edge cases                         │
│  • Verify correctness                      │
└──────────────┬─────────────────────────────┘
               ↓
┌────────────────────────────────────────────┐
│  Phase 2: Optimization                     │
│  Target: hw_emu (hours)                    │
│  Goal: Make it fast                        │
│  Iterations: 5-15                          │
├────────────────────────────────────────────┤
│  • Add PIPELINE pragmas                    │
│  • Add ARRAY_PARTITION pragmas             │
│  • Check resource usage                    │
│  • Validate performance                    │
│  • Balance resources vs performance        │
└──────────────┬─────────────────────────────┘
               ↓
┌────────────────────────────────────────────┐
│  Phase 3: Production                       │
│  Target: hw (days)                         │
│  Goal: Deploy                              │
│  Iterations: 1-3                           │
├────────────────────────────────────────────┤
│  • Build final bitstream                   │
│  • Test on real hardware                   │
│  • Measure actual performance              │
│  • Archive for deployment                  │
└────────────────────────────────────────────┘
```

---

## Time Savings Example

### ❌ Wrong Way: Building hw Every Time

```
Iteration 1: hw build (4 hours) → Find bug → Fix
Iteration 2: hw build (4 hours) → Optimize → Check resources
Iteration 3: hw build (4 hours) → Too many LUTs → Fix
Iteration 4: hw build (4 hours) → Performance low → Optimize
Iteration 5: hw build (4 hours) → Finally works!

Total time: 20 hours (2.5 days)
```

### ✅ Right Way: Using sw_emu → hw_emu → hw

```
sw_emu iterations (10x @ 3 min each) = 30 minutes → Algorithm correct
hw_emu iterations (5x @ 45 min each) = 4 hours → Optimized
hw build (1x @ 4 hours) = 4 hours → Production ready

Total time: 8.5 hours (1 day)
Saved: 11.5 hours (58% faster!)
```

---

## Common Mistakes to Avoid

### ❌ Mistake 1: Using hw for Debugging

```bash
# This is WRONG - wasting hours!
./fpga_build_template.sh -t hw ...  # 4 hours later...
# Error: syntax error in kernel.cpp
# Fix and rebuild... another 4 hours wasted!
```

**✅ Instead:**
```bash
# Start with sw_emu - fix bugs in minutes
./fpga_build_template.sh -t sw_emu ...  # 3 minutes
# Fix bugs quickly, then move to hw_emu
```

### ❌ Mistake 2: Skipping hw_emu

```bash
# This is WRONG
./fpga_build_template.sh -t sw_emu ...  # Works!
./fpga_build_template.sh -t hw ...      # 4 hours later...
# Error: Routing failed - too many LUTs!
```

**✅ Instead:**
```bash
# Use hw_emu to catch resource issues early
./fpga_build_template.sh -t sw_emu ...  # Works!
./fpga_build_template.sh -t hw_emu ...  # 45 min - shows resource usage
grep "LUT" results/reports/*/system_estimate*.xtxt  # Check before hw build
./fpga_build_template.sh -t hw ...      # Now confident it will work!
```

### ❌ Mistake 3: Large Datasets in hw_emu

```bash
# hw_emu is RTL simulation - very slow for large data
./fpga_run_template.sh -t hw_emu ... # Takes hours to simulate!
```

**✅ Instead:**
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