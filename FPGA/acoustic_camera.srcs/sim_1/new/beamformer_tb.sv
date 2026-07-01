`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/21/2026 07:36:59 PM
// Design Name: 
// Module Name: beamformer_tb
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

module beamformer_tb;

parameter MIC_COUNT = 30;

logic clk, n_reset, input_ready;
logic signed [17:0] R [MIC_COUNT-1:0];
logic signed [17:0] I [MIC_COUNT-1:0];
logic [3:0] framebuffer [1023:0];

beamformer #(.MIC_COUNT(MIC_COUNT)) dut (
    .clk(clk),
    .n_reset(n_reset),
    .R(R),
    .I(I),
    .input_ready(input_ready),
    .framebuffer(framebuffer)
);

always #5 clk = ~clk;
integer fd, p;
integer k;
initial begin
    clk = 0;
    n_reset = 0;
    input_ready = 0;
    for (k = 0; k < MIC_COUNT; k++) begin
        R[k] = 18'h1ffff;
        I[k] = 18'h1ffff;
    end

    @(posedge clk); #1;
    n_reset = 1;

    @(posedge clk); #1;
    input_ready = 1;
    @(posedge clk); #1;
    input_ready = 0;

    // wait long enough for all 1024 pixels to complete
    // each pixel: 1 WAITING(22) + 30*(1 CALCULATING + 22 WAITING) + 1 WRITING = 714 cycles
    // 1024 pixels * 714 = ~731136 cycles
    #8000000;

    
    fd = $fopen("framebuffer.txt", "w");
    for (p = 0; p < 1024; p++) begin
        $fwrite(fd, "%d\n", dut.framebuffer[p]);
    end
    $fclose(fd);

    $finish;
end

// dump framebuffer when done
initial begin
    $dumpfile("beamformer_tb.vcd");
    $dumpvars(0, beamformer_tb);
end

endmodule