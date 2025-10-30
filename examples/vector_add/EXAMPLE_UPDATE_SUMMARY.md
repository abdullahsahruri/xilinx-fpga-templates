# Vector Add Example - 4-Phase Workflow Update

This example now demonstrates the complete recommended workflow for FPGA development.

## Files Added

### 1. `test_vadd.cpp` - Standalone Testbench
**Purpose:** Phase 1 & 2 testing without XRT overhead

**Usage:**
```bash
# Phase 1: Rapid iteration with g++
g++ -std=c++14 -O2 -I. vector_add.cpp test_vadd.cpp -o test_vadd && ./test_vadd
```

**Key features:**
- No Xilinx tools required
- Direct kernel function calls
- Standard C++ debugging (gdb, valgrind)
- Seconds per iteration

### 2. `csim.tcl` - Vitis HLS C Simulation Script
**Purpose:** Phase 2 - Validate synthesizability

**Usage:**
```bash
# Phase 2: Check if code can be synthesized
vitis_hls -f csim.tcl
```

**What it validates:**
- HLS pragma syntax (PIPELINE, INTERFACE, etc.)
- Unsupported C++ features
- Data type synthesizability
- Interface configuration

## Updated Files

### `README.md`
**Changes:**
1. Added Phase 1 & 2 files to Files section
2. Replaced old 3-option workflow with 4-phase workflow:
   - **Phase 1:** g++ (Seconds) - Algorithm development
   - **Phase 2:** vitis_hls csim (Minutes) - Synthesizability validation
   - **Phase 3:** hw_emu (Hours) - System integration
   - **Phase 4:** hw (Production) - Real hardware
3. Moved sw_emu to deprecated section with migration guide link

## Complete 4-Phase Workflow Example

```bash
cd examples/vector_add

# Phase 1: Rapid algorithm testing (iterate 20-100+ times)
g++ -std=c++14 -O2 -I. vector_add.cpp test_vadd.cpp -o test_vadd
./test_vadd
# Output: TEST PASSED! All 4096 elements verified. (in seconds)

# Phase 2: Validate synthesizability (run 1-3 times)
vitis_hls -f csim.tcl
# Output: CSim done with 0 errors. (in 1-5 minutes)

# Phase 3: System integration (run 5-10 times)
../../fpga_build_template.sh -p vector_add -k vadd -s vector_add.cpp -b u200 -t hw_emu -c
../../fpga_run_template.sh -p vector_add -x "results/kernels/vadd.xo" -H host.cpp -B u200 -t hw_emu -c
# Output: Resource usage report, timing analysis (in ~1 hour)

# Phase 4: Production deployment (run 1 time)
../../fpga_build_template.sh -p vector_add -k vadd -s vector_add.cpp -b u200 -t hw -c
../../fpga_run_template.sh -p vector_add -x "results/kernels/vadd.xo" -H host.cpp -B u200 -t hw -c
# Output: Real hardware performance (in 2-6 hours)
```

## Key Benefits

### Time Savings
- **Old workflow (sw_emu → hw_emu → hw):**
  - sw_emu: 5 minutes × 50 iterations = 250 minutes
  - Total: ~4+ hours for iteration phase

- **New workflow (g++ → csim → hw_emu → hw):**
  - g++: 5 seconds × 50 iterations = 250 seconds (~4 minutes)
  - csim: 2 minutes × 2 validations = 4 minutes
  - Total: ~8 minutes for iteration phase

**Result: 30x faster iteration!**

### Better Development Experience
1. **Phase 1 (g++):**
   - Use familiar C++ tools (gdb, valgrind, sanitizers)
   - Instant feedback on algorithm bugs
   - No FPGA tool licensing issues
   - CI/CD friendly

2. **Phase 2 (vitis_hls csim):**
   - Catches synthesizability issues early
   - Validates HLS pragmas before long builds
   - Prevents wasted hours on hw_emu with bad pragmas

3. **Phase 3 (hw_emu):**
   - Focus on optimization, not debugging
   - Algorithm already verified
   - Pragmas already validated

4. **Phase 4 (hw):**
   - Confident deployment
   - No surprises

## Migration from Old Example

If you were using the old sw_emu approach:

**Old:**
```bash
../../fpga_build_template.sh -t sw_emu ...  # 5 minutes per iteration
```

**New:**
```bash
g++ -std=c++14 -O2 -I. vector_add.cpp test_vadd.cpp -o test_vadd
./test_vadd  # 5 SECONDS per iteration
```

## References

- Main templates: [../../README.md](../../README.md)
- sw_emu migration: [../../docs/SW_EMU_MIGRATION.md](../../docs/SW_EMU_MIGRATION.md)
- CSIM guide: [../../docs/CSIM_GUIDE.md](../../docs/CSIM_GUIDE.md)
- Build targets: [../../docs/BUILD_TARGETS.md](../../docs/BUILD_TARGETS.md)