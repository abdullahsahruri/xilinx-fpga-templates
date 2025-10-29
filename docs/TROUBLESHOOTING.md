# Troubleshooting Guide

## Build Errors

### Platform Not Found

**Error:**
```
ERROR: Platform not found for board: u200
```

**Solutions:**

1. **Check available platforms:**
```bash
platforminfo --list
```

2. **Specify exact platform:**
```bash
./fpga_build_template.sh \
    -P xilinx_u200_gen3x16_xdma_2_202110_1 \
    -p test -k kernel -s kernel.cpp
```

3. **Set platform path:**
```bash
export PLATFORM_PATH=/opt/xilinx/platforms
./fpga_build_template.sh ...
```

---

### Vitis Not Found

**Error:**
```
ERROR: Vitis not found at /tools/Xilinx/Vitis
```

**Solutions:**

1. **Source Vitis setup:**
```bash
source /tools/Xilinx/Vitis/2024.2/settings64.sh
```

2. **Set VITIS_PATH:**
```bash
export VITIS_PATH=/custom/path/to/vitis/2024.2
./fpga_build_template.sh ...
```

3. **Check Vitis installation:**
```bash
which v++
# Should show path to v++ compiler
```

---

### Disk Quota Exceeded

**Error:**
```
ERROR: Disk quota exceeded
```

**Solutions:**

1. **Check disk space:**
```bash
df -h /tmp
df -h $HOME
```

2. **Clean old builds:**
```bash
# Clean temporary build files
rm -rf /tmp/${USER}_fpga_builds/*
rm -rf /tmp/${USER}_fpga_runs/*

# Clean old results (be careful!)
rm -rf results/
```

3. **Always use -c flag:**
```bash
# Auto-cleanup after builds
./fpga_build_template.sh ... -c
./fpga_run_template.sh ... -c
```

---

### Syntax Errors in Kernel

**Error:**
```
ERROR: Compilation failed
kernel.cpp:42: syntax error
```

**Solution:**

**Use sw_emu for fast iteration:**
```bash
# Test with sw_emu (1-5 minutes)
./fpga_build_template.sh -t sw_emu -p debug -k kernel -s kernel.cpp -c

# Fix errors
vim kernel.cpp

# Rebuild quickly
./fpga_build_template.sh -t sw_emu -p debug -k kernel -s kernel.cpp -c

# Repeat until it works
# Then move to hw_emu
./fpga_build_template.sh -t hw_emu -p debug -k kernel -s kernel.cpp -c
```

---

## Resource Errors

### Routing Failed - Too Many LUTs

**Error:**
```
ERROR: Routing failed
Using too many LUTs: 1,500,000 (limit: 1,300,000)
```

**Solutions:**

1. **Check resources in hw_emu first:**
```bash
./fpga_build_template.sh -t hw_emu -p test -k kernel -s kernel.cpp -c
grep "LUT" results/reports/test/kernel/system_estimate*.xtxt
```

2. **Reduce parallelization:**
```cpp
// Before (too many resources)
int buffer[1024];
#pragma HLS ARRAY_PARTITION variable=buffer block factor=32

// After (fewer resources)
int buffer[1024];
#pragma HLS ARRAY_PARTITION variable=buffer block factor=16
```

3. **Reduce unrolling:**
```cpp
// Before
#pragma HLS UNROLL factor=16

// After
#pragma HLS UNROLL factor=8
```

4. **Use fewer memory ports:**
```cpp
// Before (3 separate bundles)
#pragma HLS INTERFACE m_axi port=in1 bundle=gmem0
#pragma HLS INTERFACE m_axi port=in2 bundle=gmem1
#pragma HLS INTERFACE m_axi port=out bundle=gmem2

// After (share bundles)
#pragma HLS INTERFACE m_axi port=in1 bundle=gmem0
#pragma HLS INTERFACE m_axi port=in2 bundle=gmem1
#pragma HLS INTERFACE m_axi port=out bundle=gmem0
```

---

### Out of BRAM

**Error:**
```
ERROR: Insufficient BRAM resources
Using: 2,500 BRAM (limit: 2,016)
```

**Solutions:**

1. **Reduce local array sizes:**
```cpp
// Before (too much BRAM)
int buffer[65536];

// After (use streaming or smaller buffers)
int buffer[4096];
```

2. **Use ARRAY_PARTITION complete sparingly:**
```cpp
// Before (all BRAM → registers)
int buffer[1024];
#pragma HLS ARRAY_PARTITION variable=buffer complete

// After (partial partitioning)
int buffer[1024];
#pragma HLS ARRAY_PARTITION variable=buffer block factor=16
```

3. **Stream data instead of buffering:**
```cpp
// Before (stores all data)
int buffer[SIZE];
for (int i = 0; i < SIZE; i++) {
    buffer[i] = input[i];
}
process(buffer);

// After (streaming)
for (int i = 0; i < SIZE; i++) {
    #pragma HLS PIPELINE II=1
    int data = input[i];
    output[i] = process(data);
}
```

---

## Runtime Errors

### Device Not Found

**Error:**
```
ERROR: No devices found
```

**Solutions:**

**For emulation:**
```bash
# Set emulation mode
export XCL_EMULATION_MODE=sw_emu  # or hw_emu

# Run again
./fpga_run_template.sh ...
```

**For hardware:**
```bash
# Check if FPGA is detected
xbutil examine

# If not found, check drivers
xbutil validate --device 0000:01:00.0
```

---

### Kernel Not Found in xclbin

**Error:**
```
ERROR: Kernel 'my_kernel' not found in xclbin
```

**Solutions:**

1. **Check kernel name matches:**
```cpp
// In kernel.cpp
extern "C" {
void vadd(...) {  // ← Kernel name is "vadd"
    ...
}
}
```

```bash
# In build command
./fpga_build_template.sh -k vadd ...  # ← Must match!
```

2. **Verify xclbin contains kernel:**
```bash
xclbinutil --info --input binary_container.xclbin
# Look for kernel name in output
```

---

### Execution Timeout

**Error:**
```
ERROR: Kernel execution timeout
```

**Solutions:**

1. **For hw_emu, use smaller datasets:**
```cpp
// hw_emu is slow (RTL simulation)
#define DATA_SIZE 1024  // Small dataset for hw_emu
```

2. **Check for infinite loops:**
```cpp
// Bad - might loop forever
while (condition) {
    // No guaranteed exit
}

// Good - bounded loop
for (int i = 0; i < MAX_ITER; i++) {
    if (condition) break;
}
```

3. **Increase timeout (if needed):**
```cpp
// In host code
run.wait(std::chrono::seconds(300));  // 5 minute timeout
```

---

### Wrong Results

**Error:**
```
TEST FAILED: Results don't match
```

**Solutions:**

1. **Check data types match:**
```cpp
// Kernel
void kernel(const float* in, float* out, int size) { ... }

// Host must match
auto buffer = bo.map<float*>();  // Not int*!
```

2. **Verify buffer sizes:**
```cpp
// Kernel processes SIZE elements
for (int i = 0; i < SIZE; i++) { ... }

// Host must allocate SIZE elements
size_t bytes = SIZE * sizeof(int);
auto bo = xrt::bo(device, bytes, ...);
```

3. **Check synchronization:**
```cpp
// Must sync TO device before execution
bo_in.sync(XCL_BO_SYNC_BO_TO_DEVICE);

// Execute kernel
auto run = kernel(...);
run.wait();

// Must sync FROM device after execution
bo_out.sync(XCL_BO_SYNC_BO_FROM_DEVICE);
```

4. **Test with sw_emu first:**
```bash
# sw_emu helps catch logic errors
./fpga_build_template.sh -t sw_emu ...
./fpga_run_template.sh -t sw_emu ...
```

---

## Performance Issues

### Low Throughput

**Symptoms:**
- Kernel executes slowly
- Low utilization
- Poor speedup vs CPU

**Solutions:**

1. **Add PIPELINE pragma:**
```cpp
// Before (sequential)
for (int i = 0; i < size; i++) {
    output[i] = input[i] * 2;
}

// After (pipelined)
for (int i = 0; i < size; i++) {
    #pragma HLS PIPELINE II=1
    output[i] = input[i] * 2;
}
```

2. **Check II (Initiation Interval):**
```bash
# Look at synthesis report
cat results/reports/*/kernel/hls_synthesis_report.rpt
# Search for "II=" - should be 1 for best performance
```

3. **Use multiple memory banks:**
```cpp
// Before (sequential memory access)
#pragma HLS INTERFACE m_axi port=in1 bundle=gmem0
#pragma HLS INTERFACE m_axi port=in2 bundle=gmem0

// After (parallel memory access)
#pragma HLS INTERFACE m_axi port=in1 bundle=gmem0
#pragma HLS INTERFACE m_axi port=in2 bundle=gmem1
```

4. **Add DATAFLOW for multi-stage:**
```cpp
void kernel(...) {
    #pragma HLS DATAFLOW
    stage1();
    stage2();
    stage3();
}
```

---

### Memory Bandwidth Bottleneck

**Symptoms:**
- Kernel underutilized
- Memory access is bottleneck

**Solutions:**

1. **Burst transfers:**
```cpp
#pragma HLS INTERFACE m_axi port=data bundle=gmem0 depth=SIZE \
    max_read_burst_length=256 max_write_burst_length=256
```

2. **Local buffering:**
```cpp
// Read into local buffer
int local_buffer[SIZE];
#pragma HLS ARRAY_PARTITION variable=local_buffer block factor=16

// Burst read
for (int i = 0; i < SIZE; i++) {
    #pragma HLS PIPELINE II=1
    local_buffer[i] = input[i];
}

// Process locally (fast)
for (int i = 0; i < SIZE; i++) {
    #pragma HLS PIPELINE II=1
    local_buffer[i] = process(local_buffer[i]);
}

// Burst write
for (int i = 0; i < SIZE; i++) {
    #pragma HLS PIPELINE II=1
    output[i] = local_buffer[i];
}
```

---

## Build Performance Issues

### hw_emu Build Very Slow

**Normal:** hw_emu builds take 30-60 minutes

**If taking > 2 hours:**

1. **Check system resources:**
```bash
top  # CPU usage
free -h  # Memory usage
```

2. **Reduce optimization (faster build):**
```bash
./fpga_build_template.sh -o 0 ...  # Optimization level 0 (fastest)
```

3. **Use sw_emu for iteration:**
```bash
# Iterate quickly with sw_emu
./fpga_build_template.sh -t sw_emu ...

# Only use hw_emu when ready
./fpga_build_template.sh -t hw_emu ...
```

---

### hw Build Extremely Slow

**Normal:** hw builds take 2-6 hours

**If taking > 8 hours or failing:**

1. **Simplify design:**
   - Reduce parallelization
   - Lower optimization level
   - Fewer memory ports

2. **Check resources aren't over 80%:**
```bash
cat results/reports/*/kernel/system_estimate*.xtxt
# LUT/FF/BRAM should be < 80% for good routing
```

---

## Emulation Issues

### emconfig.json Not Found

**Error:**
```
ERROR: emconfig.json not found
```

**Solution:**

**The run template creates it automatically. If manually running:**
```bash
emconfigutil --platform xilinx_u200_... --nd 1
export XCL_EMULATION_MODE=hw_emu
./host.exe binary_container.xclbin
```

---

### XCL_EMULATION_MODE Not Set

**Error:**
```
ERROR: Running emulation without XCL_EMULATION_MODE set
```

**Solution:**

**The run template sets it automatically. If manually running:**
```bash
export XCL_EMULATION_MODE=sw_emu  # or hw_emu
./host.exe binary_container.xclbin
```

---

## Getting More Help

### Enable Verbose Output

```bash
# For build
./fpga_build_template.sh ... -v

# Check logs
cat results/logs/project_build.log
```

### Check Official Documentation

- [Vitis Documentation](https://docs.xilinx.com/r/en-US/ug1416-vitis-documentation)
- [Xilinx Forums](https://support.xilinx.com/s/topic/0TO2E000000YKY3WAO/vitis-acceleration)
- [XRT Documentation](https://xilinx.github.io/XRT/)

### Report Issues

Open an issue at: https://github.com/abdullahsahruri/xilinx-fpga-templates/issues

Include:
- Command you ran
- Error message
- Build log (`results/logs/*.log`)
- Vitis version
- Board type

---

## Quick Diagnosis Flowchart

```
Problem?
│
├─ Build fails
│  ├─ Syntax error → Use sw_emu for fast iteration
│  ├─ Platform not found → Use -P or check platforminfo
│  ├─ Disk quota → Clean /tmp, use -c flag
│  └─ Routing failed → Check resources, reduce parallelization
│
├─ Runtime fails
│  ├─ Device not found → Set XCL_EMULATION_MODE (for emu)
│  ├─ Kernel not found → Check kernel name matches
│  ├─ Timeout → Use smaller dataset for hw_emu
│  └─ Wrong results → Check data types, synchronization
│
└─ Performance low
   ├─ Add PIPELINE II=1
   ├─ Use multiple memory banks
   └─ Check II in synthesis report
```