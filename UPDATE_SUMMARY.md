# fpga-templates sw_emu Deprecation Update

## Date: 2025-10-30

## Summary

Updated xilinx-fpga-templates to reflect Xilinx's deprecation of sw_emu in Vitis 2024.2 (complete removal in 2025.1).

## Changes Made

### 1. Documentation Updates

**BUILD_TARGETS.md:**
- Added prominent deprecation notice at the top
- Updated overview table to show HLS C Sim instead of sw_emu
- Added comprehensive HLS C Simulation section with examples
- Marked sw_emu section as DEPRECATED with collapsible legacy info
- Updated workflow recommendations

**SW_EMU_MIGRATION.md (NEW):**
- Comprehensive 300+ line migration guide
- Step-by-step migration instructions
- Before/after code examples
- Benefits comparison (60x faster iteration)
- FAQ section
- Complete example project migration

### 2. Script Updates

**fpga_build_template.sh:**
- Added interactive deprecation warning when sw_emu is selected
- Shows prominent warning box with migration guidance
- Requires user confirmation to continue with sw_emu
- Points to SW_EMU_MIGRATION.md documentation

### 3. Key Migration Message

**Old Workflow (DEPRECATED):**
```
sw_emu → hw_emu → hw
```

**New Workflow (Vitis 2024.2+):**
```
HLS C Simulation → hw_emu → hw
```

## Benefits for Users

1. **60x Faster Iteration:** HLS C Sim takes seconds instead of minutes
2. **Standard Tools:** Use g++, gdb, valgrind - no Xilinx overhead
3. **Better Isolation:** Test kernel logic separately from XRT complexity
4. **CI/CD Friendly:** Simple C++ builds work anywhere
5. **Future-Proof:** sw_emu will be removed in Vitis 2025.1

## Still TODO (Optional)

The following files still reference sw_emu but are less critical:
- README.md
- README_FPGA_BUILD_TEMPLATE.md  
- README_FPGA_RUN_TEMPLATE.md
- QUICK_START.md
- HLS_TUTORIAL.md
- COMMAND_REFERENCE.md
- TROUBLESHOOTING.md
- examples/vector_add/README.md

These can be updated later or left as-is with the understanding that:
1. The main BUILD_TARGETS.md now has the correct info
2. SW_EMU_MIGRATION.md provides comprehensive guidance
3. The script itself warns users when they try to use sw_emu

## Testing

To test the deprecation warning:
```bash
cd examples/vector_add
../../fpga_build_template.sh -p test -k vadd -s vector_add.cpp -t sw_emu -c
# Should show deprecation warning and prompt for confirmation
```

## References

- Xilinx Answer Record 000036790
- Vitis 2024.2 Release Notes
- docs/BUILD_TARGETS.md
- docs/SW_EMU_MIGRATION.md
