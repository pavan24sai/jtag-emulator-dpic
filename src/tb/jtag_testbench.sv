// jtag_testbench.sv
// Testbench for JTAG Boundary Scan Testing
//
// This testbench provides the simulation environment for testing
// the JTAG TAP controller and boundary scan functionality. It includes:
// - Clock generation for both system and JTAG domains
// - DPI-C integration for C++ based test execution
// - Reset sequences
//
// The testbench instantiates the jtag_top module and provides the necessary
// infrastructure for running the complete JTAG test suite via DPI-C.

`timescale 1ns/1ps

module jtag_testbench;

    // System clock
    logic sys_clk = 0;
    always #5 sys_clk = ~sys_clk;  // 100MHz system clock
    
    // JTAG signals
    logic tck = 0;
    logic tms = 0;
    logic tdi = 0;
    logic tdo;
    logic trst_n = 1;
    logic sys_reset_n = 1;
    
    // External pins around boundary scan
    wire up_down_ext;                   // External up_down bidir pin
    wire [3:0] count_ext;               // External count output
    wire [3:0] count_oe_ext;            // External count output enable
    
    // Pull-up for up_down_ext to ensure it's not floating
    pullup(up_down_ext);
    
    // JTAG top-level instance
    jtag_top dut (
        .sys_clk(sys_clk),
        .sys_reset_n(sys_reset_n),
        .tck(tck),
        .tms(tms),
        .tdi(tdi),
        .tdo(tdo),
        .trst_n(trst_n),
        .up_down_ext(up_down_ext),
        .count_ext(count_ext),
        .count_oe_ext(count_oe_ext)
    );
    
    // Test stimulus
    initial begin
        $display("Starting simulation...");
        $display("DPI-C functions should be loaded from ./build/jtag_mock.so");
        
        // Reset sequence
        sys_reset_n = 0;
        #100;
        sys_reset_n = 1;
        #100;
        
        // Wait for a bit
        #1000;
        
        // Run the JTAG tests
        $display("Calling run_counter_jtag_tests at time %0t", $time);
        run_counter_jtag_tests();
        $display("Returned from run_counter_jtag_tests at time %0t", $time);
        
        // Wait a bit more
        #1000;
        
        $display("Simulation completed");
        $finish;
    end
    
    // Import the test function
    import "DPI-C" context task run_counter_jtag_tests();

    // Exported helpers for C++ to drive and sample pins
    export "DPI-C" task sv_wait_cycles;
    export "DPI-C" function sv_get_tdo;
    export "DPI-C" task sv_drive_jtag_pins;
    export "DPI-C" task sv_jtag_step;

    task sv_wait_cycles(input int cycles);
        repeat (cycles) #1;
    endtask

    function byte sv_get_tdo();
        sv_get_tdo = tdo;
    endfunction

    task sv_drive_jtag_pins(input byte tck_val, input byte tms_val, input byte tdi_val);
        tck = tck_val;
        tms = tms_val;
        tdi = tdi_val;
    endtask

    // Single JTAG step: set TMS/TDI, toggle TCK posedge->negedge, sample TDO on negedge
    task sv_jtag_step(input byte tms_in, input byte tdi_in, input byte is_last, output byte tdo_out);
        // Set inputs before rising edge
        tms = tms_in;
        tdi = tdi_in;
        // Ensure TCK low, then posedge with 50% duty cycle
        tck = 0; #0.5;  // TCK low for 0.5 time units
        tck = 1; #1;    // TCK high for 1 time unit (50% duty cycle)
        // Falling edge and sample
        tck = 0; #0.5;  // TCK low for 0.5 time units
        #0.1;  // Small delay to ensure TDO is stable
        tdo_out = tdo;
    endtask


endmodule
