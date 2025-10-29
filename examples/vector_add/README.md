# Vector Addition Example

A simple "Hello World" example for Xilinx FPGA development that demonstrates:
- Basic HLS kernel structure
- Memory interface pragmas
- Pipeline optimization
- Host application using XRT Native API
- Data transfer and verification

## What This Example Does

Adds two vectors element-by-element:
```
Vector A: [0, 1, 2, 3, ...]
Vector B: [0, 2, 4, 6, ...]
Result:   [0, 3, 6, 9, ...]
```

## Files

- `vector_add.cpp` - HLS kernel (runs on FPGA)
- `host.cpp` - Host application (runs on CPU, controls FPGA)
- `README.md` - This file

## Quick Start

### Prerequisites

- Xilinx Vitis installed
- Alveo board (U200, U250, U280, etc.) or emulation environment
- Templates from parent directory

### Option 1: Software Emulation (Fastest - Minutes)

Test functionality without hardware synthesis:

```bash
cd examples/vector_add

# Build kernel (sw_emu)
../../fpga_build_template.sh \
    -p vector_add \
    -k vadd \
    -s vector_add.cpp \
    -b u200 \
    -t sw_emu \
    -c

# Link and run
../../fpga_run_template.sh \
    -p vector_add \
    -x "results/kernels/vadd.xo" \
    -H host.cpp \
    -B u200 \
    -t sw_emu \
    -c
```

**Expected output:**
```
=== Vector Addition Example ===
[1/5] Loading FPGA device...
[2/5] Loading xclbin...
[3/5] Creating kernel...
[4/5] Allocating buffers and preparing data...
[5/5] Executing kernel...

=== Results ===
TEST PASSED! All 4096 elements verified.
```

### Option 2: Hardware Emulation (Slower - ~1 Hour)

Validate performance and resource usage:

```bash
# Build kernel (hw_emu)
../../fpga_build_template.sh \
    -p vector_add \
    -k vadd \
    -s vector_add.cpp \
    -b u200 \
    -t hw_emu \
    -c

# Check resource utilization
cat results/reports/vector_add/vadd/system_estimate_vadd.xtxt

# Link and run
../../fpga_run_template.sh \
    -p vector_add \
    -x "results/kernels/vadd.xo" \
    -H host.cpp \
    -B u200 \
    -t hw_emu \
    -c
```

### Option 3: Hardware Build (Slowest - 2-6 Hours)

Build for actual FPGA hardware:

```bash
# Build kernel (hw)
../../fpga_build_template.sh \
    -p vector_add \
    -k vadd \
    -s vector_add.cpp \
    -b u200 \
    -t hw \
    -c

# Link and run (requires physical FPGA)
../../fpga_run_template.sh \
    -p vector_add \
    -x "results/kernels/vadd.xo" \
    -H host.cpp \
    -B u200 \
    -t hw \
    -c
```

## Understanding the Code

### Kernel Code (`vector_add.cpp`)

**Complete kernel implementation:**

```cpp
extern "C" {
void vadd(
    const unsigned int* in1,  // Input vector 1
    const unsigned int* in2,  // Input vector 2
    unsigned int* out,        // Output vector
    int size                  // Vector size
) {
    // Memory interface pragmas - Define how kernel accesses memory
    #pragma HLS INTERFACE m_axi port=in1 bundle=gmem0 depth=4096
    #pragma HLS INTERFACE m_axi port=in2 bundle=gmem1 depth=4096
    #pragma HLS INTERFACE m_axi port=out bundle=gmem0 depth=4096

    // Control interface pragmas - Define how host controls the kernel
    #pragma HLS INTERFACE s_axilite port=in1
    #pragma HLS INTERFACE s_axilite port=in2
    #pragma HLS INTERFACE s_axilite port=out
    #pragma HLS INTERFACE s_axilite port=size
    #pragma HLS INTERFACE s_axilite port=return

    // Main computation loop with pipelining
    for (int i = 0; i < size; i++) {
        #pragma HLS PIPELINE II=1  // Process 1 element per clock cycle
        out[i] = in1[i] + in2[i];
    }
}
}
```

**Key concepts explained:**

1. **`extern "C"` block:**
   - Prevents C++ name mangling
   - Makes kernel callable from host application
   - Required for XRT to find the kernel function

2. **Memory interfaces (`m_axi`):**
   - `m_axi` = AXI Master interface for accessing DDR/HBM memory
   - `bundle=gmem0/gmem1` = Assigns ports to different memory banks
   - `depth=4096` = Hints at maximum array size for optimization
   - `in1` and `out` share `gmem0` (can use same memory bank)
   - `in2` uses `gmem1` (separate bank for parallel access)

3. **Control interfaces (`s_axilite`):**
   - `s_axilite` = AXI-Lite slave interface for control/status
   - Used to pass scalar arguments (pointers, size)
   - `port=return` allows host to check if kernel finished

4. **Pipeline pragma:**
   - `#pragma HLS PIPELINE II=1`
   - **II (Initiation Interval) = 1** means process 1 element per cycle
   - Without this: loop would take 3-5 cycles per element
   - With this: achieves maximum throughput

**How it works:**
- Host loads data into DDR memory
- Kernel reads from `in1` and `in2` in parallel (different memory banks)
- Performs addition in FPGA logic
- Writes result back to `out`
- All pipelined for maximum speed

---

### Host Code (`host.cpp`)

**Complete host implementation (simplified view):**

```cpp
#include <iostream>
#include <vector>
#include <xrt/xrt_device.h>
#include <xrt/xrt_kernel.h>
#include <xrt/xrt_bo.h>

#define DATA_SIZE 4096

int main(int argc, char* argv[]) {
    try {
        // ============ Step 1: Device Initialization ============
        std::cout << "[1/5] Loading FPGA device..." << std::endl;
        auto device = xrt::device(0);  // Open first FPGA device

        // Load compiled FPGA binary (.xclbin)
        std::string xclbin_file = argv[1];
        auto uuid = device.load_xclbin(xclbin_file);

        // ============ Step 2: Kernel Creation ============
        std::cout << "[2/5] Creating kernel..." << std::endl;
        auto kernel = xrt::kernel(device, uuid, "vadd");

        // ============ Step 3: Buffer Allocation ============
        std::cout << "[3/5] Allocating buffers..." << std::endl;
        size_t size_bytes = DATA_SIZE * sizeof(unsigned int);

        // Create buffers in device memory
        auto bo_in1 = xrt::bo(device, size_bytes, kernel.group_id(0));
        auto bo_in2 = xrt::bo(device, size_bytes, kernel.group_id(1));
        auto bo_out = xrt::bo(device, size_bytes, kernel.group_id(2));

        // Map buffers to host memory for access
        auto in1_map = bo_in1.map<unsigned int*>();
        auto in2_map = bo_in2.map<unsigned int*>();
        auto out_map = bo_out.map<unsigned int*>();

        // Initialize input data
        for (int i = 0; i < DATA_SIZE; i++) {
            in1_map[i] = i;          // [0, 1, 2, 3, ...]
            in2_map[i] = i * 2;      // [0, 2, 4, 6, ...]
            out_map[i] = 0;
        }

        // ============ Step 4: Transfer Data to Device ============
        std::cout << "[4/5] Transferring data to device..." << std::endl;
        bo_in1.sync(XCL_BO_SYNC_BO_TO_DEVICE);  // Host → FPGA
        bo_in2.sync(XCL_BO_SYNC_BO_TO_DEVICE);

        // ============ Step 5: Execute Kernel ============
        std::cout << "[5/5] Executing kernel..." << std::endl;
        auto run = kernel(bo_in1, bo_in2, bo_out, DATA_SIZE);
        run.wait();  // Block until kernel completes

        // ============ Step 6: Transfer Results Back ============
        bo_out.sync(XCL_BO_SYNC_BO_FROM_DEVICE);  // FPGA → Host

        // ============ Step 7: Verify Results ============
        std::cout << "\n=== Results ===" << std::endl;
        bool passed = true;
        for (int i = 0; i < DATA_SIZE; i++) {
            unsigned int expected = in1_map[i] + in2_map[i];
            if (out_map[i] != expected) {
                passed = false;
                break;
            }
        }

        if (passed) {
            std::cout << "TEST PASSED! All " << DATA_SIZE
                      << " elements verified." << std::endl;
        } else {
            std::cout << "TEST FAILED!" << std::endl;
        }

        return passed ? 0 : 1;

    } catch (std::exception const& e) {
        std::cerr << "ERROR: " << e.what() << std::endl;
        return 1;
    }
}
```

**Key concepts explained:**

1. **XRT Native API (Modern approach):**
   - `xrt::device` - Represents the FPGA device
   - `xrt::kernel` - Represents a hardware kernel
   - `xrt::bo` - Buffer Object for device memory
   - Better than older OpenCL API (simpler, less boilerplate)

2. **Device initialization:**
   ```cpp
   auto device = xrt::device(0);  // Device index 0
   auto uuid = device.load_xclbin(xclbin_file);  // Load bitstream
   ```
   - Opens FPGA device (use 0 for first card)
   - Loads .xclbin (FPGA configuration + kernel code)
   - Returns UUID to identify the loaded program

3. **Kernel object creation:**
   ```cpp
   auto kernel = xrt::kernel(device, uuid, "vadd");
   ```
   - Creates handle to kernel function
   - "vadd" must match kernel name in vector_add.cpp
   - Used to get memory bank groups and execute kernel

4. **Buffer allocation with bank mapping:**
   ```cpp
   auto bo_in1 = xrt::bo(device, size_bytes, kernel.group_id(0));
   ```
   - `kernel.group_id(0)` = memory bank for argument 0 (in1)
   - `kernel.group_id(1)` = memory bank for argument 1 (in2)
   - Automatically maps to correct DDR/HBM banks

5. **Memory mapping:**
   ```cpp
   auto in1_map = bo_in1.map<unsigned int*>();
   ```
   - Maps device buffer to host-accessible pointer
   - Allows reading/writing data from CPU
   - Changes don't appear on device until `sync()`

6. **Data synchronization:**
   ```cpp
   bo_in1.sync(XCL_BO_SYNC_BO_TO_DEVICE);    // CPU → FPGA
   bo_out.sync(XCL_BO_SYNC_BO_FROM_DEVICE);  // FPGA → CPU
   ```
   - Explicit DMA transfers between host and device
   - `TO_DEVICE` = copy data to FPGA memory
   - `FROM_DEVICE` = read results back

7. **Kernel execution:**
   ```cpp
   auto run = kernel(bo_in1, bo_in2, bo_out, DATA_SIZE);
   run.wait();
   ```
   - Pass buffer objects and scalar arguments
   - `run` is a handle to track execution
   - `wait()` blocks until kernel finishes

**Execution flow:**
```
Host CPU                          FPGA Device
--------                          -----------
1. Prepare data in RAM
2. DMA transfer → → → → → → →    3. Data in DDR
                                  4. Kernel reads from DDR
                                  5. Performs addition
                                  6. Writes results to DDR
7. DMA transfer ← ← ← ← ← ← ←
8. Verify results in RAM
```

## Customization Ideas

### Modify Vector Size

In `host.cpp`:
```cpp
#define DATA_SIZE 8192  // Change from 4096 to 8192
```

### Change Data Type

Replace `unsigned int` with `float`:
```cpp
// In kernel:
void vadd(const float* in1, const float* in2, float* out, int size)

// In host:
auto in1_map = bo_in1.map<float*>();
```

### Add More Operations

Extend the kernel:
```cpp
out[i] = (in1[i] + in2[i]) * 2;  // Add and multiply
```

## Troubleshooting

### "Device not found"
- For emulation: Set `export XCL_EMULATION_MODE=sw_emu` or `hw_emu`
- For hardware: Check `xbutil examine` to verify board is detected

### "Compilation errors"
- Verify Vitis environment: `which v++`
- Source setup: `source /tools/Xilinx/Vitis/2024.2/settings64.sh`

### "Different results"
- Check data types match between kernel and host
- Verify buffer sizes are correct

## Expected Resource Usage (U200, hw_emu)

Approximate values:
- **LUTs:** ~1,000 (< 0.1%)
- **FFs:** ~1,500 (< 0.1%)
- **BRAMs:** 0
- **DSPs:** 0

Very lightweight example - good starting point!

## Next Steps

After successfully running this example:

1. **Experiment with optimizations:**
   - Try different pipeline intervals
   - Add dataflow pragma
   - Use different memory bundles

2. **Try other examples:**
   - Matrix multiplication (demonstrates array partitioning)
   - FIR filter (shows more complex pipelining)

3. **Build your own kernel:**
   - Use this as a template
   - Modify for your application
   - Follow the same build workflow

## Reference

- [Vitis HLS User Guide](https://docs.xilinx.com/r/en-US/ug1399-vitis-hls)
- [XRT Documentation](https://xilinx.github.io/XRT/)
- [Main Repository README](../../README.md)