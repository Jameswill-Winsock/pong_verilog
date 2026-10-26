module top(
    input wire clk,
    input wire srst,        // active high system reset
    input wire p1_up,
    input wire p1_down,
    input wire p2_up,
    input wire p2_down,
    input wire ai1_en,          // 1 = computer drives P1
    input wire ai2_en,          // 1 = computer drives P2
    input wire [1:0] ai1_diff,  // 0 easy 3 insane
    input wire [1:0] ai2_diff,
    input wire p1_smash,        // smash buttons (rising edge arms a full meter)
    input wire p2_smash,
    input wire music_en,        // background soundtrack on/off (off also rewinds it)

    // vid ram write port
    output wire vid_clk,
    output wire vid_we,
    output wire [6:0] vid_x,
    output wire [5:0] vid_y,
    output wire [3:0] vid_data,

    // status
    output wire [3:0] p1_score,
    output wire p1_ten,
    output wire [3:0] p2_score,
    output wire p2_ten,
    output wire game_over,
    output wire [6:0] ball_x,
    output wire [5:0] ball_y,
    output wire [5:0] p1_y,
    output wire [5:0] p2_y,
    output wire beep,           // 1-bit beeper line (sound effects)
    output wire [1:0] music,    // soundtrack: how many of the 3 voices are high
    output wire [1:0] p1_meter, // smash charge 0..3
    output wire [1:0] p2_meter,
    output wire p1_armed,
    output wire p2_armed,
    output wire ev_smash        // pulse on a smash hit
);

localparam [5:0] PADDLE_H = 6'd10;
localparam [5:0] PADDLE_W = 6'd2;
localparam [6:0] P1_X = 7'd2;
localparam [6:0] P2_X = 7'd124;

wire [6:0] hsync;
wire [5:0] vsync;
wire net_pixel;
wire p1_point, p2_point;
wire ev_wall, ev_paddle;
wire [6:0] p1_x, p2_x;
wire p1_pixel, p2_pixel, ball_pixel, score_pixel;

// one pulse per frame, on the last pixel
wire frame_tick = (hsync == 7'd127) && (vsync == 6'd63);

// scan counters + center net
netdraw u_netdraw (
    .clk(clk),
    .srst(srst),
    .hsync(hsync),
    .vsync(vsync),
    .net_out(net_pixel)
);

wire ball_right;
wire signed [4:0] ball_slope;
wire [11:0] ball_speed;
wire hit_p1, hit_p2, smash_p1, smash_p2;
wire ai1_sm, ai2_sm;

// computer opponents (same up/down interface a human uses, so they are equally limited by paddle speed)
wire ai1_up, ai1_dn, ai2_up, ai2_dn;

ai_paddle #(
    .FACE_X(7'd4),  
    .LEFT(1), 
    .H(PADDLE_H), 
    .SEED(8'h5A)
) u_ai1(
    .clk(clk), 
    .srst(srst), 
    .frame_tick(frame_tick), 
    .diff(ai1_diff),
    .ball_x(ball_x), 
    .ball_y(ball_y), 
    .ball_right(ball_right), 
    .ball_slope(ball_slope),
    .ball_speed(ball_speed),
    .my_y(p1_y), 
    .opp_y(p2_y), 
    .up(ai1_up), 
    .down(ai1_dn),
    .smash(ai1_sm)
);

ai_paddle #(
    .FACE_X(7'd122),
    .LEFT(0), 
    .H(PADDLE_H), 
    .SEED(8'hC3)
) u_ai2(
    .clk(clk), 
    .srst(srst), 
    .frame_tick(frame_tick), 
    .diff(ai2_diff),
    .ball_x(ball_x), 
    .ball_y(ball_y), 
    .ball_right(ball_right), 
    .ball_slope(ball_slope),
    .ball_speed(ball_speed),
    .my_y(p2_y), 
    .opp_y(p1_y), 
    .up(ai2_up), 
    .down(ai2_dn),
    .smash(ai2_sm)
);

wire p1_u = ai1_en ? ai1_up : p1_up;
wire p1_d = ai1_en ? ai1_dn : p1_down;
wire p2_u = ai2_en ? ai2_up : p2_up;
wire p2_d = ai2_en ? ai2_dn : p2_down;
wire p1_sm_btn = ai1_en ? ai1_sm : p1_smash;
wire p2_sm_btn = ai2_en ? ai2_sm : p2_smash;

// paddles
paddle_logic #(
    .X(P1_X),
    .HEIGHT(PADDLE_H)
) u_paddle1(
    .clk(clk),
    .srst(srst),
    .frame_tick(frame_tick),
    .up(p1_u),
    .down(p1_d),
    .x_coord(p1_x),
    .y_coord(p1_y)
);

paddle_logic #(
    .X(P2_X),
    .HEIGHT(PADDLE_H)
) u_paddle2(
    .clk(clk),
    .srst(srst),
    .frame_tick(frame_tick),
    .up(p2_u),
    .down(p2_d),
    .x_coord(p2_x),
    .y_coord(p2_y)
);

paddle_draw #(
    .WIDTH(PADDLE_W), 
    .HEIGHT(PADDLE_H)
) u_paddle1_draw(
    .hsync(hsync), 
    .vsync(vsync), 
    .x_coord(p1_x), 
    .y_coord(p1_y), 
    .vout(p1_pixel)
);

paddle_draw #(
    .WIDTH(PADDLE_W), 
    .HEIGHT(PADDLE_H)
) u_paddle2_draw(
    .hsync(hsync), 
    .vsync(vsync), 
    .x_coord(p2_x), 
    .y_coord(p2_y), 
    .vout(p2_pixel)
);

// balls
ball_logic #(
    .P1_X(P1_X),
    .P2_X(P2_X),
    .PADDLE_H(PADDLE_H)
) u_ball(
    .clk(clk),
    .srst(srst),
    .frame_tick(frame_tick),
    .halt(game_over),
    .p1_armed(p1_armed),
    .p2_armed(p2_armed),
    .p1_y(p1_y),
    .p2_y(p2_y),
    .ball_x(ball_x),
    .ball_y(ball_y),
    .ball_right(ball_right),
    .ball_slope(ball_slope),
    .p1_point(p1_point),
    .p2_point(p2_point),
    .ev_wall(ev_wall),
    .ev_paddle(ev_paddle),
    .ball_speed(ball_speed),
    .hit_p1(hit_p1),
    .hit_p2(hit_p2),
    .smash_p1(smash_p1),
    .smash_p2(smash_p2)
);

assign ev_smash = smash_p1 | smash_p2;

// rally smash meters
smash_ctrl u_smash1(
    .clk(clk), 
    .srst(srst), 
    .frame_tick(frame_tick),
    .btn(p1_sm_btn), 
    .hit(hit_p1), 
    .smashed(smash_p1), 
    .point(p1_point | p2_point),
    .meter(p1_meter), 
    .armed(p1_armed)
);
smash_ctrl u_smash2(
    .clk(clk), 
    .srst(srst), 
    .frame_tick(frame_tick),
    .btn(p2_sm_btn), 
    .hit(hit_p2), 
    .smashed(smash_p2), 
    .point(p1_point | p2_point),
    .meter(p2_meter), 
    .armed(p2_armed)
);

reg [4:0] frame_cnt;
always @(posedge clk or posedge srst) begin
    if (srst) begin 
        frame_cnt <= 5'd0; 
    end
    else if (frame_tick) begin 
        frame_cnt <= frame_cnt + 5'd1; 
    end
end
wire blink = frame_cnt[2];

wire [3:0] m1_level, m2_level;
meter_draw #(
    .X0(7'd0)
)  u_m1(
    .hsync(hsync), 
    .vsync(vsync), 
    .meter(p1_meter), 
    .armed(p1_armed), 
    .blink(blink), 
    .level(m1_level)
);
meter_draw #(
    .X0(7'd126)
) u_m2(
    .hsync(hsync), 
    .vsync(vsync), 
    .meter(p2_meter), 
    .armed(p2_armed), 
    .blink(blink), 
    .level(m2_level)
);

wire ball_in_x = (hsync == ball_x) || (hsync == ball_x + 7'd1);
wire ball_in_y = (vsync == ball_y) || (vsync == ball_y + 6'd1);
assign ball_pixel = ball_in_x && ball_in_y;

// score counter, l/r low selects which player scores on a miss pulse
// run is held low which keeps scoring enabled
// stop_g output ends game when someone reaches 10

wire stop_g, attract_n_unused;  // i will deal with it later (meaning never lmfao)
score_counter u_score (
    .srst(srst),
    .l(~p1_point),
    .r(~p2_point),
    .miss(p1_point | p2_point),
    .run(1'b0),
    .p1_score(p1_score),
    .p1_ten(p1_ten),
    .p2_score(p2_score),
    .p2_ten(p2_ten),
    .stop_g(stop_g),
    .attract_n(attract_n_unused)
);
assign game_over = stop_g;

// sound
reg go_q;
always @(posedge clk or posedge srst) begin
    if (srst) begin 
        go_q <= 1'b0; 
    end
    else begin 
        go_q <= game_over; 
    end
end

beeper u_beeper(
    .clk(clk), 
    .srst(srst), 
    .frame_tick(frame_tick),
    .ev_wall(ev_wall), 
    .ev_paddle(ev_paddle),
    .ev_smash(ev_smash),
    .ev_point(p1_point | p2_point),
    .ev_over(game_over & ~go_q),
    .beep(beep)
);

music u_music(
    .clk(clk),
    .srst(srst),
    .frame_tick(frame_tick),
    .en(music_en),
    .level(music)
);

score_display u_score_display(
    .hsync(hsync),
    .vsync(vsync),
    .p1_score(p1_score),
    .p1_ten(p1_ten),
    .p2_score(p2_score),
    .p2_ten(p2_ten),
    .pixel(score_pixel)
);

// vid out
wire bright = p1_pixel | p2_pixel | ball_pixel | score_pixel;
wire dim = net_pixel & ~vsync[2];       // dashed centre net line

assign vid_clk = clk;

// look i left this option, in case i wanted to do display that does only updation based screen change
// instead of refreshing whole screen every pulse, like classic pong with crt on 59.94 hz ntsc (even though its b&w still its 59.94 technically)
// which is what i currently do
assign vid_we = 1'b1;   

assign vid_x = hsync;
assign vid_y = vsync;
wire [3:0] meter_level = (m1_level > m2_level) ? m1_level : m2_level;
assign vid_data = bright ? 4'd15 : (meter_level != 4'd0) ? meter_level : (dim ? 4'd5 : 4'd0);

endmodule