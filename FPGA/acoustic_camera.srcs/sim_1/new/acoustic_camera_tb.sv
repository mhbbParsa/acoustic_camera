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

    localparam int  MIC_COUNT         = 30;
    localparam int  CLOCK_DIVIDER     = 50;
    localparam int  DECIMATION_FACTOR = 32;
    localparam int  N_TB              = 1000;
    localparam int  TEST_FREQ         = 20000;

    logic clk = 0, n_reset = 0;
    logic [4:0] gain = 5'd4;
    logic [13:0] temp_ctr;
    logic signal[14:0];
    always_ff @(posedge clk or negedge n_reset) begin
        if(!n_reset) begin
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
        .CLOCK_DIVIDER (CLOCK_DIVIDER),
        .DECIMATION_FACTOR (DECIMATION_FACTOR),
        .N (N_TB)
    ) dut (
        .clk (clk),
        .n_reset (n_reset),
        .data (signal),
        .gain(gain)
    );
    integer fd, p;

    always #5 clk = ~clk;

    initial begin
        $dumpvars(1, dut);
        n_reset = 1;
        #1
        n_reset = 0;
        #1
        n_reset = 1;
        #26000000
        
        fd = $fopen("framebuffer.txt", "w");
        for (p = 0; p < 1024; p++) begin
            $fwrite(fd, "%d\n", dut.framebuffer[p]);
        end
        $fclose(fd);
        $finish();
    end


endmodule
