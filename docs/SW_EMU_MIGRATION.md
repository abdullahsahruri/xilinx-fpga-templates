# sw_emu Deprecation and Migration Guide

## IMPORTANT ANNOUNCEMENT

**Starting Vitis 2024.2:** Software emulation (`sw_emu`) is **DEPRECATED**.
**Starting Vitis 2025.1:** Software emulation will be **REMOVED** completely.

**Xilinx Answer Record:** 000036790

---

## What This Means for You

###  For Alveo/Data Center Users (U200, U250, U280, etc.)

You should migrate to the new workflow:

| Old Workflow (DEPRECATED) | New Workflow (Vitis 2024.2+) |
|---------------------------|------------------------------|
| sw_emu (functional test) | HLS C Simulation (functional test) |
| hw_emu (system test) | hw_emu (system test) |
| hw (production) | hw (production) |

**Action Required:** Replace all `sw_emu` usage with HLS C Simulation.

###  For Embedded Acceleration Users

- Use AIE x86sim for AI Engine kernels
- Use HLS C Simulation for PL kernels
- Use hw_emu for host code development
- Request access to Vitis Functional Simulation (VFS) early access feature

---

## Migration Steps

### Step 1: Understand the Differences

| Feature | sw_emu (OLD) | HLS C Sim (NEW) |
|---------|--------------|-----------------|
| **Build time** | 1-5 minutes | 2-10 seconds |
| **Tools needed** | Vitis, v++, XRT | g++, standard C++ compiler |
| **Tests** | Full system (host + kernel) | Kernel function only |
| **Debugging** | XRT emulation, limited | gdb, valgrind, all standard tools |
| **CI/CD** | Complex (Xilinx tools) | Simple (standard C++ build) |
| **Accuracy** | CPU emulation | CPU execution (same) |
| **Future support** | REMOVED in 2025.1 | Recommended going forward |

**Key Difference:** HLS C Sim tests your **kernel function in isolation** using pure C++ compilation, while sw_emu tested the full system with XRT emulation overhead.

### Step 2: Create HLS C Simulation Testbench

**Old sw_emu approach:**
```cpp
// host.cpp - Required full host code with XRT
#include <CL/cl.h>
#include "xrt/xrt_kernel.h"

int main() {
    // Load FPGA
    auto device = xrt::device(0);
    auto xclbin = device.load_xclbin("kernel.xclbin");
    auto kernel = xrt::kernel(xclbin, "my_kernel");

    // Create buffers
    auto bo_in = xrt::bo(device, size, kernel.group_id(0));
    auto bo_out = xrt::bo(device, size, kernel.group_id(1));

    // ... 50+ lines of XRT boilerplate ...

    // Run kernel
    auto run = kernel(bo_in, bo_out, size);
    run.wait();

    // Verify results
    // ...
}
```

**New HLS C Sim approach:**
```cpp
// kernel_test.cpp - Simple C++ testbench
#include "kernel.h"  // Your kernel header
#include <iostream>
#include <cassert>

int main() {
    // Prepare test data
    const int N = 1000;
    int *input = new int[N];
    int *output = new int[N];

    for (int i = 0; i < N; i++) {
        input[i] = i;
    }

    // Call kernel function directly (no XRT!)
    my_kernel(input, output, N);

    // Verify results
    for (int i = 0; i < N; i++) {
        assert(output[i] == input[i] * 2);  // Expected behavior
    }

    std::cout << "PASS: All tests passed!" << std::endl;

    delete[] input;
    delete[] output;
    return 0;
}
```

Compile and run:
```bash
# Old way (sw_emu) - 3 minutes
./fpga_build_template.sh -t sw_emu -p test -k kernel -s kernel.cpp -c
./fpga_run_template.sh -t sw_emu -p test -x results/kernels/kernel.xo -H host.cpp -c

# New way (HLS C Sim) - 3 seconds!
g++ -std=c++14 -I. kernel.cpp kernel_test.cpp -o test && ./test
```

### Step 3: Update Your Workflow

**Old Workflow:**
```bash
# Phase 1: sw_emu (DEPRECATED)
./fpga_build_template.sh -t sw_emu -p dev -k kernel -s kernel.cpp -c
./fpga_run_template.sh -t sw_emu -p dev -x results/kernels/kernel.xo -H host.cpp -c

# Phase 2: hw_emu
./fpga_build_template.sh -t hw_emu -p dev -k kernel -s kernel.cpp -c

# Phase 3: hw
./fpga_build_template.sh -t hw -p prod -k kernel -s kernel.cpp -c
```

**New Workflow:**
```bash
# Phase 1: HLS C Sim (RECOMMENDED)
g++ -std=c++14 -I. kernel.cpp kernel_test.cpp -o test && ./test

# Phase 2: hw_emu (once kernel logic is correct)
./fpga_build_template.sh -t hw_emu -p dev -k kernel -s kernel.cpp -c
./fpga_run_template.sh -t hw_emu -p dev -x results/kernels/kernel.xo -H host.cpp -c

# Phase 3: hw (production)
./fpga_build_template.sh -t hw -p prod -k kernel -s kernel.cpp -c
```

### Step 4: Update Makefiles and Scripts

**Before (using sw_emu):**
```makefile
test:
	./fpga_build_template.sh -t sw_emu -p test -k kernel -s kernel.cpp -c
	./fpga_run_template.sh -t sw_emu -p test -x results/kernels/kernel.xo -H host.cpp -c
```

**After (using HLS C Sim):**
```makefile
test:
	g++ -std=c++14 -I. kernel.cpp kernel_test.cpp -o test
	./test

integration_test:
	./fpga_build_template.sh -t hw_emu -p test -k kernel -s kernel.cpp -c
	./fpga_run_template.sh -t hw_emu -p test -x results/kernels/kernel.xo -H host.cpp -c
```

---

## Example: Complete Migration

### Before (sw_emu based)

**Directory structure:**
```
my_project/
├── kernel.cpp         # Kernel implementation
├── kernel.h           # Kernel header
├── host.cpp           # Full XRT host code (100+ lines)
└── Makefile           # Uses sw_emu
```

**Makefile:**
```makefile
all: test

test:
	../fpga_build_template.sh -t sw_emu -p test -k my_kernel -s kernel.cpp -c
	../fpga_run_template.sh -t sw_emu -p test -x results/kernels/my_kernel.xo -H host.cpp -c
```

**Typical iteration:** 3-5 minutes per bug fix

### After (HLS C Sim based)

**Directory structure:**
```
my_project/
├── kernel.cpp         # Kernel implementation (unchanged)
├── kernel.h           # Kernel header (unchanged)
├── kernel_test.cpp    # NEW: Simple C++ testbench
├── host.cpp           # Full XRT host code (for hw_emu/hw only)
└── Makefile           # Uses HLS C Sim + hw_emu
```

**kernel_test.cpp (NEW):**
```cpp
#include "kernel.h"
#include <iostream>
#include <cassert>
#include <cstdlib>
#include <ctime>

void test_basic() {
    const int N = 100;
    int input[N], output[N];

    for (int i = 0; i < N; i++) input[i] = i;

    my_kernel(input, output, N);

    for (int i = 0; i < N; i++) {
        assert(output[i] == input[i] * 2);
    }
    std::cout << "PASS: test_basic" << std::endl;
}

void test_edge_cases() {
    // Test with zeros
    int input[10] = {0};
    int output[10];
    my_kernel(input, output, 10);
    for (int i = 0; i < 10; i++) assert(output[i] == 0);

    // Test with negatives
    int input2[5] = {-1, -2, -3, -4, -5};
    int output2[5];
    my_kernel(input2, output2, 5);
    for (int i = 0; i < 5; i++) assert(output2[i] == input2[i] * 2);

    std::cout << "PASS: test_edge_cases" << std::endl;
}

void test_large_data() {
    const int N = 100000;
    int *input = new int[N];
    int *output = new int[N];

    for (int i = 0; i < N; i++) input[i] = rand();

    my_kernel(input, output, N);

    for (int i = 0; i < N; i++) {
        assert(output[i] == input[i] * 2);
    }

    delete[] input;
    delete[] output;
    std::cout << "PASS: test_large_data" << std::endl;
}

int main() {
    srand(time(NULL));

    test_basic();
    test_edge_cases();
    test_large_data();

    std::cout << "\nAll tests passed!" << std::endl;
    return 0;
}
```

**Makefile (NEW):**
```makefile
# Fast kernel testing (seconds)
test:
	g++ -std=c++14 -I. kernel.cpp kernel_test.cpp -o test
	./test

# System integration testing (30-60 min)
integration_test:
	../fpga_build_template.sh -t hw_emu -p test -k my_kernel -s kernel.cpp -c
	../fpga_run_template.sh -t hw_emu -p test -x results/kernels/my_kernel.xo -H host.cpp -c

# Production build (2-6 hours)
production:
	../fpga_build_template.sh -t hw -p prod -k my_kernel -s kernel.cpp -c

# Debug with gdb
debug:
	g++ -g -std=c++14 -I. kernel.cpp kernel_test.cpp -o test_debug
	gdb ./test_debug

.PHONY: test integration_test production debug
```

**Typical iteration:** 3-5 seconds per bug fix (100x faster!)

---

## Benefits of Migration

### Speed

| Task | Old (sw_emu) | New (HLS C Sim) | Speedup |
|------|--------------|-----------------|---------|
| Single test | 3 minutes | 3 seconds | 60x faster |
| 10 iterations | 30 minutes | 30 seconds | 60x faster |
| 50 iterations | 2.5 hours | 2.5 minutes | 60x faster |

### Simplicity

**sw_emu required:**
- Xilinx Vitis installed
- XRT runtime installed
- Complex XRT API knowledge
- Emulation environment setup
- Platform files

**HLS C Sim requires:**
- Standard C++ compiler (g++)
- Your kernel code
- Simple testbench

### Debugging

**sw_emu debugging:**
```bash
# Limited debugging options
export XCL_EMULATION_MODE=sw_emu
./fpga_run_template.sh ...
# Printf debugging mainly
```

**HLS C Sim debugging:**
```bash
# Full power of standard C++ debugging
g++ -g -fsanitize=address kernel.cpp kernel_test.cpp -o test
gdb ./test
valgrind --leak-check=full ./test
# Use breakpoints, watchpoints, memory sanitizers, etc.
```

### CI/CD Integration

**Old (sw_emu):**
```yaml
# .github/workflows/test.yml
- name: Install Vitis
  run: |
    # 50+ lines to install Xilinx tools

- name: Test
  run: |
    source /tools/Xilinx/Vitis/2024.2/settings64.sh
    ./fpga_build_template.sh -t sw_emu ...
```

**New (HLS C Sim):**
```yaml
# .github/workflows/test.yml
- name: Test
  run: |
    g++ -std=c++14 -I. kernel.cpp kernel_test.cpp -o test
    ./test
```

Much simpler, faster, and works on any CI platform!

---

## FAQ

### Q: Do I need to delete all my sw_emu code?

A: Not immediately. sw_emu still works in Vitis 2024.2 (with deprecation warnings). But plan to migrate before Vitis 2025.1 when it will be completely removed.

### Q: What about testing host-kernel interaction?

A: Use `hw_emu` for that. HLS C Sim is for kernel logic only. hw_emu tests the full system including XRT, host code, and kernel.

### Q: Can I still use my old host code?

A: Yes! Your host code remains unchanged. You're just adding a new testing layer (HLS C Sim) for faster kernel iteration.

### Q: What if I need XRT features in testing?

A: For XRT-specific features (buffer management, events, etc.), use `hw_emu`. HLS C Sim is purely for kernel algorithm validation.

### Q: Is HLS C Sim as accurate as sw_emu?

A: Both run your kernel as C++ code on the CPU, so accuracy is similar. HLS C Sim is actually more accurate for kernel behavior since it doesn't involve XRT emulation overhead.

### Q: Will my HLS pragmas work in HLS C Sim?

A: HLS pragmas are ignored during HLS C Sim (just like in sw_emu). They only affect synthesis in hw_emu and hw builds.

---

## Still Have Questions?

- See [BUILD_TARGETS.md](BUILD_TARGETS.md) for detailed build target documentation
- See [HLS_TUTORIAL.md](HLS_TUTORIAL.md) for HLS C Simulation examples
- Xilinx Answer Record: 000036790
- Contact Xilinx support for additional assistance

---

## Summary

**DO THIS:**
-  Migrate from sw_emu to HLS C Simulation
-  Create simple C++ testbenches for your kernels
-  Use hw_emu for system integration testing
-  Enjoy 60x faster iteration times

**DON'T DO THIS:**
-  Continue relying on sw_emu (it will be removed in 2025.1)
-  Skip HLS C Sim and go straight to hw_emu (too slow for rapid iteration)
-  Use hw builds for debugging (way too slow)

**New Workflow:** HLS C Sim (seconds) → hw_emu (minutes) → hw (hours)