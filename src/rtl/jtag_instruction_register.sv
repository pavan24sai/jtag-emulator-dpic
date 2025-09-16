// jtag_instruction_register.sv
// JTAG Instruction Register with standard instruction support

module jtag_instruction_register #(
    parameter IR_WIDTH = 4,
    parameter DEVICE_ID = 32'h12345678
) (
    input  logic tck,
    input  logic reset_n,
    input  logic capture_ir,
    input  logic shift_ir,
    input  logic update_ir,
    input  logic tdi,
    output logic tdo,
    
    // Instruction outputs
    output logic [IR_WIDTH-1:0] instruction,
    
    // TDR select signals
    output logic select_bypass,
    output logic select_idcode, 
    output logic select_sample_preload,
    output logic select_extest,
    output logic select_boundary_scan
);

    // Standard IEEE 1149.1 instructions (4-bit encoding)
    localparam [IR_WIDTH-1:0] BYPASS        = 4'b1111;  // All 1s - mandatory
    localparam [IR_WIDTH-1:0] IDCODE        = 4'b0001;  // Device identification
    localparam [IR_WIDTH-1:0] SAMPLE        = 4'b0010;  // Sample/Preload
    localparam [IR_WIDTH-1:0] PRELOAD       = 4'b0010;  // Same as SAMPLE
    localparam [IR_WIDTH-1:0] EXTEST        = 4'b0000;  // External test
    
    // Instruction register shift chain
    logic [IR_WIDTH-1:0] shift_register;
    logic [IR_WIDTH-1:0] instruction_reg;
    
    // Instruction register operations
    always_ff @(posedge tck or negedge reset_n) begin
        if (!reset_n) begin
            shift_register <= IDCODE;  // Power-on default to IDCODE
        end else if (capture_ir) begin
            // Capture fixed pattern (alternating 01 pattern per IEEE 1149.1)
            shift_register <= 4'b0101;
        end else if (shift_ir) begin
            // Shift in new instruction
            shift_register <= {tdi, shift_register[IR_WIDTH-1:1]};
        end
    end
    
    // Update instruction register
    always_ff @(posedge tck or negedge reset_n) begin
        if (!reset_n) begin
            instruction_reg <= IDCODE;  // Default to IDCODE on reset
        end else if (update_ir) begin
            instruction_reg <= shift_register;
            $display("Time=%0t: IR_UPDATE - shift_reg=%h, instruction_reg=%h, update_ir=1", $time, shift_register, instruction_reg);
        end
        
        // Debug update_ir signal
        if (update_ir) begin
            $display("Time=%0t: update_ir asserted - shift_reg=%h, instruction_reg=%h", $time, shift_register, instruction_reg);
        end
        
        // Debug BYPASS instruction specifically
        if (update_ir && shift_register == BYPASS) begin
            $display("Time=%0t: BYPASS instruction detected - shift_reg=%h, instruction_reg=%h", $time, shift_register, instruction_reg);
        end
    end
    
    // Output current instruction
    assign instruction = instruction_reg;
    
    // TDO output
    assign tdo = shift_register[0];
    
    // Instruction decoder - select appropriate TDR
    always_comb begin
        // Default - deselect all
        select_bypass         = 1'b0;
        select_idcode         = 1'b0;
        select_sample_preload = 1'b0;
        select_extest         = 1'b0;
        select_boundary_scan  = 1'b0;
        
        case (instruction_reg)
            BYPASS: begin
                select_bypass = 1'b1;
                $display("Time=%0t: BYPASS selected - instruction_reg=%h", $time, instruction_reg);
            end
            
            IDCODE: begin
                select_idcode = 1'b1;
            end
            
            SAMPLE, PRELOAD: begin
                select_sample_preload = 1'b1;
                select_boundary_scan  = 1'b1;
            end
            
            EXTEST: begin
                select_extest        = 1'b1;
                select_boundary_scan = 1'b1;
            end
            
            default: begin
                // Unknown instruction defaults to BYPASS
                select_bypass = 1'b1;
            end
        endcase
    end
    
    /*
    always @(posedge tck) begin
        if (update_ir) begin
            $display("Time=%0t: IR Updated - shift_reg=%h, instruction_reg=%h", 
                     $time, shift_register, instruction_reg);
            $display("Time=%0t: Select signals - idcode=%b, bypass=%b, boundary_scan=%b", 
                     $time, select_idcode, select_bypass, select_boundary_scan);
        end
    end
    */

endmodule
