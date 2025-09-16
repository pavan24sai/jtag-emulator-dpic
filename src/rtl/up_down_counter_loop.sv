// up_down_counter_loop.sv
// Up down counter RTL implementation

module up_down_counter_loop #(parameter N = 4, MAX_VALUE = 10) (
    input clk,
    input reset,
    input up_down, // 1 for up, 0 for down
    output reg [N-1:0] count
);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        count <= 0; // Asynchronous reset
    end else begin
        if (up_down) begin // Count up
            if (count == MAX_VALUE) begin
                count <= 0; // Loop back to 0 when reaching MAX_VALUE
            end else begin
                count <= count + 1;
            end
        end else begin // Count down
            if (count == 0) begin
                count <= MAX_VALUE; // Loop back to MAX_VALUE when reaching 0
            end else begin
                count <= count - 1;
            end
        end
    end
end

endmodule
