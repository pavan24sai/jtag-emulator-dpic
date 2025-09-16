# Codebase Overview

## DPI-C Layer (`dpi/`)
- **`digilent_jtag_mock.h`** - API declarations, data structures, DPI-C includes
- **`digilent_jtag_mock.cpp`** - Mock implementation of Digilent JTAG API with device registry, TAP navigation helpers, and pin control functions
- **`jtag_counter_tests.cpp`** - Complete test suite including IDCODE, SAMPLE/PRELOAD, EXTEST, BYPASS, and complex instruction sequence tests

## RTL Design (`rtl/`)
- **`jtag_top.sv`** - Top-level integration module with JTAG interface and system connections
- **`jtag_tap_controller.sv`** - IEEE 1149.1 compliant 16-state TAP finite state machine
- **`jtag_instruction_register.sv`** - 4-bit instruction register with decode logic for IDCODE/SAMPLE/EXTEST/BYPASS
- **`jtag_boundary_scan_register.sv`** - 9-bit boundary scan register for pin control and observation
- **`up_down_counter_loop.sv`** - Device under test (4-bit up/down counter)

## Testbench (`tb/`)
- **`jtag_testbench.sv`** - SystemVerilog testbench with clock generation, reset control, and DPI-C interface

## Build System
- **`Makefile`** - Automated build for ModelSim with SystemVerilog compilation, C++ compilation with necessary flags, and shared library creation
- **`run_sim`** - Simulation execution script

# Execution Steps
Steps to run the emulator on ModelSim software (in Linux).

## Build and Run (Using the Makefile)
```bash
# Clean previous builds
make clean

# Build and run simulation
make modelsim
```

### Manual Steps
```bash
# 1. Compile SystemVerilog sources
vlog -sv rtl/*.sv tb/*.sv

# 2. Compile C++ DPI-C library  
g++ -c -fPIC -I$MTI_INCLUDE dpi/*.cpp
g++ -shared -o build/jtag_mock.so build/obj/*.o

# 3. Run simulation
vsim -sv_lib build/jtag_mock work.jtag_testbench
```