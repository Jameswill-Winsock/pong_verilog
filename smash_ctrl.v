// smash_ctrl.v
// per-player rally-smash state: a charge meter and an arming window.
//   * every normal paddle hit of mine charges the meter by one, up to METER_MAX
//   * with a full meter, a button press (rising edge) arms the smash for ARM_FRAMES frames
//   * if the ball is hit while armed it becomes a smash (ball_logic does that) and the meter empties
//   * if the window runs out with no hit, the charge is wasted -> meter empties (the risk of mistiming)
//   * a point (either way) resets everything: you build the smash during a rally
module smash_ctrl #(
    parameter [1:0] METER_MAX  = 2'd3,
    parameter [3:0] ARM_FRAMES = 4'd10
) (
    input  wire clk, srst, frame_tick,
    input  wire btn,        // raw smash button
    input  wire hit,        // my paddle returned the ball (pulse)
    input  wire smashed,    // that hit was a smash (pulse, comes with hit)
    input  wire point,      // somebody scored (pulse)
    output reg  [1:0] meter,
    output wire armed
);
    reg [3:0] arm_cnt;
    reg btn_q;
    assign armed = (arm_cnt != 4'd0);

    always @(posedge clk or posedge srst) begin
        if (srst) begin
            meter <= 2'd0; arm_cnt <= 4'd0; btn_q <= 1'b0;
        end else begin
            btn_q <= btn;
            if (point) begin
                meter <= 2'd0; arm_cnt <= 4'd0;
            end else if (smashed) begin
                meter <= 2'd0; arm_cnt <= 4'd0;
            end else if (hit) begin
                if (meter != METER_MAX) meter <= meter + 2'd1;
            end else begin
                if (btn && !btn_q && meter == METER_MAX && arm_cnt == 4'd0) begin
                    arm_cnt <= ARM_FRAMES;
                end else if (frame_tick && arm_cnt != 4'd0) begin
                    arm_cnt <= arm_cnt - 4'd1;
                    if (arm_cnt == 4'd1) meter <= 2'd0;      // whiff
                end
            end
        end
    end
endmodule