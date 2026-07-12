`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/29/2026 03:44:00 PM
// Design Name: 
// Module Name: acoustic_camera_tb
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

module acoustic_camera_tb;

    localparam int MIC_COUNT = 30;
    localparam int DECIMATION_FACTOR = 32;
    localparam int N = 1000;
    localparam signed [31:0] COS_w = 32'hC97F276E;
    localparam signed [31:0] SIN_w = 32'h73D0D6F3;
    localparam int CLK_HZ = 100_000_000;

    localparam int  TEST_FREQ         = 20000;

    logic clk = 0, rst = 0;
    logic [4:0] gain = 5'd4;
    logic zoom = 1; // 1 = 60deg, 0 = 180deg
    logic [13:0] temp_ctr;
    logic signal[14:0];
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            temp_ctr <= 0;
            for(int i = 0;i<15;i++)
                signal[i] <= 0;
        end
        else if(temp_ctr == (50000000/TEST_FREQ - 1)) begin
            temp_ctr <= temp_ctr + 1;
            for(int i = 0;i<15;i++)
                signal[i] <= 1;
        end
        else if(temp_ctr == (100000000/TEST_FREQ - 1)) begin
            temp_ctr <= 0;
            for(int i = 0;i<15;i++)
                signal[i] <= 0;
        end
        else begin
            temp_ctr <= temp_ctr + 1;
        end
    end

    acoustic_camera #(
        .MIC_COUNT (MIC_COUNT),
        .DECIMATION_FACTOR (DECIMATION_FACTOR),
        .N (N),
        .CLK_HZ (CLK_HZ),
        .COS_w (COS_w),
        .SIN_w (SIN_w)
    ) dut (
        .clk (clk),
        .rst (rst),
        .data (signal),
        .gain (gain),
        .zoom (zoom)
    );
    integer fd, p;

    always #5 clk = ~clk;

    initial begin
        $dumpvars(1, dut);
        rst = 0;
        #1
        rst = 1;
        #1
        rst = 0;
        #26000000
        
        fd = $fopen("framebuffer.txt", "w");
        for (p = 0; p < 1024; p++) begin
            $fwrite(fd, "%d\n", dut.framebuffer.buffer2[p][5:0]);
        end
        $fclose(fd);
        $finish();
    end


endmodule
