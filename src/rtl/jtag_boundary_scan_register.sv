// jtag_boundary_scan_register.sv
// Boundary scan register implementation for up_down_counter_loop

module jtag_boundary_scan_register #(
    parameter N = 4  // Counter width - matches up_down_counter_loop
) (
    input  logic tck,
    input  logic reset_n,
    input  logic capture_dr,
    input  logic shift_dr,
    input  logic update_dr,
    input  logic tdi,
    output logic tdo,
    
    // Interface to up_down_counter_loop
    input  logic up_down_core,           // From core logic
    output logic up_down_pin,            // To external pin
    input  logic [N-1:0] count_core,     // From core logic  
    output logic [N-1:0] count_pin,      // To external pins
    output logic [N-1:0] count_oe,       // Output enable control
    
    // Control signals
    input  logic boundary_scan_mode      // 1 = boundary scan, 0 = normal operation
);

    // Boundary scan register width calculation:
    // - up_down input: 1 cell
    // - count outputs: 2 cells each (data + enable) = 2*N cells  
    // Total: 1 + 2*N cells
    localparam BSR_WIDTH = 1 + (2 * N);
    
    // Boundary scan register
    logic [BSR_WIDTH-1:0] scan_register;
    logic [BSR_WIDTH-1:0] update_register;
    
    // Cell assignments for clarity
    // Cell 0: up_down input capture/control
    localparam UP_DOWN_CELL = 0;
    
    // Cells 1 to N: count output data cells  
    localparam COUNT_DATA_START = 1;
    
    // Cells N+1 to 2*N: count output enable cells
    localparam COUNT_ENABLE_START = 1 + N;

    // Boundary scan register shift operation
    always_ff @(posedge tck or negedge reset_n) begin
        if (!reset_n) begin
            scan_register <= '0;
        end else if (capture_dr) begin
            // Capture current pin states
            // up_down_core should be 1 due to pullup in testbench
            scan_register[UP_DOWN_CELL] <= up_down_core;
            
            // Capture current count output values
            for (int i = 0; i < N; i++) begin
                scan_register[COUNT_DATA_START + i] <= count_core[i];
            end
            
            // Capture current output enable states (all enabled in normal mode)
            for (int i = 0; i < N; i++) begin
                scan_register[COUNT_ENABLE_START + i] <= 1'b1;
            end
        end else if (shift_dr) begin
            // Shift operation: TDI -> scan_register -> TDO (MSB-first)
            scan_register <= {tdi, scan_register[BSR_WIDTH-1:1]};
        end
    end
    
    // Update register for boundary scan control
    always_ff @(posedge tck or negedge reset_n) begin
        if (!reset_n) begin
            // Initialize with default pattern: all zeros with output enables active
            update_register <= '0;
            update_register[COUNT_ENABLE_START +: N] <= {N{1'b1}};  // Set all enable bits to 1
        end else if (update_dr) begin
            update_register <= scan_register;
            // $display("Time=%0t: BSR_UPDATE - scan_reg=%09b, new_update_reg=%09b", $time, scan_register, scan_register);
        end
        
        // Debug update_dr signal
        if (update_dr) begin
            $display("Time=%0t: update_dr asserted", $time);
        end
    end
    
    // TDO output (shift out LSB for LSB-first shifting)
    assign tdo = scan_register[0];
    
    // Pin control logic - mux between normal and boundary scan modes
    always_comb begin
        if (boundary_scan_mode) begin
            // Boundary scan mode - use update register values
            up_down_pin = update_register[UP_DOWN_CELL];
            
            for (int i = 0; i < N; i++) begin
                count_pin[i] = update_register[COUNT_DATA_START + i];
                count_oe[i]  = update_register[COUNT_ENABLE_START + i];
            end
        end else begin
            // Normal operation mode - pass through core signals
            up_down_pin = up_down_core;
            count_pin   = count_core;
            count_oe    = '1;  // Always drive in normal mode
        end
    end

    // Debug information
    /*
    always @(posedge tck) begin
        if (capture_dr) 
            $display("BSR: Capture - up_down=%b, count=%b", up_down_core, count_core);
        if (shift_dr)
            $display("BSR: Shift - TDI=%b, register=%b, TDO=%b", tdi, scan_register, tdo);
        if (update_dr) begin
            $display("BSR: Update - scan_reg=%b, update_reg=%b", scan_register, update_register);
            $display("BSR: Update - up_down_pin=%b, count_pin=%b, count_oe=%b", 
                     update_register[UP_DOWN_CELL], 
                     update_register[COUNT_DATA_START +: N],
                     update_register[COUNT_ENABLE_START +: N]);
        end
    end
    
    always @(*) begin
        if (boundary_scan_mode) begin
            $display("BSR: EXTEST Mode - up_down_pin=%b, count_pin=%b, count_oe=%b", 
                     up_down_pin, count_pin, count_oe);
        end
    end
    */

endmodule
