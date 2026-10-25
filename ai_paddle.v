// ai_paddle.v
// computer opponent. drives up/down exactly like a human would. (atleast i tried to kek)

// prediction (no division): ball motion obeys vy = slope*speed/16 and |vx| = speed, so
// dy/dx = slope/16 for the whole rally leg. distance to my face = dx, therefore
//     y_unfolded = ball_y + dx*slope/16
// walls mirror the path, so fold y_unfolded back into 0..62. |dx*slope/16| <= 58*10/16 = 36,
// so at most one fold is ever needed.

// difficulty (diff): reaction distance (when it switches from sloppy tracking to the prediction) 
// and a per-approach aim error that is latched once, so the paddle never jitters.

// if you are trying to understand this code, think like the ai
// just dont become the ai lul
module ai_paddle #(
    parameter [6:0] FACE_X = 7'd58,   // ball left-edge x at which this paddle is hit
    parameter       LEFT   = 0,
    parameter [5:0] H      = 6'd10,
    parameter [7:0] SEED   = 8'hC3
) (
    input  wire clk, srst, frame_tick,
    input  wire [1:0] diff,
    input  wire [5:0] ball_x, ball_y,
    input  wire ball_right,
    input  wire signed [4:0] ball_slope,
    input  wire [5:0] my_y, opp_y,
    output wire up, down
);
    wire approaching = LEFT ? ~ball_right : ball_right;

    // distance (px) from ball to my hit plane, 0 if already past it
    wire signed [7:0] bx8 = {2'b00, ball_x};
    wire signed [7:0] dxs = LEFT ? (bx8 - $signed({1'b0, FACE_X})) : ($signed({1'b0, FACE_X}) - bx8);
    wire [5:0] dx = dxs[7] ? 6'd0 : dxs[5:0];

    // y at my plane, unfolded then folded off the walls
    wire signed [12:0] prod = $signed({7'd0, dx}) * ball_slope;   // dx*slope
    wire signed [12:0] yu   = $signed({7'd0, ball_y}) + (prod >>> 4);
    wire signed [12:0] yf   = (yu < 0) ? -yu : (yu > 13'sd62) ? (13'sd124 - yu) : yu;

    // react distance by difficulty
    // yea yea i know its a cheap ass approach by just limiting view distance but IT WORKS MAN 
    // YOU CAN SEE THE ENTIRE THING AND YET YOU'LL MISS IT KEK
    reg [5:0] react;
    always @* case (diff)
        2'd0: react = 6'd24;
        2'd1: react = 6'd36;
        2'd2: react = 6'd50;
        default: react = 6'd63;
    endcase

    // aim: from diff>=2 try to send the ball away from the opponent
    wire opp_high = ({1'b0, opp_y} + 7'd5) < 7'd32;  // opponent paddle centre in upper half
    wire signed [12:0] aim = diff[1] ? (opp_high ? -13'sd2 : 13'sd2) : 13'sd0;

    reg [7:0] lfsr;
    reg signed [4:0] err;
    reg approaching_q;
    reg [1:0] phase;                                              // frame phase for the speed handicap
    wire signed [4:0] raw = {lfsr[3], lfsr[3:0]};                 // -8..7
    always @(posedge clk or posedge srst) begin
        if (srst) begin
            lfsr <= SEED; 
            err <= 5'sd0; 
            approaching_q <= 1'b0; 
            phase <= 2'd0;
        end else begin
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
            if (frame_tick) begin
                approaching_q <= approaching;
                phase <= phase + 2'd1;
                if (approaching && !approaching_q)
                    err <= (diff == 2'd0) ? raw : (diff == 2'd1) ? (raw >>> 1) : (diff == 2'd2) ? (raw >>> 2) : 5'sd0;
            end
        end
    end

    wire signed [12:0] ball_c  = $signed({7'd0, ball_y}) + 13'sd1;   // ball is 2 px tall
    wire signed [12:0] pred_c  = yf + 13'sd1 + aim + {{8{err[4]}}, err};
    wire signed [12:0] target  = approaching ? ((dx <= react) ? pred_c : ball_c) : 13'sd32;
    wire signed [12:0] my_c    = $signed({7'd0, my_y}) + $signed({7'd0, H >> 1});
    wire signed [12:0] d       = target - my_c;

    // paddle moves 2 px per frame, so a +-1 dead zone cannot oscillate
    // speed handicap: the human-visible difference between levels. 
    // the paddle itself moves 2 px per moving frame, 
    // so duty 4/4, 3/4, 2/4, 1/4 gives 2.0, 1.5, 1.0, 0.5 px/frame average.
    reg allow;
    always @* case (diff)
        2'd3: allow = 1'b1;
        2'd2: allow = (phase != 2'd3);
        2'd1: allow = phase[0];
        default: allow = (phase == 2'd0);
    endcase

    assign up   = allow && (d < -13'sd1);
    assign down = allow && (d >  13'sd1);
endmodule