// beeper.v
// one-bit square-wave beeper, the way the og atari machine did it: no samples, just a divider.
// events are single-clock pulses
// a tone is: divider reload value (pitch) + a length in frames.
// has priority: game over > point > paddle > wall; a lower-priority event never cuts off a higher one.
module beeper #(
    parameter integer CLK_HZ  = 245760,   // 64*64 clocks/frame * 60 fps in the Verilator build
    parameter integer F_WALL  = 240,
    parameter integer F_PADDLE = 480,
    parameter integer F_POINT = 360,
    parameter integer F_OVER  = 180,
    parameter integer N_WALL  = 4,        // lengths in frames
    parameter integer N_PADDLE = 5,
    parameter integer N_POINT = 24,
    parameter integer N_OVER  = 60
) (
    input  wire clk, srst, frame_tick,
    input  wire ev_wall, ev_paddle, ev_point, ev_over,
    output wire beep
);
    // half-period in clocks: f = CLK_HZ / (2*div)
    localparam [15:0] D_WALL = 16'(CLK_HZ / (2 * F_WALL));
    localparam [15:0] D_PADDLE = 16'(CLK_HZ / (2 * F_PADDLE));
    localparam [15:0] D_POINT = 16'(CLK_HZ / (2 * F_POINT));
    localparam [15:0] D_OVER = 16'(CLK_HZ / (2 * F_OVER));

    reg [15:0] div_cnt, div_top;
    reg [6:0]  left;          // frames of tone remaining
    reg [2:0]  prio;
    reg        tone;

    wire [2:0] new_prio = ev_over ? 3'd4 : ev_point ? 3'd3 : ev_paddle ? 3'd2 : ev_wall ? 3'd1 : 3'd0;
    wire accept = (new_prio != 3'd0) && ((left == 7'd0) || (new_prio >= prio));

    always @(posedge clk or posedge srst) begin
        if (srst) begin
            div_cnt <= 16'd0; div_top <= 16'd1; left <= 7'd0; prio <= 3'd0; tone <= 1'b0;
        end else if (accept) begin
            prio <= new_prio; div_cnt <= 16'd0; tone <= 1'b1;
            case (new_prio)
                3'd4:    begin div_top <= D_OVER;   left <= 7'(N_OVER);   end
                3'd3:    begin div_top <= D_POINT;  left <= 7'(N_POINT);  end
                3'd2:    begin div_top <= D_PADDLE; left <= 7'(N_PADDLE); end
                default: begin div_top <= D_WALL;   left <= 7'(N_WALL);   end
            endcase
        end else begin
            if (frame_tick && left != 7'd0) begin
                left <= left - 7'd1;
                if (left == 7'd1) prio <= 3'd0;
            end
            if (left != 7'd0) begin
                if (div_cnt + 16'd1 >= div_top) begin div_cnt <= 16'd0; tone <= ~tone; end
                else div_cnt <= div_cnt + 16'd1;
            end else tone <= 1'b0;
        end
    end

    assign beep = (left != 7'd0) & tone;
endmodule