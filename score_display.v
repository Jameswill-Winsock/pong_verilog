module score_display(
    input wire [6:0] hsync,
    input wire [5:0] vsync,
    input wire [3:0] p1_score,
    input wire p1_ten,
    input wire [3:0] p2_score,
    input wire p2_ten,
    output wire pixel
);

localparam [6:0] TOP_Y = 7'd3;
localparam [6:0] P1_TENS = 7'd42, P1_ONES = 7'd50;
localparam [6:0] P2_TENS = 7'd72, P2_ONES = 7'd80;

// 3x5 font, 15 bits per digit, row 0 first, leftmost column first
function [14:0] glyph(input [3:0] d);
    case (d)
        4'd0: glyph = 15'b111_101_101_101_111;
        4'd1: glyph = 15'b010_110_010_010_111;
        4'd2: glyph = 15'b111_001_111_100_111;
        4'd3: glyph = 15'b111_001_111_001_111;
        4'd4: glyph = 15'b101_101_111_001_001;
        4'd5: glyph = 15'b111_100_111_001_111;
        4'd6: glyph = 15'b111_100_111_101_111;
        4'd7: glyph = 15'b111_001_010_010_010;
        4'd8: glyph = 15'b111_101_111_101_111;
        4'd9: glyph = 15'b111_101_111_001_111;
        default: glyph = 15'b000_000_000_000_000;
    endcase
endfunction

// check if current pixel is lit by digit d drawn with its top-left at x0, top_y
function digit_on(input [3:0] d, input [6:0] x0);
    reg [7:0] lx;
    reg [6:0] ly;
    reg [3:0] col, row;
    reg [14:0] g;
    begin
        lx = {1'b0, hsync} - x0;
        ly = {1'b0, vsync} - TOP_Y;
        if ({1'b0, hsync} >= {1'b0, x0} && lx < 8'd6 && {1'b0, vsync} >= TOP_Y && ly < 7'd10) begin
            col = {2'b00, lx[2:1]};
            row = {1'b0, ly[3:1]};
            g = glyph(d);
            digit_on = g[14 - (row*3+col)];
        end else begin
            digit_on = 1'b0;
        end
    end
endfunction

wire [3:0] p1_ones = (p1_score >= 4'd10) ? p1_score - 4'd10 : p1_score;
wire [3:0] p2_ones = (p2_score >= 4'd10) ? p2_score - 4'd10 : p2_score;

assign pixel = digit_on(p1_ones, P1_ONES) | (p1_ten & digit_on(4'd1, P1_TENS)) | digit_on(p2_ones, P2_ONES) | (p2_ten & digit_on(4'd1, P2_TENS));

endmodule