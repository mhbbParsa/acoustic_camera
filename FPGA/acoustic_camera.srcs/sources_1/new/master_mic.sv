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
    parameter MIC_COUNT = 30,
    parameter CLOCK_DIVIDER = 50,
    parameter DECIMATION_FACTOR = 32
)(
    output logic signed [17:0] audio [MIC_COUNT-1:0],
    output logic               mic_clk,
    output logic               audio_ready,
    input  logic               data [MIC_COUNT/2-1:0],
    input  logic               clk,
    input  logic               n_reset
);

logic enable1, enable2;
logic decimate;
logic [$clog2(DECIMATION_FACTOR)-1:0] decimation_ctr;
logic [$clog2(CLOCK_DIVIDER)-1:0] divider_ctr;

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
        .n_reset (n_reset),
        .decimate (decimate)
        );

        CIC #(
            .DECIMATION_FACTOR (DECIMATION_FACTOR)
        ) mic2 (
        .audio (audio[2*i+1]),
        .PDM    (sync2[i]),
        .enable  (enable2),
        .clk     (clk),
        .n_reset (n_reset),
        .decimate (decimate)
        );
    end : mic_pair
endgenerate

always_ff @(posedge clk, negedge n_reset) begin
    if(!n_reset) begin
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
always_ff @(posedge clk, negedge n_reset) begin
    if(!n_reset) begin
        divider_ctr <= 0;
        decimation_ctr <= 0;
        audio_ready <= 0;
        mic_clk <= 0;
    end
    else if(divider_ctr == (CLOCK_DIVIDER/2-1)) begin
        mic_clk <= 1;
        divider_ctr <= divider_ctr + 1;
        audio_ready <= 0;
    end
    else if(divider_ctr == (CLOCK_DIVIDER-1)) begin
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

assign enable1 = (divider_ctr == (CLOCK_DIVIDER/2-1));
assign enable2 = (divider_ctr == (CLOCK_DIVIDER-1));
assign decimate = (decimation_ctr == DECIMATION_FACTOR-1);

endmodule
