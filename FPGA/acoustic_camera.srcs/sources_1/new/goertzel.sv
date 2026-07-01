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

    logic [31:0] re, img;
    logic signed [63:0] c1, c2, s2;
    logic signed [31:0] s1_fetch, s2_fetch;



    enum logic [2:0] {waiting, active1, active2, shifting, writing1, writing2, writing3} state;

    always_ff @(posedge clk or negedge n_reset) begin
        if (!n_reset) begin
            ctr <= '0;
            mic_ctr <= '0;
            state <= waiting;
            goertzel_valid <= 0;
            cos_s1_product <= '0;
            cos_s2_product <= '0;
            sin_s2_product <= '0;
            s1_fetch <= '0;
            s2_fetch <= '0;
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
                        state <= active1;
                end
                active1: begin
                    s1_fetch <= s_1[mic_ctr];
                    state <= active2;
                end
                active2: begin
                    cos_s1_product <= s1_fetch * COS_w;
                    state <= shifting;
                end
                shifting: begin
                    s_2[mic_ctr] <= s_1[mic_ctr];
                    s_1[mic_ctr] <= audio[mic_ctr] + c1 - s_2[mic_ctr];
                    if(mic_ctr == MIC_COUNT-1) begin
                        mic_ctr <= 0;
                        if(ctr == N-1) begin
                            ctr <= 0;
                            state <= writing1;
                        end
                        else begin
                            ctr <= ctr + 1;
                            state <= waiting;
                        end
                    end
                    else begin
                        mic_ctr <= mic_ctr + 1;
                        state <= active1;
                    end
                end
                writing1: begin
                    s2_fetch <= s_2[mic_ctr];
                    state <= writing2;
                end
                writing2: begin
                    cos_s2_product <= s2_fetch * COS_w;
                    sin_s2_product <= s2_fetch * SIN_w;
                    state <= writing3;
                end
                writing3: begin
                    R[mic_ctr] <= re;
                    I[mic_ctr] <= img;
                    s_1[mic_ctr] <= '0;
                    s_2[mic_ctr] <= '0;
                    if(mic_ctr == MIC_COUNT-1) begin
                        goertzel_valid <= 1;
                        state <= waiting;
                        mic_ctr <= 0;
                    end
                    else begin
                        goertzel_valid <= 0;
                        mic_ctr <= mic_ctr + 1;
                        state <= writing1;
                    end
                end
            endcase
        end
    end



always_comb begin
    c1 = (cos_s1_product >>> 30);
    c2 = (cos_s2_product >>> 31);
    s2 = (sin_s2_product >>> 31);

    re = (s_1[mic_ctr] - c2) >>> 8;
    img = s2 >>> 8;
end

endmodule