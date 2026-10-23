// ball_logic.v -- fixed-point ball: Q8.8 position, speed ramp, angle from hit offset
module ball_logic #(
    parameter [5:0] P1_X = 6'd2,
    parameter [5:0] P2_X = 6'd60,
    parameter [5:0] PADDLE_H = 6'd10,
    parameter [11:0] SPEED0 = 12'd85,    // 0.33 px/frame (same as old BALL_DIV=3)
    parameter [11:0] SPEED_INC = 12'd13, // added per paddle hit
    parameter [11:0] SPEED_MAX = 12'd384,// 1.5 px/frame
    parameter integer SERVE_DELAY = 45
) (
    input  wire clk, srst, frame_tick, halt,
    input  wire [5:0] p1_y, p2_y,
    output wire [5:0] ball_x, ball_y,
    output reg  p1_point, p2_point
);
    reg signed [15:0] px, py, vy;     // Q8.8 px/py, vy in px/frame
    reg [11:0] speed;                 // |vx|, Q.8
    reg going_right;
    reg [7:0] lfsr;
    integer serve_cnt;
 
    assign ball_x = px[13:8];
    assign ball_y = py[13:8];
 
    localparam signed [15:0] LFACE = ({10'd0, P1_X} + 16'sd2) <<< 8;
    localparam signed [15:0] RFACE = ({10'd0, P2_X} - 16'sd2) <<< 8;
    localparam signed [15:0] BOT   = 16'sd62 <<< 8;
    localparam signed [15:0] RMISS = 16'sd62 <<< 8;
    localparam signed [15:0] CENTER = 16'sd31 <<< 8;
    localparam signed [7:0]  H = {2'b00, PADDLE_H};
 
    wire signed [7:0] by_i  = py[15:8];
    wire signed [7:0] p1_t  = {2'b00, p1_y};
    wire signed [7:0] p2_t  = {2'b00, p2_y};
    wire hit_p1_rows = (by_i + 8'sd1 >= p1_t) && (by_i <= p1_t + H - 8'sd1);
    wire hit_p2_rows = (by_i + 8'sd1 >= p2_t) && (by_i <= p2_t + H - 8'sd1);
 
    wire signed [15:0] vx = going_right ? $signed({4'd0, speed}) : -$signed({4'd0, speed});
 
    reg signed [15:0] nx, ny, nvy;
    reg nright;
    reg [11:0] nspeed;
 
    // hit offset in half-pixels: ball centre minus paddle centre, range -H..+H
    wire signed [15:0] by16 = {{8{by_i[7]}}, by_i};
    wire signed [15:0] t1_16 = {{8{p1_t[7]}}, p1_t};
    wire signed [15:0] t2_16 = {{8{p2_t[7]}}, p2_t};
    wire signed [15:0] H16 = {8'd0, H};
    wire signed [15:0] off1 = (by16 <<< 1) + 16'sd2 - (t1_16 <<< 1) - H16;
    wire signed [15:0] off2 = (by16 <<< 1) + 16'sd2 - (t2_16 <<< 1) - H16;
 
    // vy = offset * speed / 16  (tan(theta) = offset/16); explicit 32-bit signed math
    wire [11:0] hit_speed = (speed + SPEED_INC > SPEED_MAX) ? SPEED_MAX : speed + SPEED_INC;
    wire signed [31:0] spd_n = {20'd0, hit_speed};
    wire signed [31:0] vy1 = (({{16{off1[15]}}, off1}) * spd_n) >>> 4;
    wire signed [31:0] vy2 = (({{16{off2[15]}}, off2}) * spd_n) >>> 4;
    // serve: offset -4..+3 from the LFSR
    wire signed [15:0] soff = {13'd0, lfsr[2:0]} - 16'sd4;
    wire signed [31:0] spd0_32 = {20'd0, SPEED0};
    wire signed [31:0] vy_serve = (({{16{soff[15]}}, soff}) * spd0_32) >>> 4;
 
 
    always @* begin
        nx = px + vx; ny = py + vy; nvy = vy; nright = going_right; nspeed = speed;
        // walls: mirror the overshoot instead of clamping
        if (ny < 0)        begin ny = -ny;          nvy = -vy; end
        else if (ny > BOT) begin ny = 2*BOT - ny;   nvy = -vy; end
        // left paddle
        if (!going_right && px >= LFACE && nx < LFACE && hit_p1_rows) begin
            nx = 2*LFACE - nx; nright = 1'b1;
            nspeed = hit_speed;
            nvy = vy1[15:0];
        end
        // right paddle
        if (going_right && px <= RFACE && nx > RFACE && hit_p2_rows) begin
            nx = 2*RFACE - nx; nright = 1'b0;
            nspeed = hit_speed;
            nvy = vy2[15:0];
        end
    end
 
    wire missed_left  = (nx <= 0);
    wire missed_right = (nx >= RMISS);
    wire step_now = frame_tick && !halt && (serve_cnt == 0);
 
    always @(posedge clk or posedge srst) begin
        if (srst) begin
            px <= CENTER; py <= CENTER; vy <= 16'sd15;
            speed <= SPEED0; going_right <= 1'b1; lfsr <= 8'hA5;
            serve_cnt <= SERVE_DELAY; p1_point <= 0; p2_point <= 0;
        end else begin
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
            p1_point <= 0; p2_point <= 0;
            if (frame_tick && !halt && serve_cnt > 0) serve_cnt <= serve_cnt - 1;
            if (step_now) begin
                if (missed_left || missed_right) begin
                    p2_point <= missed_left; p1_point <= missed_right;
                    px <= CENTER; py <= CENTER; speed <= SPEED0;
                    going_right <= missed_left ? 1'b0 : 1'b1;
                    vy <= vy_serve[15:0];
                    serve_cnt <= SERVE_DELAY;
                end else begin
                    px <= nx; py <= ny; vy <= nvy;
                    going_right <= nright; speed <= nspeed;
                end
            end
        end
    end
endmodule