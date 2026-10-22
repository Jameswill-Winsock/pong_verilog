module score_counter (
    input wire srst,
    input wire l,
    input wire r,
    input wire miss,
    input wire run,
    output reg [3:0] p1_score,
    output reg [3:0] p2_score,
    output reg p1_ten,
    output reg p2_ten,
    output wire stop_g,
    output wire attract_n
);

assign stop_g = p1_ten | p2_ten;
assign attract_n = stop_g | ~run;

wire score_en = miss & attract_n;
wire p1_pulse = score_en & ~l;
wire p2_pulse = score_en & ~r;

wire [3:0] p1_next = p1_score + 4'd1;
wire [3:0] p2_next = p2_score + 4'd1;

always @(posedge p1_pulse or posedge srst) begin
    if (srst) begin
        p1_score <= 4'd0;
        p1_ten <= 1'b0;
    end else begin
        p1_score <= p1_next;
        if ((p1_next[1]&p1_next[3]) & ~(p1_score[1] & p1_score[3])) begin
            p1_ten <= ~p1_ten;
        end
    end
end

always @(posedge p2_pulse or posedge srst) begin
    if (srst) begin
        p2_score <= 4'd0;
        p2_ten <= 1'b0;
    end else begin
        p2_score <= p2_next;
        if((p2_next[1]&p2_next[3]) & ~(p2_score[1]&p2_score[3])) begin
            p2_ten <= ~p2_ten;
        end
    end
end

endmodule