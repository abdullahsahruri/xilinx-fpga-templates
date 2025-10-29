# HLS Tutorial: From C++ to FPGA

## What is HLS (High-Level Synthesis)?

HLS lets you write FPGA accelerators in **C/C++** instead of Verilog/VHDL:
-  Write algorithms in familiar languages
-  Use pragmas to control hardware behavior
-  Vitis HLS generates RTL automatically
-  Faster development than traditional HDL

---

## Your First HLS Kernel

**Basic structure:**

```cpp
extern "C" {
void my_kernel(
    const int* input,    // Input from memory
    int* output,         // Output to memory
    int size             // Scalar parameter
) {
    // Memory interface (DDR/HBM access)
    #pragma HLS INTERFACE m_axi port=input bundle=gmem0
    #pragma HLS INTERFACE m_axi port=output bundle=gmem0

    // Control interface (host communication)
    #pragma HLS INTERFACE s_axilite port=input
    #pragma HLS INTERFACE s_axilite port=output
    #pragma HLS INTERFACE s_axilite port=size
    #pragma HLS INTERFACE s_axilite port=return

    // Your algorithm with optimization pragmas
    for (int i = 0; i < size; i++) {
        #pragma HLS PIPELINE II=1  // Process 1 element/cycle
        output[i] = input[i] * 2;  // Example computation
    }
}
}
```

**Key components:**
1. `extern "C"` - Prevents C++ name mangling
2. Memory interface pragmas - Define memory access
3. Control interface pragmas - Define host communication
4. Optimization pragmas - Improve performance

---

## Essential HLS Pragmas

### 1. PIPELINE - Maximum Throughput

```cpp
for (int i = 0; i < size; i++) {
    #pragma HLS PIPELINE II=1
    output[i] = input[i] * 2;
}
```

- **II (Initiation Interval)** = cycles between processing iterations
- **II=1** = process 1 element per cycle (maximum throughput)
- **Most important optimization!**

**Without PIPELINE:** 3-5 cycles per element
**With PIPELINE II=1:** 1 cycle per element (3-5x faster!)

### 2. ARRAY_PARTITION - Parallel Access

```cpp
int buffer[1024];
#pragma HLS ARRAY_PARTITION variable=buffer block factor=16
```

- Splits arrays into multiple memory blocks
- Enables parallel reads/writes
- **Options:**
  - `block` - Divide into N chunks
  - `cyclic` - Interleaved distribution
  - `complete` - All elements become registers (fast but expensive)

**Example:** `factor=16` creates 16 parallel banks

### 3. DATAFLOW - Function Pipelining

```cpp
void kernel(int* in, int* out, int size) {
    #pragma HLS DATAFLOW
    int buffer1[SIZE], buffer2[SIZE];

    stage1(in, buffer1, size);      // Runs in parallel with...
    stage2(buffer1, buffer2, size); // ...and...
    stage3(buffer2, out, size);     // ...this
}
```

- Pipelines multiple functions
- Increases throughput for multi-stage algorithms
- Functions execute in parallel with streaming data

### 4. Memory Interfaces

```cpp
#pragma HLS INTERFACE m_axi port=data bundle=gmem0 depth=1024
```

- **m_axi** = AXI Master for DDR/HBM memory access
- **bundle** = Memory bank assignment (gmem0, gmem1, ...)
- **depth** = Array size hint for optimization

**Multiple bundles for parallelism:**
```cpp
#pragma HLS INTERFACE m_axi port=in1 bundle=gmem0  // Bank 0
#pragma HLS INTERFACE m_axi port=in2 bundle=gmem1  // Bank 1 (parallel!)
```

---

## Common HLS Patterns

### Pattern 1: Simple Transformation

```cpp
for (int i = 0; i < size; i++) {
    #pragma HLS PIPELINE II=1
    output[i] = process(input[i]);
}
```

**Use for:** Element-wise operations, filters, transformations

### Pattern 2: Reduction (Sum, Max, Min)

```cpp
int sum = 0;
for (int i = 0; i < size; i++) {
    #pragma HLS PIPELINE II=1
    sum += input[i];
}
output[0] = sum;
```

**Use for:** Aggregations, statistics, finding max/min

### Pattern 3: Multi-Stage Pipeline

```cpp
void kernel(int* in, int* out, int size) {
    #pragma HLS DATAFLOW
    int buffer1[SIZE], buffer2[SIZE];

    stage1(in, buffer1, size);
    stage2(buffer1, buffer2, size);
    stage3(buffer2, out, size);
}
```

**Use for:** Signal processing, image processing, compression

### Pattern 4: Matrix Operations

```cpp
for (int i = 0; i < N; i++) {
    for (int j = 0; j < M; j++) {
        #pragma HLS PIPELINE II=1
        int sum = 0;
        for (int k = 0; k < K; k++) {
            sum += A[i][k] * B[k][j];
        }
        C[i][j] = sum;
    }
}
```

**Use for:** Matrix multiply, convolution, ML inference

---

## Development Workflow

```
┌─────────────────────────────────────────┐
│ 1. Write kernel in C++ (no pragmas)    │
│    └─ Focus on correctness first       │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│ 2. Test with sw_emu                     │
│    └─ Fix bugs rapidly (minutes)        │
│    └─ Iterate 10-20 times               │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│ 3. Add optimization pragmas             │
│    ├─ PIPELINE for loops                │
│    ├─ ARRAY_PARTITION for arrays        │
│    └─ DATAFLOW for functions            │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│ 4. Validate with hw_emu                 │
│    ├─ Check resources (LUT/FF/BRAM)     │
│    ├─ Verify performance                │
│    └─ Iterate 5-10 times                │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│ 5. Build for hardware (hw)              │
│    └─ Deploy to production              │
└─────────────────────────────────────────┘
```

---

## Resource Optimization Tips

### If Using Too Many LUTs

```bash
# Check resource usage
cat results/reports/PROJECT/KERNEL/system_estimate_KERNEL.xtxt
```

**Solutions:**
-  Reduce parallelization (lower ARRAY_PARTITION factor)
-  Reduce PIPELINE unrolling
-  Use fewer memory ports
-  Simplify complex operations

**Example:** Change `factor=32` to `factor=16`

### If Performance Is Low

**Solutions:**
-  Add PIPELINE pragmas to loops
-  Increase ARRAY_PARTITION factor
-  Use multiple memory bundles
-  Check II (should be 1 for best throughput)
-  Add DATAFLOW for multi-function designs

### Resource Limits (Alveo U200)

```
LUT:  < 1,000,000 (out of ~1.3M)
FF:   < 2,000,000 (out of ~2.5M)
BRAM: < 2,000     (out of 2,016)
DSP:  < 6,840     (out of 6,840)
```

**Rule of thumb:** Keep usage < 80% for successful routing

---

## How to Test Your Kernel

### 1. Software Emulation (sw_emu)

```bash
./fpga_build_template.sh -p test -k kernel -s kernel.cpp -t sw_emu -c
./fpga_run_template.sh -p test -x results/kernels/kernel.xo -H host.cpp -t sw_emu -c
```

-  **Time:** 1-5 minutes
- **Purpose:** Functional testing
-  **How:** Runs kernel as CPU code
-  **Use for:** Bug fixing, algorithm validation

### 2. Hardware Emulation (hw_emu)

```bash
./fpga_build_template.sh -p test -k kernel -s kernel.cpp -t hw_emu -c

# Check resources before running
grep "LUT\|FF\|BRAM\|DSP" results/reports/test/kernel/system_estimate*.xtxt

./fpga_run_template.sh -p test -x results/kernels/kernel.xo -H host.cpp -t hw_emu -c
```

-  **Time:** 30-60 minutes
- **Purpose:** Performance validation
-  **How:** Full HLS synthesis + RTL simulation
-  **Use for:** Optimization, resource checking

### 3. Hardware (hw)

```bash
./fpga_build_template.sh -p test -k kernel -s kernel.cpp -t hw -c
./fpga_run_template.sh -p test -x results/kernels/kernel.xo -H host.cpp -t hw -c
```

-  **Time:** 2-6 hours
- **Purpose:** Production deployment
-  **How:** Full FPGA place & route
-  **Use for:** Final builds, real hardware testing

---

## Complete Working Example

See **[examples/vector_add/README.md](../examples/vector_add/README.md)** for:
- Full kernel code with explanations
- Complete host application (XRT Native API)
- Step-by-step execution guide
- Memory interface details
- Customization examples

---

## Learning Resources

### Official Documentation
- [Vitis HLS User Guide](https://docs.xilinx.com/r/en-US/ug1399-vitis-hls)
- [HLS Pragmas Reference](https://docs.xilinx.com/r/en-US/ug1399-vitis-hls/HLS-Pragmas)
- [XRT Documentation](https://xilinx.github.io/XRT/)

### Official Examples
- [Vitis_Accel_Examples](https://github.com/Xilinx/Vitis_Accel_Examples) - Host+kernel examples
- [Vitis-HLS-Introductory-Examples](https://github.com/Xilinx/Vitis-HLS-Introductory-Examples) - HLS techniques
- [Vitis-Tutorials](https://github.com/Xilinx/Vitis-Tutorials) - Comprehensive tutorials

### Next Steps
- [Build targets explained](BUILD_TARGETS.md) - Understanding sw_emu, hw_emu, hw
- [Command reference](COMMAND_REFERENCE.md) - All template options
- [Advanced usage](ADVANCED_USAGE.md) - Makefiles, CI/CD, profiling