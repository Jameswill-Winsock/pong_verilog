// ball_logic.v
// The 2x2 ball: movement, wall/paddle bounces, and point detection.
//
// Everything advances on frame_tick (once per video frame). The left paddle
// occupies columns P1_X..P1_X+1, the right paddle P2_X..P2_X+1.
//   * Hitting the top/bottom edge flips the vertical direction.
//   * Hitting a paddle flips the horizontal direction; the part of the paddle
//     that was hit sets the new vertical direction (top = up, bottom = down,
//     middle = keep).
//   * Passing the left/right edge gives the other player a point (one-clock
//     p1_point / p2_point pulse), recentres the ball, and serves it back
//     toward the player who lost the point after a short delay.
module ball_logic #(
    parameter [5:0]   P1_X        = 6'd2,
    parameter [5:0]   P2_X        = 6'd60,
    parameter [5:0]   PADDLE_H    = 6'd10,
    parameter integer BALL_DIV    = 3,    // frames per ball step
    parameter integer SERVE_DELAY = 45    // frames to wait before serving
) (
    input  wire       clk,
    input  wire       srst,
    input  wire       frame_tick,
    input  wire       halt,           // game over: freeze the ball
    input  wire [5:0] p1_y,
    input  wire [5:0] p2_y,
    output wire [5:0] ball_x,
    output wire [5:0] ball_y,
    output reg        p1_point,       // right-hand player missed
    output reg        p2_point        // left-hand player missed
);

    // ---- state (signed so "off the edge" is easy to detect) -----------
    reg signed [7:0] bx, by;
    reg              going_right;
    reg signed [1:0] dy;                 // -1, 0, +1
    reg        [7:0] lfsr;               // cheap random bit for serves
    integer          div_cnt;
    integer          serve_cnt;

    assign ball_x = bx[5:0];
    assign ball_y = by[5:0];

    localparam signed [7:0] LEFT_FACE_X  = {2'b00, P1_X} + 8'sd2;  // ball x when touching P1
    localparam signed [7:0] RIGHT_FACE_X = {2'b00, P2_X} - 8'sd2;  // ball x when touching P2
    localparam signed [7:0] H            = {2'b00, PADDLE_H};

    // ---- one ball step, computed combinationally ----------------------
    reg signed [7:0] nx, ny;
    reg signed [1:0] ndy;
    reg              nright;
    reg signed [7:0] rel;                // ball row relative to the paddle top
    wire signed [7:0] dy8 = {{6{dy[1]}}, dy};   // dy sign-extended for arithmetic
    reg  signed [7:0] ndy8;
    wire signed [7:0] p1_top = {2'b00, p1_y};
    wire signed [7:0] p2_top = {2'b00, p2_y};

    wire hit_p1_rows = (by + 8'sd1 >= p1_top) && (by <= p1_top + H - 8'sd1);
    wire hit_p2_rows = (by + 8'sd1 >= p2_top) && (by <= p2_top + H - 8'sd1);

    always @* begin
        nright = going_right;
        ndy    = dy;
        nx     = going_right ? bx + 8'sd1 : bx - 8'sd1;
        rel    = 8'sd0;

        // top / bottom walls (the ball is 2 tall, rows 0..62)
        if ((by + dy8) < 8'sd0 || (by + dy8) > 8'sd62)
            ndy = -dy;

        // left paddle
        if (!going_right && bx >= LEFT_FACE_X && nx < LEFT_FACE_X && hit_p1_rows) begin
            nright = 1'b1;
            nx     = LEFT_FACE_X;
            rel    = by - p1_top;
            if      (rel <= 8'sd2)      ndy = -2'sd1;
            else if (rel >= H - 8'sd4)  ndy =  2'sd1;
        end

        // right paddle
        if (going_right && bx <= RIGHT_FACE_X && nx > RIGHT_FACE_X && hit_p2_rows) begin
            nright = 1'b0;
            nx     = RIGHT_FACE_X;
            rel    = by - p2_top;
            if      (rel <= 8'sd2)      ndy = -2'sd1;
            else if (rel >= H - 8'sd4)  ndy =  2'sd1;
        end

        ndy8 = {{6{ndy[1]}}, ndy};
        ny = by + ndy8;
        if (ny < 8'sd0)  ny = 8'sd0;
        if (ny > 8'sd62) ny = 8'sd62;
    end

    wire missed_left  = (nx <= 8'sd0);
    wire missed_right = (nx >= 8'sd62);

    // ---- state update --------------------------------------------------
    wire step_now = frame_tick && !halt && (serve_cnt == 0) && (div_cnt == BALL_DIV - 1);

    always @(posedge clk or posedge srst) begin
        if (srst) begin
            bx          <= 8'sd31;
            by          <= 8'sd31;
            going_right <= 1'b1;
            dy          <= 2'sd1;
            lfsr        <= 8'hA5;
            div_cnt     <= 0;
            serve_cnt   <= SERVE_DELAY;
            p1_point    <= 1'b0;
            p2_point    <= 1'b0;
        end else begin
            lfsr     <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
            p1_point <= 1'b0;
            p2_point <= 1'b0;

            if (frame_tick && !halt) begin
                if (serve_cnt > 0)
                    serve_cnt <= serve_cnt - 1;
                else if (div_cnt < BALL_DIV - 1)
                    div_cnt <= div_cnt + 1;
            end

            if (step_now) begin
                div_cnt <= 0;
                if (missed_left || missed_right) begin
                    p2_point    <= missed_left;
                    p1_point    <= missed_right;
                    bx          <= 8'sd31;          // recentre and wait to serve
                    by          <= 8'sd31;
                    going_right <= missed_left ? 1'b0 : 1'b1;   // serve toward the loser
                    dy          <= lfsr[0] ? 2'sd1 : -2'sd1;
                    serve_cnt   <= SERVE_DELAY;
                end else begin
                    bx          <= nx;
                    by          <= ny;
                    going_right <= nright;
                    dy          <= ndy;
                end
            end
        end
    end

endmodule