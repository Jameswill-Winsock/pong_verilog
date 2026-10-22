module paddle_logic #(
    parameter [5:0] X = 6'd2,
    parameter [5:0] START_Y = 6'd27,
    parameter [5:0] HEIGHT = 6'd10,
    parameter [5:0] PADDLE_STEP = 6'd2
) (
    input wire clk,
    input wire srst,
    input wire frame_tick,
    input wire up, 
    input wire down,
    output reg [5:0] x_coord,
    output reg [5:0] y_coord   
);

localparam [6:0] MAX_Y = 7'd64 -{1'b0, HEIGHT};
assign x_coord = X;

always @(posedge clk or posedge srst) begin
    if (srst) begin
        y_coord <= START_Y;
    end else if (frame_tick) begin
        if (up && !down) begin
            if (y_coord > PADDLE_STEP) begin
                y_coord <= y_coord - PADDLE_STEP;
            end else begin
                y_coord <= 6'd0;
            end
        end else if (down && !up) begin
            if ({1'b0, y_coord} + {1'b0, PADDLE_STEP} < MAX_Y) begin
                y_coord <= y_coord + PADDLE_STEP;
            end else begin
                y_coord <= MAX_Y[5:0];
            end
        end
    end
end

endmodule