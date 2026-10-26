// meter_draw.v 
// three vertical pips for one player's smash meter, drawn on the screen edge.
// level: 0 = off, 6 = charging, 9/15 blink when full, 15 solid when armed
module meter_draw #(
    parameter [6:0] X0 = 7'd0,          // left column of the 2-px wide bar
    parameter [5:0] Y0 = 6'd21          // top of the first pip
) (
    input  wire [6:0] hsync,
    input  wire [5:0] vsync,
    input  wire [1:0] meter,
    input  wire armed, blink,
    output wire [3:0] level
);
    wire in_x = (hsync == X0) || (hsync == X0 + 7'd1);
    wire [6:0] ry = {1'b0, vsync} - {1'b0, Y0};
    wire in_band = ({1'b0, vsync} >= {1'b0, Y0}) && (ry < 7'd22);
    // each pip is 6 rows tall with a 2-row gap: rows 0-5, 8-13, 16-21
    wire [2:0] pip_row = ry[2:0];
    wire [1:0] pip_idx = ry[4:3];
    wire in_pip = in_band && (pip_row < 3'd6) && (pip_idx < 2'd3);
    // pip 0 is the bottom one so the bar fills upwards
    wire [1:0] pip_from_bottom = 2'd2 - pip_idx;
    wire lit = (meter > pip_from_bottom);
    wire full = (meter == 2'd3);
    wire [3:0] on_level = armed ? 4'd15 : (full ? (blink ? 4'd15 : 4'd9) : 4'd6);
    assign level = (in_x && in_pip && lit) ? on_level : 4'd0;
endmodule