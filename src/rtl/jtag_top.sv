// jtag_top.sv
// Complete JTAG TAP Controller with Boundary Scan Support
//
// This module implements a full JTAG Test Access Port (TAP) controller with
// boundary scan capabilities for testing an up-down counter. It includes:
// - TAP state machine for JTAG protocol compliance
// - Instruction register for command decoding
// - Boundary scan register for pin testing
// - IDCODE register for device identification
// - BYPASS register for minimal delay path
// - Integration with the up_down_counter_loop DUT
//
// The module supports standard JTAG instructions:
// - IDCODE (0x1): Device identification
// - SAMPLE (0x2): Capture current pin states
// - EXTEST (0x3): Drive pins for external testing
// - BYPASS (0xF): 1-bit bypass register

module jtag_top #(
    parameter N = 4,
    parameter MAX_VALUE = 10,
    parameter DEVICE_ID = 32'h12345678
) (
    // System signals
    input  logic sys_clk,
    input  logic sys_reset_n,
    
    // JTAG interface
    input  logic tck,
    input  logic tms, 
    input  logic tdi,
    output logic tdo,
    input  logic trst_n,
    
    // External interface (after boundary scan)  
    inout  logic up_down_ext,           // Bidirectional: input in normal mode, output in EXTEST
    output logic [N-1:0] count_ext,
    output logic [N-1:0] count_oe_ext
);

    // TAP Controller signals
    logic [3:0] tap_state;
    logic capture_dr, shift_dr, update_dr;
    logic capture_ir, shift_ir, update_ir;
    logic clock_dr, clock_ir, tap_reset_n;
    
    // Instruction Register signals
    logic [3:0] instruction;
    logic ir_tdo;
    logic select_bypass, select_idcode, select_sample_preload, select_extest, select_boundary_scan;
    
    // Test Data Register signals
    logic bypass_tdo, idcode_tdo, bsr_tdo;
    logic boundary_scan_mode;
    
    // Core logic signals (internal)
    logic up_down_core, up_down_pin;
    logic [N-1:0] count_core, count_pin;
    logic [N-1:0] count_oe;
    
    // TDO multiplexer selection
    logic selected_tdo;

    // Instantiate TAP Controller
    jtag_tap_controller tap_controller (
        .tck(tck),
        .tms(tms),
        .trst_n(trst_n),
        .tap_state(tap_state),
        .capture_dr(capture_dr),
        .shift_dr(shift_dr),
        .update_dr(update_dr),
        .capture_ir(capture_ir),
        .shift_ir(shift_ir),
        .update_ir(update_ir),
        .clock_dr(clock_dr),
        .clock_ir(clock_ir),
        .reset_n(tap_reset_n),
        .test_logic_reset(),
        .run_test_idle(),
        .select_dr_scan(),
        .exit1_dr(),
        .pause_dr(),
        .exit2_dr(),
        .select_ir_scan(),
        .exit1_ir(),
        .pause_ir(),
        .exit2_ir()
    );

    // Instantiate Instruction Register
    jtag_instruction_register #(
        .IR_WIDTH(4),
        .DEVICE_ID(DEVICE_ID)
    ) instruction_register (
        .tck(tck),
        .reset_n(tap_reset_n),
        .capture_ir(capture_ir),
        .shift_ir(shift_ir),
        .update_ir(update_ir),
        .tdi(tdi),
        .tdo(ir_tdo),
        .instruction(instruction),
        .select_bypass(select_bypass),
        .select_idcode(select_idcode),
        .select_sample_preload(select_sample_preload),
        .select_extest(select_extest),
        .select_boundary_scan(select_boundary_scan)
    );

    // Boundary scan mode control
    assign boundary_scan_mode = select_extest;

    // Instantiate Boundary Scan Register
    jtag_boundary_scan_register #(
        .N(N)
    ) boundary_scan_register (
        .tck(tck),
        .reset_n(tap_reset_n),
        .capture_dr(capture_dr & select_boundary_scan),
        .shift_dr(shift_dr & select_boundary_scan),
        .update_dr(update_dr & select_boundary_scan),
        .tdi(tdi),
        .tdo(bsr_tdo),
        .up_down_core(up_down_ext),
        .up_down_pin(up_down_pin),
        .count_core(count_core),
        .count_pin(count_pin),
        .count_oe(count_oe),
        .boundary_scan_mode(boundary_scan_mode)
    );

    // Instantiate Device ID Register (32-bit)
    // JTAG standard requires MSB-first shifting for IDCODE
    logic [31:0] idcode_shift_reg;
    always_ff @(posedge tck or negedge tap_reset_n) begin
        if (!tap_reset_n) begin
            idcode_shift_reg <= DEVICE_ID;
        end else if (capture_dr & select_idcode) begin
            idcode_shift_reg <= DEVICE_ID;
            $display("Time=%0t: IDCODE CAPTURE - DEVICE_ID=%h loaded", $time, DEVICE_ID);
        end else if (shift_dr & select_idcode) begin
            idcode_shift_reg <= {tdi, idcode_shift_reg[31:1]};
        end
    end
    assign idcode_tdo = idcode_shift_reg[0];

    // Instantiate Bypass Register (1-bit)
    // Bypass register should echo TDI with 1-cycle delay
    logic bypass_reg;
    always_ff @(posedge tck or negedge tap_reset_n) begin
        if (!tap_reset_n) begin
            bypass_reg <= 1'b0;
        end else if (shift_dr & select_bypass) begin
            bypass_reg <= tdi;
            $display("Time=%0t: BYPASS_REG - tdi=%d, bypass_reg=%d, bypass_tdo=%d", $time, tdi, bypass_reg, bypass_tdo);
        end
    end
    // Bypass register outputs the previous value (1-cycle delay)
    assign bypass_tdo = bypass_reg;

    // TDO Multiplexer
    always_comb begin
        if (shift_ir) begin
            selected_tdo = ir_tdo;
        end else if (select_boundary_scan) begin
            selected_tdo = bsr_tdo;
        end else if (select_idcode) begin
            selected_tdo = idcode_tdo;
        end else if (select_bypass) begin
            selected_tdo = bypass_tdo;
        end else begin
            selected_tdo = bypass_tdo;  // Default to bypass
        end
        
        // Debug TDO multiplexer
        if (select_idcode) begin
            $display("Time=%0t: TDO_MUX - select_idcode=1, idcode_tdo=%d, selected_tdo=%d", $time, idcode_tdo, selected_tdo);
        end
    end
    
    // TDO output - registered for stable output
    logic tdo_reg;
    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            tdo_reg <= 1'b0;
        end else begin
            tdo_reg <= selected_tdo;
        end
    end
    assign tdo = tdo_reg;
    
    // Debug final TDO output
    always @(*) begin
        if (select_idcode) begin
            $display("Time=%0t: FINAL_TDO - tdo=%d, selected_tdo=%d, trst_n=%d", $time, tdo, selected_tdo, trst_n);
        end
    end

    // up_down pin control - bidirectional based on boundary scan mode
    always_comb begin
        if (boundary_scan_mode) begin
            // EXTEST mode - BSR drives external pin
            up_down_core = up_down_pin;  // Use BSR value for core
        end else begin
            // Normal mode - external pin drives core
            up_down_core = up_down_ext;  // Use external input for core
        end
    end
    
    // up_down external pin assignment
    assign up_down_ext = boundary_scan_mode ? up_down_pin : 1'bz;

    // Instantiate the actual up_down_counter_loop (DUT)
    up_down_counter_loop #(
        .N(N),
        .MAX_VALUE(MAX_VALUE)
    ) counter_dut (
        .clk(sys_clk),
        .reset(~sys_reset_n),
        .up_down(up_down_core),
        .count(count_core)
    );

    // External pin connections (through boundary scan control)
    assign count_ext     = count_pin;
    assign count_oe_ext  = count_oe;

    always @(posedge tck) begin
        $display("Time=%0t: TAP_State=%h, Instruction=%h, select_idcode=%b", 
                 $time, tap_state, instruction, select_idcode);
        if (shift_dr & select_idcode) begin
            $display("Time=%0t: IDCODE SHIFT - idcode_shift_reg=%h, idcode_tdo=%b", 
                     $time, idcode_shift_reg, idcode_tdo);
        end
        if (shift_dr & select_boundary_scan) begin
            $display("Time=%0t: BSR SHIFT - bsr_tdo=%b", $time, bsr_tdo);
        end
    end

endmodule