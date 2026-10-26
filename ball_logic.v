// ball_logic.v -- fixed-point ball on a 128x64 field: Q8.8 position, speed ramp, angle from hit offset,
// rally smash with a speed that bleeds back to the normal rally speed.
//
// State is (px, py, speed, base, slope, direction):
//   |vx| = speed                         (Q.8 px/frame)
//   vy   = slope * speed / 16, signed    (derived every step, never stored, so the angle stays
//                                          consistent while speed changes mid-flight)
//   base = the speed the rally would be at without a smash; after a smash `speed` decays to `base`
module ball_logic #(
    parameter [6:0] P1_X = 7'd2,
    parameter [6:0] P2_X = 7'd124,
    parameter [5:0] PADDLE_H = 6'd10,
    parameter [11:0] SPEED0 = 12'd150,       // 0.59 px/frame at the serve
    parameter [11:0] SPEED_INC = 12'd14,     // added per paddle hit
    parameter [11:0] SPEED_MAX = 12'd512,    // 2 px/frame rally cap
    parameter [11:0] SMASH_BOOST = 12'd192,  // extra speed on a smash (0.75 px/frame)
    parameter [11:0] SMASH_DECAY = 12'd3,    // speed shed per frame until back at the rally speed
    parameter signed [15:0] SMASH_MIN = 16'sd10, // smallest smash slope (x/16): a smash is never flat
    parameter integer SERVE_DELAY = 45
) (
    input  wire clk, srst, frame_tick, halt,
    input  wire p1_armed, p2_armed,         // smash armed (from smash_ctrl)
    input  wire [5:0] p1_y, p2_y,
    output wire [6:0] ball_x,
    output wire [5:0] ball_y,
    output wire ball_right,                 // 1 = travelling toward P2
    output wire signed [4:0] ball_slope,    // tan(theta)*16, signed dy per dx (for AI)
    output wire [11:0] ball_speed,          // |vx| in Q.8 px/frame (for AI smash timing)
    output reg  p1_point, p2_point,
    output reg  ev_wall, ev_paddle,         // one-clock pulses for sound
    output reg  hit_p1, hit_p2,             // my paddle returned the ball
    output reg  smash_p1, smash_p2          // ... and it was a smash
);
    reg signed [17:0] px;
    reg signed [15:0] py;
    reg [11:0] speed, base;
    reg going_right;
    reg signed [4:0] slope, nslope;
    reg wall_hit, paddle_hit, hit1, hit2, smash1, smash2;
    reg [7:0] lfsr;
    integer serve_cnt;

    assign ball_x = px[14:8];
    assign ball_y = py[13:8];
    assign ball_right = going_right;
    assign ball_slope = slope;
    assign ball_speed = speed;

    localparam signed [17:0] LFACE  = ({11'd0, P1_X} + 18'd2) <<< 8;
    localparam signed [17:0] RFACE  = ({11'd0, P2_X} - 18'd2) <<< 8;
    localparam signed [17:0] LMISS  = ({11'd0, P1_X} - 18'd2) <<< 8;
    localparam signed [17:0] RMISS  = ({11'd0, P2_X} + 18'd2) <<< 8;
    localparam signed [17:0] CENTER_X = 18'sd63 <<< 8;
    localparam signed [15:0] CENTER_Y = 16'sd31 <<< 8;
    localparam signed [15:0] BOT    = 16'sd62 <<< 8;
    localparam signed [7:0]  H = {2'b00, PADDLE_H};

    wire signed [7:0] by_i  = py[15:8];
    wire signed [7:0] p1_t  = {2'b00, p1_y};
    wire signed [7:0] p2_t  = {2'b00, p2_y};
    wire hit_p1_rows = (by_i + 8'sd1 >= p1_t) && (by_i <= p1_t + H - 8'sd1);
    wire hit_p2_rows = (by_i + 8'sd1 >= p2_t) && (by_i <= p2_t + H - 8'sd1);

    wire signed [17:0] vx = going_right ? $signed({6'd0, speed}) : -$signed({6'd0, speed});

    // vy = slope*speed/16, computed on magnitude then signed, so +s and -s are exact mirrors
    wire [4:0]  aslope = slope[4] ? (~slope + 5'd1) : slope;
    wire [15:0] vmag   = aslope * speed;
    wire signed [15:0] vy_mag = {4'd0, vmag[15:4]};
    wire signed [15:0] vy = slope[4] ? -vy_mag : vy_mag;

    reg signed [17:0] nx;
    reg signed [15:0] ny;
    reg nright;
    reg [11:0] nspeed, nbase;

    // hit offset in half-pixels: ball centre minus paddle centre, range -H..+H
    wire signed [15:0] by16 = {{8{by_i[7]}}, by_i};
    wire signed [15:0] t1_16 = {{8{p1_t[7]}}, p1_t};
    wire signed [15:0] t2_16 = {{8{p2_t[7]}}, p2_t};
    wire signed [15:0] H16 = {8'd0, H};
    wire signed [15:0] off1 = (by16 <<< 1) + 16'sd2 - (t1_16 <<< 1) - H16;
    wire signed [15:0] off2 = (by16 <<< 1) + 16'sd2 - (t2_16 <<< 1) - H16;

    // a normal return steps up from the rally speed (not from a decaying smash speed)
    wire [11:0] hit_speed = (base + SPEED_INC > SPEED_MAX) ? SPEED_MAX : base + SPEED_INC;

    // smash: normal return plus SMASH_BOOST, angle doubled (floor SMASH_MIN, clamp +-15)
    wire [11:0] smash_speed = hit_speed + SMASH_BOOST;
    wire signed [15:0] d1 = off1 <<< 1;
    wire signed [15:0] d2 = off2 <<< 1;
    wire signed [15:0] sm_off1 = (d1 >= 16'sd15) ? 16'sd15 : (d1 <= -16'sd15) ? -16'sd15 :
                                 (d1 >= SMASH_MIN) ? d1 : (d1 <= -SMASH_MIN) ? d1 :
                                 (d1 > 0) ? SMASH_MIN : (d1 < 0) ? -SMASH_MIN : (lfsr[0] ? SMASH_MIN : -SMASH_MIN);
    wire signed [15:0] sm_off2 = (d2 >= 16'sd15) ? 16'sd15 : (d2 <= -16'sd15) ? -16'sd15 :
                                 (d2 >= SMASH_MIN) ? d2 : (d2 <= -SMASH_MIN) ? d2 :
                                 (d2 > 0) ? SMASH_MIN : (d2 < 0) ? -SMASH_MIN : (lfsr[0] ? SMASH_MIN : -SMASH_MIN);

    // serve: offset -4..+3 from the LFSR
    wire signed [15:0] soff = {13'd0, lfsr[2:0]} - 16'sd4;

    always @* begin
        nx = px + vx;
        ny = py + vy;
        nright = going_right;
        nspeed = speed;
        nbase = base;
        nslope = slope;
        wall_hit = 1'b0;
        paddle_hit = 1'b0;
        hit1 = 1'b0; hit2 = 1'b0; smash1 = 1'b0; smash2 = 1'b0;

        // after a smash the speed sheds SMASH_DECAY per frame until it is back at the rally speed
        if (speed > base)
            nspeed = (speed - base <= SMASH_DECAY) ? base : speed - SMASH_DECAY;

        // walls: mirror the overshoot instead of clamping
        if (ny < 0) begin
            wall_hit = 1'b1;
            ny = -ny;
            nslope = -slope;
        end else if (ny > BOT) begin
            wall_hit = 1'b1;
            ny = 2*BOT - ny;
            nslope = -slope;
        end

        // left paddle
        if (!going_right && px >= LFACE && nx < LFACE && hit_p1_rows) begin
            nx = 2*LFACE - nx;
            paddle_hit = 1'b1;
            hit1 = 1'b1;
            nright = 1'b1;
            nbase = hit_speed;
            if (p1_armed) begin
                smash1 = 1'b1;
                nspeed = smash_speed;
                nslope = sm_off1[4:0];
            end else begin
                nspeed = hit_speed;
                nslope = off1[4:0];
            end
        end

        // right paddle
        if (going_right && px <= RFACE && nx > RFACE && hit_p2_rows) begin
            nx = 2*RFACE - nx;
            paddle_hit = 1'b1;
            hit2 = 1'b1;
            nright = 1'b0;
            nbase = hit_speed;
            if (p2_armed) begin
                smash2 = 1'b1;
                nspeed = smash_speed;
                nslope = sm_off2[4:0];
            end else begin
                nspeed = hit_speed;
                nslope = off2[4:0];
            end
        end
    end

    wire missed_left  = (nx <= LMISS);
    wire missed_right = (nx >= RMISS);
    wire step_now = frame_tick && !halt && (serve_cnt == 0);

    always @(posedge clk or posedge srst) begin
        if (srst) begin
            px <= CENTER_X;
            py <= CENTER_Y;
            slope <= 5'sd3;
            speed <= SPEED0;
            base <= SPEED0;
            going_right <= 1'b1;
            lfsr <= 8'hA5;
            serve_cnt <= SERVE_DELAY;
            p1_point <= 0;
            p2_point <= 0;
            ev_wall <= 0;
            ev_paddle <= 0;
            hit_p1 <= 0; 
            hit_p2 <= 0; 
            smash_p1 <= 0; 
            smash_p2 <= 0;
        end else begin
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};

            p1_point <= 0;
            p2_point <= 0;
            ev_wall <= 0;
            ev_paddle <= 0;
            hit_p1 <= 0; 
            hit_p2 <= 0; 
            smash_p1 <= 0; 
            smash_p2 <= 0;

            if (frame_tick && !halt && serve_cnt > 0) begin
                serve_cnt <= serve_cnt - 1;
            end

            if (step_now) begin
                if (missed_left || missed_right) begin
                    p2_point <= missed_left;
                    p1_point <= missed_right;
                    px <= CENTER_X;
                    py <= CENTER_Y;
                    speed <= SPEED0;
                    base <= SPEED0;
                    going_right <= missed_left ? 1'b0 : 1'b1;
                    slope <= soff[4:0];
                    serve_cnt <= SERVE_DELAY;
                end else begin
                    ev_wall <= wall_hit;
                    ev_paddle <= paddle_hit;
                    hit_p1 <= hit1; 
                    hit_p2 <= hit2;
                    smash_p1 <= smash1; 
                    smash_p2 <= smash2;
                    px <= nx;
                    py <= ny;
                    slope <= nslope;
                    going_right <= nright;
                    speed <= nspeed;
                    base <= nbase;
                end
            end
        end
    end
endmodule