`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/19/2026 11:44:20 AM
// Design Name: 
// Module Name: master_clock
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


module master_mic #(
    parameter int MIC_COUNT = 30,
    parameter int MIC_HZ = 2_000_000,
    parameter int CLK_HZ = 100_000_000,
    parameter int DECIMATION_FACTOR = 32
)(
    output logic signed [17:0] audio [MIC_COUNT-1:0],
    output logic               mic_clk,
    output logic               audio_ready,
    input  logic               data [MIC_COUNT/2-1:0],
    input  logic               clk,
    input  logic               rst
);

logic enable1, enable2;
logic decimate;
logic [$clog2(DECIMATION_FACTOR)-1:0] decimation_ctr;
logic [$clog2(CLK_HZ/MIC_HZ)-1:0] divider_ctr;

logic sync1[MIC_COUNT/2-1:0];
logic sync2[MIC_COUNT/2-1:0];



generate
    genvar i;
    for(i = 0; i< MIC_COUNT/2; i++) begin : mic_pair
        CIC #(
            .DECIMATION_FACTOR (DECIMATION_FACTOR)
        ) mic1 (
        .audio (audio[2*i]),
        .PDM    (sync2[i]),
        .enable  (enable1),
        .clk     (clk),
        .rst (rst),
        .decimate (decimate)
        );

        CIC #(
            .DECIMATION_FACTOR (DECIMATION_FACTOR)
        ) mic2 (
        .audio (audio[2*i+1]),
        .PDM    (sync2[i]),
        .enable  (enable2),
        .clk     (clk),
        .rst (rst),
        .decimate (decimate)
        );
    end : mic_pair
endgenerate

always_ff @(posedge clk, posedge rst) begin
    if(rst) begin
        for(int i=0; i<MIC_COUNT/2; i++) begin
            sync2[i] <= 0;
            sync1[i] <= 0;
        end
    end
    else begin
        for(int i=0; i<MIC_COUNT/2; i++) begin
            sync2[i] <= sync1[i];
            sync1[i] <= data[i];
        end
    end
end


//even mics get sampled first
always_ff @(posedge clk, posedge rst) begin
    if(rst) begin
        divider_ctr <= 0;
        decimation_ctr <= 0;
        audio_ready <= 0;
        mic_clk <= 0;
    end
    else if(divider_ctr == (CLK_HZ/MIC_HZ/2-1)) begin
        mic_clk <= 1;
        divider_ctr <= divider_ctr + 1;
        audio_ready <= 0;
    end
    else if(divider_ctr == (CLK_HZ/MIC_HZ-1)) begin
        mic_clk <= 0;
        divider_ctr <= 0;

        if(decimation_ctr == DECIMATION_FACTOR-1) begin
                audio_ready <= 1;
                decimation_ctr <= 0;
        end
        else begin
            decimation_ctr <= decimation_ctr + 1;
            audio_ready <= 0;
        end
    end
    else begin
        divider_ctr <= divider_ctr + 1;
        audio_ready <= 0;
    end
end

assign enable1 = (divider_ctr == (CLK_HZ/MIC_HZ/2-1));
assign enable2 = (divider_ctr == (CLK_HZ/MIC_HZ-1));
assign decimate = (decimation_ctr == DECIMATION_FACTOR-1);

endmodule
