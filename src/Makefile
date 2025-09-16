# Makefile for JTAG DPI-C Simulation on ModelSim
# This Makefile builds and runs a complete JTAG boundary scan test suite
# using ModelSim simulator with DPI-C integration.

# Simulator selection: modelsim
SIM ?= modelsim

# Source file definitions
# RTL sources: JTAG TAP controller, instruction register, boundary scan register, and DUT
RTL_SOURCES = rtl/jtag_tap_controller.sv rtl/jtag_instruction_register.sv rtl/jtag_boundary_scan_register.sv rtl/jtag_top.sv rtl/up_down_counter_loop.sv
# Testbench: SystemVerilog testbench that instantiates the DUT
TB_SOURCES = tb/jtag_testbench.sv
# C++ sources: DPI-C mock library and test implementations
C_SOURCES = dpi/digilent_jtag_mock.cpp dpi/jtag_counter_tests.cpp
# Headers: C++ header files for DPI-C interface
HEADERS = dpi/digilent_jtag_mock.h

# Combined source lists
SV_SOURCES = $(RTL_SOURCES) $(TB_SOURCES)
ALL_SOURCES = $(SV_SOURCES) $(C_SOURCES)

# Compilation flags
# -sv: Enable SystemVerilog support
# -dpiheader: Generate DPI header file
# +acc: Enable access to all signals for debugging
MODELSIM_FLAGS = -sv -dpiheader dpi_header.h +acc

# Coverage flags for comprehensive RTL testing
# +cover=sbfec: Enable statement, branch, fsm, expression, and condition coverage
COVERAGE_FLAGS = +cover=sbfec

# ModelSim flags
VSIM_BIN := $(dir $(shell which vsim))
MTI_INCLUDE ?= $(VSIM_BIN)/../include
MODELSIM_GXX := $(firstword $(wildcard $(VSIM_BIN)/../gcc-7.4.0-linux_x86_64/bin/g++))
ifeq ($(MODELSIM_GXX),)
MODELSIM_GXX := $(firstword $(wildcard $(VSIM_BIN)/../gcc-*/bin/g++))
endif
CXX ?= $(if $(MODELSIM_GXX),$(MODELSIM_GXX),g++)
LDXX ?= $(CXX)
LDFLAGS += -static-libstdc++ -static-libgcc
VCS_FLAGS = -sverilog -CFLAGS -DVCS

# Output directories
BUILD_DIR = build
OBJ_DIR = $(BUILD_DIR)/obj
LIB_NAME = jtag_mock
SO_PATH = $(BUILD_DIR)/$(LIB_NAME).so
OBJS = $(OBJ_DIR)/digilent_jtag_mock.o $(OBJ_DIR)/jtag_counter_tests.o

.PHONY: all clean modelsim coverage_report

all: modelsim

# ModelSim compilation with coverage collection
modelsim: $(BUILD_DIR)/modelsim_lib $(SO_PATH)
	vsim -c -coverage -voptargs="+cover=sbfec" -do "coverage save -codeAll $(BUILD_DIR)/coverage.ucdb; run -all; coverage save -codeAll $(BUILD_DIR)/coverage.ucdb; quit" -sv_lib $(abspath $(BUILD_DIR))/$(LIB_NAME) work.jtag_testbench

$(BUILD_DIR)/modelsim_lib: $(SV_SOURCES) | $(BUILD_DIR)
	# Step 1: Compile SystemVerilog and create work library
	vlib $(BUILD_DIR)/modelsim_lib
	vmap work $(BUILD_DIR)/modelsim_lib
	vlog $(MODELSIM_FLAGS) $(COVERAGE_FLAGS) $(SV_SOURCES) -work $(BUILD_DIR)/modelsim_lib


$(SO_PATH): $(OBJS) | $(BUILD_DIR)
	$(LDXX) -shared -fPIC $(OBJS) -o $(SO_PATH) $(LDFLAGS)

$(OBJ_DIR)/digilent_jtag_mock.o: dpi/digilent_jtag_mock.cpp $(HEADERS) | $(OBJ_DIR)
	$(CXX) -c -fPIC -I$(MTI_INCLUDE) -I. dpi/digilent_jtag_mock.cpp -o $(OBJ_DIR)/digilent_jtag_mock.o

$(OBJ_DIR)/jtag_counter_tests.o: dpi/jtag_counter_tests.cpp $(HEADERS) | $(OBJ_DIR)
	$(CXX) -c -fPIC -I$(MTI_INCLUDE) -I. dpi/jtag_counter_tests.cpp -o $(OBJ_DIR)/jtag_counter_tests.o

# Create build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(OBJ_DIR): | $(BUILD_DIR)
	mkdir -p $(OBJ_DIR)

# Debug targets
debug: MODELSIM_FLAGS += +define+DEBUG
debug: modelsim

waveform: MODELSIM_FLAGS += +define+WAVEFORM_DUMP
waveform: modelsim

# Coverage report target
coverage_report: $(BUILD_DIR)/coverage.ucdb
	@echo "Generating code coverage report..."
	vcover report -html -output $(BUILD_DIR)/coverage_html -details $(BUILD_DIR)/coverage.ucdb
	@echo "Coverage report generated in $(BUILD_DIR)/coverage_html/index.html"
	@echo "Coverage summary:"
	vcover report $(BUILD_DIR)/coverage.ucdb

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	rm -f transcript vsim.wlf *.log

# Help target
help:
	@echo "Available targets:"
	@echo "  modelsim        - Build for ModelSim"
	@echo "  coverage_report - Generate HTML coverage report"
	@echo "  clean           - Clean build artifacts"
	@echo ""
	@echo "Coverage workflow:"
	@echo "  1. make modelsim        - Run simulation with coverage"
	@echo "  2. make coverage_report - Generate HTML report"
	@echo ""
