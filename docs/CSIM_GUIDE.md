# Complete HLS C Simulation Guide

## Overview: Two Approaches for Kernel Testing

When developing FPGA kernels, you have two complementary approaches for testing:

| Approach | Tool | Speed | Purpose |
|----------|------|-------|---------|
| **Manual C++ Sim** | g++ | Seconds | Rapid algorithm iteration |
| **HLS C Simulation** | vitis-run hls | 1-5 min | Validate synthesizability |

**Best Practice:** Use **both** - g++ for rapid iteration, vitis-run hls for validation.

---

## Complete 4-Phase Development Workflow

```
┌─────────────────────────────────────────────────────────────┐
│  Phase 1: Rapid Algorithm Development                       │
│  Tool: g++ (standard C++ compiler)                          │
│  Time: Seconds per iteration                                │
├─────────────────────────────────────────────────────────────┤
│  g++ kernel.cpp test.cpp -o test && ./test                  │
│  • Iterate 20-100+ times                                    │
│  • Fix bugs in seconds                                      │
│  • Use gdb, valgrind, AddressSanitizer                      │
└──────────────┬──────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 2: Synthesizability Validation                       │
│  Tool: vitis-run --mode hls (HLS C Simulation)                         │
│  Time: 1-5 minutes                                          │
├─────────────────────────────────────────────────────────────┤
│  vitis-run --mode hls --tcl csim.tcl                                      │
│  • Run 1-3 times (when algorithm is correct)                │
│  • Checks: Can this code be synthesized to hardware?        │
│  • Catches: Unsupported C++ features, pragma errors         │
└──────────────┬──────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 3: System Integration & Optimization                 │
│  Tool: v++ hw_emu                                           │
│  Time: 30-60 minutes per build                              │
├─────────────────────────────────────────────────────────────┤
│  ./fpga_build_template.sh -t hw_emu ...                     │
│  • Full HLS synthesis + RTL simulation                      │
│  • Check resource usage and performance                     │
│  • Test host + kernel interaction                           │
└──────────────┬──────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────────┐
│  Phase 4: Production Deployment                             │
│  Tool: v++ hw                                               │
│  Time: 2-6 hours                                            │
├─────────────────────────────────────────────────────────────┤
│  ./fpga_build_template.sh -t hw ...                         │
│  • Full place & route                                       │
│  • Deploy to FPGA hardware                                  │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 1: g++ - Rapid Algorithm Development

### When to Use

- **Every time you change kernel logic**
- **Debugging algorithm issues**
- **Testing edge cases**
- **Initial development (20-100+ iterations)**

### Example

```bash
# 1. Write kernel
cat > kernel.cpp << 'EOF'
void my_kernel(int* in, int* out, int size) {
    for (int i = 0; i < size; i++) {
        out[i] = in[i] * 2;
    }
}
EOF

# 2. Write simple testbench
cat > test.cpp << 'EOF'
#include <iostream>
#include <cassert>

void my_kernel(int* in, int* out, int size);

int main() {
    int in[100], out[100];
    for (int i = 0; i < 100; i++) in[i] = i;

    my_kernel(in, out, 100);

    for (int i = 0; i < 100; i++) {
        assert(out[i] == i * 2);
    }
    std::cout << "PASS" << std::endl;
    return 0;
}
EOF

# 3. Compile and test (seconds!)
g++ -std=c++14 -O2 kernel.cpp test.cpp -o test && ./test

# 4. Found a bug? Fix and retest immediately
vim kernel.cpp
g++ -std=c++14 -O2 kernel.cpp test.cpp -o test && ./test  # Only 3 seconds!
```

### Advantages

- **Fastest:** 2-5 seconds compile + run
- **Standard tools:** gdb, valgrind, AddressSanitizer work
- **No Xilinx overhead:** Works anywhere (CI/CD, laptops, etc.)
- **Simple:** Just C++ compilation

---

## Phase 2: vitis-run hls - Synthesizability Validation

### When to Use

- **After algorithm is correct with g++**
- **Before going to hw_emu**
- **When you add HLS pragmas**
- **To catch synthesis issues early**

### What It Checks

vitis-run hls validates that your code **can be synthesized to hardware**:

- **Unsupported C++ features** (dynamic memory, file I/O, etc.)
- **Pragma errors** (incorrect PIPELINE, ARRAY_PARTITION usage)
- **Interface issues** (m_axi, s_axilite pragma problems)
- **Data type issues** (unsupported types, bit-width problems)

### Example: Creating csim.tcl

```tcl
# csim.tcl - HLS C Simulation script
open_project -reset my_kernel_hls
add_files kernel.cpp
add_files -tb test.cpp
set_top my_kernel

open_solution "solution1"
set_part {xcu200-fsgd2104-2-e}
create_clock -period 3.33 -name default

# Run C Simulation
csim_design -clean

# Optional: Run C Synthesis to validate pragmas
# csynth_design

exit
```

### Running HLS C Simulation

```bash
# Method 1: Using TCL script
vitis-run --mode hls --tcl csim.tcl

# Method 2: Interactive (for debugging)
vitis-run --mode hls
# In HLS console:
open_project my_kernel_hls
add_files kernel.cpp
add_files -tb test.cpp
set_top my_kernel
open_solution "solution1"
csim_design
```

### Interpreting Results

**SUCCESS:**
```
INFO: [SIM 2] *************** CSIM start ***************
INFO: [SIM 4] CSIM will launch GCC as the compiler.
PASS
INFO: [SIM 1] CSim done with 0 errors.
```

**FAILURE - Unsupported Feature:**
```
ERROR: [HLS 207-803] Unsupported dynamic memory allocation
```

**FAILURE - Pragma Error:**
```
WARNING: [HLS 200-885] Cannot automatically pipeline loop due to dependencies
```

### Example with HLS Pragmas

```cpp
// kernel.cpp - With HLS pragmas
void my_kernel(int* in, int* out, int size) {
    #pragma HLS INTERFACE m_axi port=in bundle=gmem0
    #pragma HLS INTERFACE m_axi port=out bundle=gmem1
    #pragma HLS INTERFACE s_axilite port=size
    #pragma HLS INTERFACE s_axilite port=return

    for (int i = 0; i < size; i++) {
        #pragma HLS PIPELINE II=1
        out[i] = in[i] * 2;
    }
}
```

Running vitis-run hls will validate:
- Interface pragmas are correct
- PIPELINE pragma can be applied
- Code is synthesizable

---

## Complete Example: Vector Add Kernel

### Step 1: Develop with g++ (50 iterations, 4 minutes total)

```bash
# vadd_kernel.cpp
void vadd(const int* a, const int* b, int* c, int size) {
    for (int i = 0; i < size; i++) {
        c[i] = a[i] + b[i];
    }
}

# vadd_test.cpp
#include <iostream>
#include <cassert>

void vadd(const int* a, const int* b, int* c, int size);

int main() {
    const int N = 1000;
    int a[N], b[N], c[N];

    for (int i = 0; i < N; i++) {
        a[i] = i;
        b[i] = i * 2;
    }

    vadd(a, b, c, N);

    for (int i = 0; i < N; i++) {
        assert(c[i] == a[i] + b[i]);
    }

    std::cout << "PASS: All " << N << " tests passed!" << std::endl;
    return 0;
}

# Compile and test
g++ -std=c++14 -O2 vadd_kernel.cpp vadd_test.cpp -o test && ./test
```

### Step 2: Add HLS Pragmas and Validate with vitis-run hls (2 runs, 4 minutes total)

```cpp
// vadd_kernel.cpp - With HLS pragmas
extern "C" {
void vadd(const int* a, const int* b, int* c, int size) {
    #pragma HLS INTERFACE m_axi port=a bundle=gmem0 depth=1024
    #pragma HLS INTERFACE m_axi port=b bundle=gmem1 depth=1024
    #pragma HLS INTERFACE m_axi port=c bundle=gmem0 depth=1024
    #pragma HLS INTERFACE s_axilite port=size
    #pragma HLS INTERFACE s_axilite port=return

    for (int i = 0; i < size; i++) {
        #pragma HLS PIPELINE II=1
        c[i] = a[i] + b[i];
    }
}
}

# Create csim.tcl
cat > csim.tcl << 'EOF'
open_project -reset vadd_hls
add_files vadd_kernel.cpp
add_files -tb vadd_test.cpp
set_top vadd

open_solution "solution1"
set_part {xcu200-fsgd2104-2-e}
create_clock -period 3.33 -name default

csim_design -clean
exit
EOF

# Run HLS C Simulation
vitis-run --mode hls --tcl csim.tcl

# Output:
# INFO: [SIM 1] CSim done with 0 errors.
# ✓ Code is synthesizable!
```

### Step 3: Build with hw_emu (45 minutes)

```bash
# Now we're confident it will synthesize
./fpga_build_template.sh \
    -p vadd \
    -k vadd \
    -s vadd_kernel.cpp \
    -t hw_emu \
    -b u200 \
    -c

# Check resource usage
grep "LUT\|FF\|BRAM" results/reports/vadd/system_estimate*.xtxt
```

### Step 4: Build for hardware (4 hours)

```bash
./fpga_build_template.sh \
    -p vadd \
    -k vadd \
    -s vadd_kernel.cpp \
    -t hw \
    -b u200 \
    -c
```

---

## Time Comparison

### Wrong Approach: Skip validation phases
```
Iteration 1: hw build (4 hrs) → Pragma error → Cannot synthesize!
Iteration 2: hw build (4 hrs) → Logic bug → Wrong results!
Iteration 3: hw build (4 hrs) → Another bug → Still wrong!
Iteration 4: hw build (4 hrs) → Finally works!

Total: 16 hours wasted
```

### Right Approach: Use all 4 phases
```
Phase 1: g++ iterations (50x @ 5 sec) = 4 minutes → Algorithm correct
Phase 2: vitis-run hls (2x @ 2 min) = 4 minutes → Synthesizable
Phase 3: hw_emu (3x @ 45 min) = 2.25 hours → Optimized
Phase 4: hw build (1x @ 4 hrs) = 4 hours → Deployed

Total: 6.5 hours
Saved: 9.5 hours (60% faster!)
```

---

## Common Questions

### Q: Do I always need both g++ and vitis-run hls?

**A:** Depends on your confidence level:

- **New kernel, learning HLS:** Use both (g++ for iterations, csim for validation)
- **Experienced developer, simple kernel:** g++ might be enough
- **Complex pragmas, unsure of synthesizability:** Definitely use vitis-run hls

### Q: Can I skip vitis-run hls and go straight to hw_emu?

**A:** You can, but it's risky:
- hw_emu takes 30-60 minutes
- If there's a synthesizability issue, you waste time
- vitis-run hls only takes 2-5 minutes and catches issues early

### Q: What if vitis-run hls passes but hw_emu fails?

**A:** This can happen with:
- Resource constraints (too many LUTs/BRAM)
- Timing issues (clock frequency too high)
- These are optimization issues, not synthesizability issues

### Q: Can vitis-run hls replace hw_emu?

**A:** No! They serve different purposes:
- **vitis-run hls:** Validates synthesizability
- **hw_emu:** Validates resource usage, performance, and system integration

---

## Quick Reference

### When to Use Each Tool

| Situation | Use | Command |
|-----------|-----|---------|
| First time writing kernel | g++ | `g++ kernel.cpp test.cpp -o test` |
| Debugging algorithm | g++ | `g++ -g kernel.cpp test.cpp && gdb ./test` |
| Testing edge cases | g++ | `g++ kernel.cpp test.cpp -o test && ./test` |
| Added HLS pragmas | vitis-run hls | `vitis-run --mode hls --tcl csim.tcl` |
| Before hw_emu | vitis-run hls | `vitis-run --mode hls --tcl csim.tcl` |
| Checking resources | hw_emu | `./fpga_build_template.sh -t hw_emu` |
| System integration | hw_emu | `./fpga_build_template.sh -t hw_emu` |
| Production | hw | `./fpga_build_template.sh -t hw` |

### Typical Iteration Counts

- **g++:** 20-100+ iterations (seconds each)
- **vitis-run hls:** 1-3 iterations (minutes each)
- **hw_emu:** 5-15 iterations (30-60 min each)
- **hw:** 1-3 builds (2-6 hours each)

---

## Next Steps

- **Practice:** Start with g++ for your next kernel
- **Validate:** Use vitis-run hls before hw_emu
- **Optimize:** Use hw_emu for resource tuning
- **Deploy:** Build hw only when confident

See also:
- [BUILD_TARGETS.md](BUILD_TARGETS.md) - Complete build target guide
- [SW_EMU_MIGRATION.md](SW_EMU_MIGRATION.md) - Migrating from sw_emu
- [HLS_TUTORIAL.md](HLS_TUTORIAL.md) - HLS programming basics