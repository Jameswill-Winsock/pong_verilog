// music.v
// three square-wave voices read from music_rom.v (made by make_music.py)
// a rom entry is {len[7:0], div[15:0]}: play a note whose half-period is div clocks (0 = rest) for len ticks
// len = 0 marks the end of the track, then it loops. a tick is TICK_FRAMES frames.
// the output is the number of voices that are high (0..3), so sim_main can add them up as a proper mix
module music #(
    parameter integer TICK_FRAMES = 4
) (
    input  wire clk, srst, frame_tick,
    input  wire en,                  // 0 = silent and restart from the top
    output wire [1:0] level
);
    localparam integer AW = 10;

    wire [23:0] d0, d1, d2;
    reg  [AW-1:0] a0, a1, a2;
    music_rom0 u_r0(.addr(a0), .data(d0));
    music_rom1 u_r1(.addr(a1), .data(d1));
    music_rom2 u_r2(.addr(a2), .data(d2));

    reg [2:0] fcnt;
    wire tick = frame_tick && (fcnt == TICK_FRAMES - 1);

    reg [15:0] div0, div1, div2, c0, c1, c2;
    reg [7:0]  rem0, rem1, rem2;
    reg        o0, o1, o2;

    always @(posedge clk or posedge srst) begin
        if (srst || !en) begin
            fcnt <= 3'd0;
            a0 <= 0; a1 <= 0; a2 <= 0;
            div0 <= 16'd0; div1 <= 16'd0; div2 <= 16'd0;
            rem0 <= 8'd0; rem1 <= 8'd0; rem2 <= 8'd0;
            c0 <= 16'd0; c1 <= 16'd0; c2 <= 16'd0;
            o0 <= 1'b0; o1 <= 1'b0; o2 <= 1'b0;
        end else begin
            if (frame_tick) fcnt <= (fcnt == TICK_FRAMES - 1) ? 3'd0 : fcnt + 3'd1;

            // note sequencing, once per tick. rem == 0 means "load the next entry"
            if (tick) begin
                if (rem0 <= 8'd1) begin
                    if (d0[23:16] == 8'd0) begin a0 <= 0; rem0 <= 8'd1; div0 <= 16'd0; end   // loop (one tick of rest)
                    else begin a0 <= a0 + 1'b1; rem0 <= d0[23:16]; div0 <= d0[15:0]; end
                end else rem0 <= rem0 - 8'd1;

                if (rem1 <= 8'd1) begin
                    if (d1[23:16] == 8'd0) begin a1 <= 0; rem1 <= 8'd1; div1 <= 16'd0; end
                    else begin a1 <= a1 + 1'b1; rem1 <= d1[23:16]; div1 <= d1[15:0]; end
                end else rem1 <= rem1 - 8'd1;

                if (rem2 <= 8'd1) begin
                    if (d2[23:16] == 8'd0) begin a2 <= 0; rem2 <= 8'd1; div2 <= 16'd0; end
                    else begin a2 <= a2 + 1'b1; rem2 <= d2[23:16]; div2 <= d2[15:0]; end
                end else rem2 <= rem2 - 8'd1;
            end

            // square wave dividers
            if (div0 == 16'd0) begin c0 <= 16'd0; o0 <= 1'b0; end
            else if (c0 + 16'd1 >= div0) begin c0 <= 16'd0; o0 <= ~o0; end
            else c0 <= c0 + 16'd1;

            if (div1 == 16'd0) begin c1 <= 16'd0; o1 <= 1'b0; end
            else if (c1 + 16'd1 >= div1) begin c1 <= 16'd0; o1 <= ~o1; end
            else c1 <= c1 + 16'd1;

            if (div2 == 16'd0) begin c2 <= 16'd0; o2 <= 1'b0; end
            else if (c2 + 16'd1 >= div2) begin c2 <= 16'd0; o2 <= ~o2; end
            else c2 <= c2 + 16'd1;
        end
    end

    assign level = {1'b0, o0} + {1'b0, o1} + {1'b0, o2};
endmodule