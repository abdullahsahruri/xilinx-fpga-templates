# C Simulation (csim) Documentation Update

## Date: 2025-10-30

## Summary

Added comprehensive documentation for the complete 4-phase FPGA development workflow, clarifying the roles of g++ and vitis_hls csim.

## Key Question Answered

**"Is g++ or vitis_hls csim recommended?"**

**Answer:** **Both!** They serve different purposes:
- **g++ (Phase 1):** Rapid algorithm iteration (20-100+ iterations in seconds)
- **vitis_hls csim (Phase 2):** Validate synthesizability (1-3 times before hw_emu)

## New 4-Phase Workflow

```
Phase 1: g++ (seconds)           → Algorithm correctness
Phase 2: vitis_hls csim (minutes) → Synthesizability validation
Phase 3: hw_emu (hours)          → System integration
Phase 4: hw (production)         → Deployment
```

## Files Created

### 1. docs/CSIM_GUIDE.md (NEW - 400+ lines)

Comprehensive guide covering:
- When to use g++ vs vitis_hls csim
- Complete workflow with examples
- TCL script templates for vitis_hls
- Time comparisons
- Common questions (FAQ)
- Quick reference table

**Key sections:**
- Phase 1: g++ rapid development (seconds per iteration)
- Phase 2: vitis_hls csim synthesizability check (validates HLS pragmas)
- Phase 3: hw_emu system integration (resource usage)
- Phase 4: hw production (deployment)

**Complete example:** Vector add kernel through all 4 phases

## Files Updated

### 2. docs/BUILD_TARGETS.md

Updated workflow diagram to show 4 phases:
- Added clear distinction between g++ (Phase 1) and vitis_hls csim (Phase 2)
- Emphasized that vitis_hls csim is for **checking synthesizability**
- Added comparison table showing purpose of each phase

### 3. README.md

Added prominent notice at top:
```
## NEW: Recommended 4-Phase Workflow (Vitis 2024.2+)

**sw_emu is DEPRECATED.** Use the new workflow for faster iteration:

Phase 1: g++ (seconds) → Phase 2: vitis_hls csim (minutes) →
Phase 3: hw_emu (hours) → Phase 4: hw (production)
```

## Key Messages

### What vitis_hls csim Does (Phase 2)

vitis_hls csim **validates synthesizability** - it checks:
- Unsupported C++ features (dynamic memory, file I/O)
- HLS pragma errors (PIPELINE, ARRAY_PARTITION issues)
- Interface problems (m_axi, s_axilite pragma errors)
- Data type issues (unsupported types, bit-widths)

### What g++ Does (Phase 1)

g++ is for **algorithm testing**:
- Fastest iteration (seconds, not minutes)
- Standard C++ debugging (gdb, valgrind)
- No Xilinx tools needed
- Test kernel logic in isolation

### When to Use Each

| Tool | When | Why |
|------|------|-----|
| **g++** | Every iteration | Test algorithm logic (20-100+ times) |
| **vitis_hls csim** | Before hw_emu | Validate synthesizability (1-3 times) |
| **hw_emu** | After csim passes | Check resources (5-15 times) |
| **hw** | Production | Deploy to FPGA (1-3 times) |

## Example Workflow

```bash
# Phase 1: Algorithm development (50 iterations, 4 minutes total)
for i in {1..50}; do
    vim kernel.cpp  # Fix bugs
    g++ -std=c++14 kernel.cpp test.cpp -o test && ./test  # 5 seconds
done

# Phase 2: Synthesizability validation (2 iterations, 4 minutes total)
# Add HLS pragmas
vim kernel.cpp  # Add #pragma HLS PIPELINE, etc.

# Create csim.tcl and run
vitis_hls -f csim.tcl  # 2 minutes - validates pragmas

# Phase 3: System integration (5 iterations, 4 hours total)
./fpga_build_template.sh -t hw_emu ...  # 45 min each
# Check resources, optimize pragmas

# Phase 4: Production (1 build, 4 hours)
./fpga_build_template.sh -t hw ...  # 4 hours
```

## Time Savings

**Without proper workflow:**
```
hw build attempts: 4 × 4 hours = 16 hours
(Debugging in hw is very slow!)
```

**With 4-phase workflow:**
```
Phase 1 (g++):          4 minutes
Phase 2 (vitis_hls):    4 minutes
Phase 3 (hw_emu):       4 hours
Phase 4 (hw):           4 hours
────────────────────────────────
Total:                  8 hours

Saved: 8 hours (50% faster!)
```

## Common Misconceptions Addressed

### ❌ Misconception 1
"I should just use vitis_hls csim for all testing"

✅ **Reality:** vitis_hls csim takes 1-5 minutes. Use g++ (seconds) for iteration, then validate with csim.

### ❌ Misconception 2
"g++ testing is not the 'official' way"

✅ **Reality:** Both are valid. g++ for development, vitis_hls csim for validation. Use both!

### ❌ Misconception 3
"I can skip vitis_hls csim and go straight to hw_emu"

✅ **Reality:** You can, but if there's a synthesizability issue, you waste 45 minutes. csim catches it in 2 minutes.

## Documentation Structure

```
docs/
├── CSIM_GUIDE.md           ← NEW: Complete g++ vs vitis_hls guide
├── BUILD_TARGETS.md        ← UPDATED: 4-phase workflow
├── SW_EMU_MIGRATION.md     ← Existing: sw_emu migration
├── HLS_TUTORIAL.md         ← Existing: HLS basics
└── ...
```

## Quick Reference

### Phase 1: g++ (Rapid Development)
```bash
g++ -std=c++14 -O2 kernel.cpp test.cpp -o test && ./test
```

### Phase 2: vitis_hls csim (Synthesizability)
```bash
vitis_hls -f csim.tcl  # Uses testbench, validates pragmas
```

### Phase 3: hw_emu (System Integration)
```bash
./fpga_build_template.sh -t hw_emu ...
```

### Phase 4: hw (Production)
```bash
./fpga_build_template.sh -t hw ...
```

## References

- **CSIM_GUIDE.md** - Complete workflow guide
- **BUILD_TARGETS.md** - Build target comparison
- **SW_EMU_MIGRATION.md** - Migrating from sw_emu
- **README.md** - Overview with new workflow notice

## Summary

The templates now provide clear guidance on:
1. **When to use g++** (rapid testing, Phase 1)
2. **When to use vitis_hls csim** (synthesizability validation, Phase 2)
3. **Why both are important** (different purposes, complementary)
4. **Complete workflow** (4 phases with time estimates)

Users can now develop FPGA kernels more efficiently by using the right tool at the right time!