# Xilinx FPGA Build Templates

> **Simplified, reusable shell scripts for building and running Xilinx FPGA designs with Vitis HLS**

Stop memorizing complex v++ commands. Automate your FPGA workflow with simple, battle-tested scripts that handle HLS compilation, kernel linking, host compilation, and execution.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Vitis](https://img.shields.io/badge/Vitis-2023.2%2B-orange)](https://www.xilinx.com/products/design-tools/vitis.html)

---

## ✨ Features

- ⚡ **Simple Commands** - Build kernels with a single command
- 🔧 **Auto Platform Detection** - Supports U200, U250, U280, U50, U55C, VCK190
- 💾 **/tmp Builds** - Avoids disk quota issues (multi-GB temp files)
- 🎯 **Three Targets** - sw_emu (minutes), hw_emu (hours), hw (production)
- 📊 **Resource Reporting** - Automatic LUT/FF/BRAM extraction
- 🚀 **Fast Iteration** - Skip linking/compilation when unchanged

---

## 🚀 Quick Start

```bash
# 1. Clone repository
git clone https://github.com/abdullahsahruri/xilinx-fpga-templates.git
cd xilinx-fpga-templates

# 2. Make scripts executable
chmod +x fpga_build_template.sh fpga_run_template.sh

# 3. Build kernel
./fpga_build_template.sh \
    -p vector_add \
    -k vadd \
    -s vector_add.cpp \
    -b u200 \
    -t hw_emu \
    -c

# 4. Link and run
./fpga_run_template.sh \
    -p vector_add \
    -x "results/kernels/vadd.xo" \
    -H host.cpp \
    -B u200 \
    -t hw_emu \
    -c

# Expected output: "TEST PASSED"
```

**See [Quick Start Guide](docs/QUICK_START.md) for installation options and detailed examples.**

---

## 📚 Documentation

### Getting Started
- **[Quick Start Guide](docs/QUICK_START.md)** - Installation and basic usage
- **[Complete Example](examples/vector_add/README.md)** - Full walkthrough with code

### Learning Resources
- **[HLS Tutorial](docs/HLS_TUTORIAL.md)** - Learn HLS programming from scratch
- **[Build Targets Explained](docs/BUILD_TARGETS.md)** - When to use sw_emu vs hw_emu vs hw
- **[Command Reference](docs/COMMAND_REFERENCE.md)** - All available options

### Advanced Topics
- **[README_FPGA_BUILD_TEMPLATE.md](README_FPGA_BUILD_TEMPLATE.md)** - Detailed build template guide
- **[README_FPGA_RUN_TEMPLATE.md](README_FPGA_RUN_TEMPLATE.md)** - Detailed run template guide
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

---

## 🎯 What Problem Does This Solve?

FPGA development with Xilinx Vitis is powerful but complex:

| Problem | This Solution |
|---------|---------------|
| ❌ Complex v++ commands | ✅ Simple one-liners |
| ❌ Disk quota exceeded | ✅ Auto /tmp usage |
| ❌ Remembering platform strings | ✅ Auto-detection |
| ❌ 4-hour builds for debugging | ✅ sw_emu in 3 minutes |
| ❌ Manual environment setup | ✅ Auto-sourcing Vitis/XRT |
| ❌ Rebuilding everything | ✅ Skip unchanged steps |

---

## 🎓 Build Targets Comparison

| Target | Time | Purpose | Use When |
|--------|------|---------|----------|
| **sw_emu** | 1-5 min | Functional testing | Debugging, initial development |
| **hw_emu** | 30-60 min | Performance validation | Optimization, resource checking |
| **hw** | 2-6 hours | Production | Final deployment |

**Development workflow:** sw_emu (fix bugs) → hw_emu (optimize) → hw (deploy)

**Time savings:** Following this workflow saves **5-10 days** compared to building hardware every time.

**[Learn more about build targets →](docs/BUILD_TARGETS.md)**

---

## 📦 What's Included

```
xilinx-fpga-templates/
├── fpga_build_template.sh        # Build kernels (C++ → .xo)
├── fpga_run_template.sh          # Link + compile + run
├── README.md                     # This file
├── docs/
│   ├── QUICK_START.md           # Installation & basic usage
│   ├── HLS_TUTORIAL.md          # Learn HLS programming
│   ├── BUILD_TARGETS.md         # sw_emu vs hw_emu vs hw
│   ├── COMMAND_REFERENCE.md     # All options
│   └── TROUBLESHOOTING.md       # Common issues
├── examples/
│   └── vector_add/              # Complete working example
│       ├── vector_add.cpp       # HLS kernel
│       ├── host.cpp             # XRT host application
│       └── README.md            # Detailed walkthrough
└── README_FPGA_*.md             # Detailed template guides
```

---

## 🌟 Example: Vector Addition

**Complete working example included!**

```bash
cd examples/vector_add

# Software emulation (fastest - validates logic)
../../fpga_build_template.sh -p vector_add -k vadd -s vector_add.cpp -b u200 -t sw_emu -c
../../fpga_run_template.sh -p vector_add -x "results/kernels/vadd.xo" -H host.cpp -B u200 -t sw_emu -c

# Hardware emulation (checks resources & performance)
../../fpga_build_template.sh -p vector_add -k vadd -s vector_add.cpp -b u200 -t hw_emu -c
../../fpga_run_template.sh -p vector_add -x "results/kernels/vadd.xo" -H host.cpp -B u200 -t hw_emu -c
```

**[See complete example with code explanations →](examples/vector_add/README.md)**

---

## 💡 Quick Tips

1. **Always start with sw_emu** - Catch bugs in minutes, not hours
2. **Use hw_emu before hw** - Validate resources before 4-hour builds
3. **Enable auto-cleanup** - Add `-c` flag to save disk space
4. **Check resources early** - `grep "LUT" results/reports/*/system_estimate*.xtxt`
5. **Skip unnecessary steps** - Use `--skip-link` if kernel unchanged

---

## 🎯 Supported Platforms

| Board | Flag | Memory | Use Case |
|-------|------|--------|----------|
| Alveo U200 | `-b u200` | 64GB DDR4 | General development |
| Alveo U250 | `-b u250` | 64GB DDR4 | High bandwidth |
| Alveo U280 | `-b u280` | 8GB HBM2 + DDR4 | AI/ML workloads |
| Alveo U50 | `-b u50` | 8GB HBM2 | Compact form |
| Alveo U55C | `-b u55c` | 16GB HBM2 | Compute/crypto |
| Versal VCK190 | `-b vck190` | DDR4 + LPDDR4 | AI Engine |

**Auto-detection:** Just specify `-b u200` - the scripts find the full platform name automatically.

---

## 🔗 Integration with Xilinx Examples

These templates work seamlessly with official Xilinx repositories:

```bash
# Clone official examples
git clone https://github.com/Xilinx/Vitis_Accel_Examples.git
cd Vitis_Accel_Examples/host_xrt/hello_world

# Use our templates
/path/to/fpga_build_template.sh -p hello -k vadd -s src/vadd.cpp -b u200 -t hw_emu
/path/to/fpga_run_template.sh -p hello -x "results/kernels/vadd.xo" -H src/host.cpp -B u200 -t hw_emu
```

**Official resources:**
- [Vitis_Accel_Examples](https://github.com/Xilinx/Vitis_Accel_Examples)
- [Vitis-HLS-Introductory-Examples](https://github.com/Xilinx/Vitis-HLS-Introductory-Examples)
- [Vitis-Tutorials](https://github.com/Xilinx/Vitis-Tutorials)

---

## ❓ FAQ

**Q: Do I need to modify the scripts for my project?**
A: No! Scripts are completely generic. Just specify your files as arguments.

**Q: Can I use these with existing Makefiles?**
A: Yes. Call scripts from Makefiles or see examples in docs.

**Q: What if I have a custom platform?**
A: Use `-P platform_full_name` to specify the exact platform string.

**Q: How do I add custom v++ flags?**
A: Edit the `run_hls_synthesis()` or `link_kernels()` functions in the scripts.

**Q: What versions of Vitis are supported?**
A: Tested with Vitis 2023.2 and 2024.1+. Should work with any recent version.

---

## 🐛 Troubleshooting

### Common Issues

**"Platform not found"**
```bash
platforminfo --list  # Check available platforms
./fpga_build_template.sh -P xilinx_u200_gen3x16_xdma_2_202110_1 ...
```

**"Disk quota exceeded"**
```bash
rm -rf /tmp/${USER}_fpga_builds/*  # Clean temp files
./fpga_build_template.sh ... -c     # Use auto-cleanup
```

**"Routing failed - too many LUTs"**
```bash
# Check resources in hw_emu first
./fpga_build_template.sh -t hw_emu ...
grep "LUT" results/reports/*/system_estimate*.xtxt

# Reduce parallelization if too high
```

**[See full troubleshooting guide →](docs/TROUBLESHOOTING.md)**

---

## 🤝 Contributing

Contributions welcome! Areas for improvement:
- Additional board support
- More examples (matrix multiply, FIR filter)
- Automated resource checking
- Docker container support

---

## 📄 License

This project is provided as-is for educational and research purposes.

For Xilinx/AMD tool licenses, refer to your Vitis installation agreement.

---

## 🙏 Acknowledgments

- **AMD/Xilinx** for Vitis HLS and comprehensive documentation
- **Xilinx Example Repositories** for reference implementations
- FPGA developer community for feedback and testing

---

## 📞 Support

**For template issues:**
- Open an issue: https://github.com/abdullahsahruri/xilinx-fpga-templates/issues
- Check documentation: [docs/](docs/)

**For Xilinx Vitis issues:**
- [Vitis Documentation](https://docs.xilinx.com/r/en-US/ug1416-vitis-documentation)
- [Xilinx Forums](https://support.xilinx.com/s/topic/0TO2E000000YKY3WAO/vitis-acceleration)
- [AMD Developer Zone](https://developer.amd.com/xilinx/)

---

<p align="center">
  <strong>Built for the FPGA development community</strong><br>
  <sub>Simplifying FPGA workflows, one script at a time</sub>
</p>