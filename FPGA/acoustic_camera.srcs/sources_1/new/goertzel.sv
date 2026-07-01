`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/18/2026 11:20:43 PM
// Design Name: 
// Module Name: goertzel
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module goertzel #(
    parameter int N = 1000,
    parameter int MIC_COUNT = 30,
    parameter signed [31:0] COS_w = 32'hC97F276E,
    parameter signed [31:0] SIN_w = 32'h73D0D6F3
)(
    output logic signed [17:0] R [MIC_COUNT-1:0],
    output logic signed [17:0] I [MIC_COUNT-1:0],
    output logic               goertzel_valid,
    input  logic               clk,
    input  logic               enable_goertzel,
    input  logic               n_reset,
    input  logic signed [17:0] audio [MIC_COUNT-1:0]
);
    

    logic signed [31:0] s_1 [MIC_COUNT-1:0], s_2 [MIC_COUNT-1:0];
    logic signed [63:0] cos_s1_product, sin_s2_product, cos_s2_product;
    logic [$clog2(N+1)-1:0] ctr;
    logic [$clog2(MIC_COUNT)-1:0] mic_ctr;

    assign cos_s2_product = s_2[mic_ctr] * COS_w;
    assign sin_s2_product = s_2[mic_ctr] * SIN_w;


    enum logic [1:0] {waiting, active, active2} state;

    always_ff @(posedge clk or negedge n_reset) begin
        if (!n_reset) begin
            ctr <= '0;
            mic_ctr <= '0;
            state <= waiting;
            goertzel_valid <= 0;
            cos_s1_product <= '0;
            for(int i = 0; i < MIC_COUNT; i++) begin
                s_1[i] <= '0;
                s_2[i] <= '0;
            end
        end
        else begin
            case(state)
                waiting: begin
                    goertzel_valid <= 0;
                    mic_ctr <= 0;
                    if(enable_goertzel)
                        state <= active;
                end
                active: begin
                    if (ctr == N-1) begin
                            R[mic_ctr] <= re[25:8];
                            I[mic_ctr] <= img[25:8];
                            s_2[mic_ctr] <= 0;
                            s_1[mic_ctr] <= 0;
                            if(mic_ctr == MIC_COUNT-1) begin
                                goertzel_valid <= 1;
                                ctr <= 0;
                                state <= waiting;
                            end
                            else
                                mic_ctr <= mic_ctr + 1;
                    end
                    else begin
                        cos_s1_product <= s_1[mic_ctr] * COS_w;
                        state <= active2;
                    end
                end
                active2: begin
                    s_2[mic_ctr] <= s_1[mic_ctr];
                    s_1[mic_ctr] <= audio[mic_ctr] + (cos_s1_product >>> 30) - s_2[mic_ctr];
                    if(mic_ctr == MIC_COUNT-1) begin
                        ctr <= ctr + 1;
                        state <= waiting;
                    end
                    else begin
                        mic_ctr <= mic_ctr + 1;
                        state <= active;
                    end
                end
            endcase
        end
    end


logic [31:0] re, img;
always_comb begin
    re = (s_1[mic_ctr] - (cos_s2_product >>> 31));
    img = (sin_s2_product >>> 31);
end

endmodule