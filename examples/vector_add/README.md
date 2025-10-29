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

### Kernel (`vector_add.cpp`)

Key HLS concepts demonstrated:

1. **Memory Interfaces:**
   ```cpp
   #pragma HLS INTERFACE m_axi port=in1 bundle=gmem0
   ```
   - `m_axi` = AXI Master interface for memory access
   - `bundle` = Groups ports to same memory bank

2. **Pipelining:**
   ```cpp
   #pragma HLS PIPELINE II=1
   ```
   - Processes one element per cycle
   - Maximizes throughput

3. **Function Signature:**
   ```cpp
   extern "C" void vadd(...)
   ```
   - `extern "C"` makes kernel callable from host

### Host (`host.cpp`)

XRT Native API workflow:

1. **Device Management:**
   ```cpp
   auto device = xrt::device(0);
   auto uuid = device.load_xclbin(xclbin_file);
   ```

2. **Kernel Creation:**
   ```cpp
   auto kernel = xrt::kernel(device, uuid, "vadd");
   ```

3. **Buffer Operations:**
   ```cpp
   auto bo_in1 = xrt::bo(device, size, kernel.group_id(0));
   bo_in1.sync(XCL_BO_SYNC_BO_TO_DEVICE);  // Host → Device
   ```

4. **Execution:**
   ```cpp
   auto run = kernel(bo_in1, bo_in2, bo_out, DATA_SIZE);
   run.wait();
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