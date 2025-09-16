// jtag_tap_controller.sv
// IEEE 1149.1 compliant TAP Controller with 16-state FSM

module jtag_tap_controller (
    input  logic tck,
    input  logic tms,
    input  logic trst_n,
    
    // TAP controller state outputs
    output logic [3:0] tap_state,
    
    // Control signals for test data registers
    output logic test_logic_reset,
    output logic run_test_idle,
    output logic select_dr_scan,
    output logic capture_dr,
    output logic shift_dr,
    output logic exit1_dr,
    output logic pause_dr,
    output logic exit2_dr,
    output logic update_dr,
    output logic select_ir_scan,
    output logic capture_ir,
    output logic shift_ir,
    output logic exit1_ir,
    output logic pause_ir,
    output logic exit2_ir,
    output logic update_ir,
    
    // Clock and reset outputs for TDRs
    output logic clock_dr,
    output logic clock_ir,
    output logic reset_n
);

    // TAP Controller state encoding (IEEE 1149.1 Figure 6-1)
    typedef enum logic [3:0] {
        TEST_LOGIC_RESET = 4'h0,
        RUN_TEST_IDLE    = 4'h1,
        SELECT_DR_SCAN   = 4'h2,
        CAPTURE_DR       = 4'h3,
        SHIFT_DR         = 4'h4,
        EXIT1_DR         = 4'h5,
        PAUSE_DR         = 4'h6,
        EXIT2_DR         = 4'h7,
        UPDATE_DR        = 4'h8,
        SELECT_IR_SCAN   = 4'h9,
        CAPTURE_IR       = 4'hA,
        SHIFT_IR         = 4'hB,
        EXIT1_IR         = 4'hC,
        PAUSE_IR         = 4'hD,
        EXIT2_IR         = 4'hE,
        UPDATE_IR        = 4'hF
    } tap_state_e;

    tap_state_e current_state, next_state;

    // TAP controller FSM - separate combinational and clocked logic
    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            current_state <= TEST_LOGIC_RESET;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Combinational next state logic
    always_comb begin
        case (current_state)
            TEST_LOGIC_RESET: begin
                if (tms)
                    next_state = TEST_LOGIC_RESET;
                else
                    next_state = RUN_TEST_IDLE;
            end
                
                RUN_TEST_IDLE: begin
                    if (tms)
                        next_state = SELECT_DR_SCAN;
                    else
                        next_state = RUN_TEST_IDLE;
                end
                
                SELECT_DR_SCAN: begin
                    if (tms)
                        next_state = SELECT_IR_SCAN;
                    else
                        next_state = CAPTURE_DR;
                end
                
                CAPTURE_DR: begin
                    if (tms)
                        next_state = EXIT1_DR;
                    else
                        next_state = SHIFT_DR;
                end
                
                SHIFT_DR: begin
                    if (tms)
                        next_state = EXIT1_DR;
                    else
                        next_state = SHIFT_DR;
                end
                
                EXIT1_DR: begin
                    if (tms)
                        next_state = UPDATE_DR;
                    else
                        next_state = PAUSE_DR;
                end
                
                PAUSE_DR: begin
                    if (tms)
                        next_state = EXIT2_DR;
                    else
                        next_state = PAUSE_DR;
                end
                
                EXIT2_DR: begin
                    if (tms)
                        next_state = UPDATE_DR;
                    else
                        next_state = SHIFT_DR;
                end
                
                UPDATE_DR: begin
                    if (tms)
                        next_state = SELECT_DR_SCAN;
                    else
                        next_state = RUN_TEST_IDLE;
                end
                
                SELECT_IR_SCAN: begin
                    if (tms)
                        next_state = TEST_LOGIC_RESET;
                    else
                        next_state = CAPTURE_IR;
                end
                
                CAPTURE_IR: begin
                    if (tms)
                        next_state = EXIT1_IR;
                    else
                        next_state = SHIFT_IR;
                end
                
                SHIFT_IR: begin
                    if (tms)
                        next_state = EXIT1_IR;
                    else
                        next_state = SHIFT_IR;
                end
                
                EXIT1_IR: begin
                    if (tms)
                        next_state = UPDATE_IR;
                    else
                        next_state = PAUSE_IR;
                end
                
                PAUSE_IR: begin
                    if (tms)
                        next_state = EXIT2_IR;
                    else
                        next_state = PAUSE_IR;
                end
                
                EXIT2_IR: begin
                    if (tms)
                        next_state = UPDATE_IR;
                    else
                        next_state = SHIFT_IR;
                end
                
                UPDATE_IR: begin
                    if (tms)
                        next_state = SELECT_DR_SCAN;
                    else
                        next_state = RUN_TEST_IDLE;
                end
                
            default: begin
                next_state = TEST_LOGIC_RESET;
            end
        endcase
    end

    // Output assignments
    assign tap_state = current_state;
    
    // State decode outputs
    assign test_logic_reset = (current_state == TEST_LOGIC_RESET);
    assign run_test_idle    = (current_state == RUN_TEST_IDLE);
    assign select_dr_scan   = (current_state == SELECT_DR_SCAN);
    assign capture_dr       = (current_state == CAPTURE_DR);
    assign shift_dr         = (current_state == SHIFT_DR);
    assign exit1_dr         = (current_state == EXIT1_DR);
    assign pause_dr         = (current_state == PAUSE_DR);
    assign exit2_dr         = (current_state == EXIT2_DR);
    assign update_dr        = (current_state == UPDATE_DR);
    assign select_ir_scan   = (current_state == SELECT_IR_SCAN);
    assign capture_ir       = (current_state == CAPTURE_IR);
    assign shift_ir         = (current_state == SHIFT_IR);
    assign exit1_ir         = (current_state == EXIT1_IR);
    assign pause_ir         = (current_state == PAUSE_IR);
    assign exit2_ir         = (current_state == EXIT2_IR);
    assign update_ir        = (current_state == UPDATE_IR);
    
    // Clock generation for TDRs
    assign clock_dr = tck & (capture_dr | shift_dr);
    assign clock_ir = tck & (capture_ir | shift_ir);
    
    // Reset signal for TDRs
    assign reset_n = trst_n & ~test_logic_reset;

endmodule