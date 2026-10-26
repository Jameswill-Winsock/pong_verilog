module netdraw (
    input wire clk,
    input wire srst,
    output reg [6:0] hsync,
    output reg [5:0] vsync,
    output wire net_out
);

always @(posedge clk or posedge srst) begin
    if (srst) begin 
        hsync <= 7'd0;
    end else begin 
        hsync <= hsync + 7'd1;
    end
end

always @(posedge clk or posedge srst) begin
    if (srst) begin
        vsync <= 6'd0;
    end else if (hsync == 7'd127) begin
        vsync <= vsync + 6'd1;
    end
end

assign net_out = (hsync == 7'd64);

endmodule