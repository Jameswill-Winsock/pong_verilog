module top(
    input wire clk,
    input wire srst,        // active high system reset
    input wire p1_up,
    input wire p1_down,
    input wire p2_up,
    input wire p2_down,

    // vid ram write port
    output wire vid_clk,
    output wire vid_we,
    output wire [5:0] vid_x,
    output wire [5:0] vid_y,
    output wire [3:0] vid_data,

    // status
    output wire [3:0] p1_score,
    output wire p1_ten,
    output wire [3:0] p2_score,
    output wire p2_ten,
    output wire game_over,
    output wire [5:0] ball_x,
    output wire [5:0] ball_y,
    output wire [5:0] p1_y,
    output wire [5:0] p2_y
);

localparam [5:0] PADDLE_H = 6'd10;
localparam [5:0] PADDLE_W = 6'd2;
localparam [5:0] P1_X = 6'd2;
localparam [5:0] P2_X = 6'd60;

wire [5:0] hsync, vsync;
wire net_pixel;
wire p1_point, p2_point;
wire [5:0] p1_x, p2_x;
wire p1_pixel, p2_pixel, ball_pixel, score_pixel;

// one pulse per frame, on the last pixel
wire frame_tick = (hsync == 6'd63) && (vsync == 6'd63);

// scan counters + center net
netdraw u_netdraw (
    .clk(clk),
    .srst(srst),
    .hsync(hsync),
    .vsync(vsync),
    .net_out(net_pixel)
);

// paddles
paddle_logic #(
    .X(P1_X),
    .HEIGHT(PADDLE_H)
) u_paddle1(
    .clk(clk),
    .srst(srst),
    .frame_tick(frame_tick),
    .up(p1_up),
    .down(p1_down),
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
    .up(p2_up),
    .down(p2_down),
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
    .p1_y(p1_y),
    .p2_y(p2_y),
    .ball_x(ball_x),
    .ball_y(ball_y),
    .p1_point(p1_point),
    .p2_point(p2_point)
);

wire ball_in_x = (hsync == ball_x) || (hsync == ball_x + 6'd1);
wire ball_in_y = (vsync == ball_y) || (vsync == ball_y + 6'd1);
assign ball_pixel = ball_in_x && ball_in_y;

// score counter, l/r low selects which player scores on a miss pulse
// run is held low which keeps scoring enabled
// stop_g output ends game when someone reaches 10

wire stop_g, attract_n_unused;  // i will deal with it later
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
assign vid_we = 1'b1;       // look i left this option in case i wanted to do display that does only updation based screen change instead of refreshing whole screen every pulse like classic pong with vga
assign vid_x = hsync;
assign vid_y = vsync;
assign vid_data = bright ? 4'd15 : (dim ? 4'd5 : 4'd0);

endmodule