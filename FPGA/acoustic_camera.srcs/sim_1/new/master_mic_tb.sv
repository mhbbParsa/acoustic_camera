`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/24/2026 08:22:15 PM
// Design Name: 
// Module Name: master_mic_tb
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

module master_mic_tb;

    localparam MIC_COUNT = 2;
    localparam CLOCK_DIVIDER = 4;

    logic signed [17:0] audio [MIC_COUNT-1:0];
    logic mic_clk;
    logic audio_ready;
    logic data [MIC_COUNT/2-1:0];
    logic clk;
    logic rst;

    master_mic #(
        .MIC_COUNT(MIC_COUNT),
        .CLOCK_DIVIDER(CLOCK_DIVIDER)
    ) dut (
        .audio(audio),
        .mic_clk(mic_clk),
        .audio_ready(audio_ready),
        .data(data),
        .clk(clk),
        .rst(rst)
    );
    


    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1;
        data[0] = 0;

        repeat (10) @(posedge clk);
        rst = 0;

        repeat (5000) begin
            #500000
            data[0] <= !data[0];
        end       
    end

endmodule