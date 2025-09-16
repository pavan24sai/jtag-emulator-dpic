# run_sim.tcl - simulation script for JTAG Counter testbench

echo "========================================"
echo "JTAG Counter Testbench Simulation"
echo "========================================"

# Clear any existing simulation
quit -sim
noview wave

# Load the testbench
vsim -gui -sv_lib ./build/jtag_mock work.jtag_testbench

# Open waveform viewer
view wave

# Add signals to waveform with proper grouping
add wave -divider "System Control"
add wave -color yellow jtag_testbench/sys_clk
add wave -color yellow jtag_testbench/sys_reset_n

add wave -divider "JTAG Interface"  
add wave -color cyan jtag_testbench/tck
add wave -color cyan jtag_testbench/tms
add wave -color cyan jtag_testbench/tdi
add wave -color cyan jtag_testbench/tdo
add wave -color cyan jtag_testbench/trst_n

add wave -divider "External Counter Pins"
add wave -color green jtag_testbench/up_down_ext
add wave -color green -radix unsigned jtag_testbench/count_ext  
add wave -color green -radix unsigned jtag_testbench/count_oe_ext

add wave -divider "TAP Controller State"
add wave -color orange -radix hex jtag_testbench/dut/tap_state

add wave -divider "JTAG Registers"
add wave -color magenta -radix hex jtag_testbench/dut/instruction
add wave -color magenta -radix hex jtag_testbench/dut/selected_tdo

add wave -divider "Counter Core Internal"
add wave -color red -radix unsigned jtag_testbench/dut/count_core
add wave -color red jtag_testbench/dut/up_down_core
add wave -color red jtag_testbench/dut/up_down_pin
add wave -color red -radix unsigned jtag_testbench/dut/count_pin

# Zoom to fit
wave zoom full

echo "Starting simulation..."
echo ""

# Run the simulation
run -all

echo ""
echo "Simulation completed!"
