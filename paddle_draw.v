// paddle_draw.v
// High while the pixel being scanned (hsync, vsync) is inside the paddle
// rectangle. Purely combinational.
module paddle_draw #(
    parameter [5:0] WIDTH  = 6'd2,
    parameter [5:0] HEIGHT = 6'd10
) (
    input  wire [5:0] hsync,
    input  wire [5:0] vsync,
    input  wire [5:0] x_coord,
    input  wire [5:0] y_coord,
    output wire       vout
);

    wire in_x = ({1'b0, hsync} >= {1'b0, x_coord}) &&
                ({1'b0, hsync} <  {1'b0, x_coord} + {1'b0, WIDTH});
    wire in_y = ({1'b0, vsync} >= {1'b0, y_coord}) &&
                ({1'b0, vsync} <  {1'b0, y_coord} + {1'b0, HEIGHT});

    assign vout = in_x && in_y;

endmodule