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

localparam int MIC_COUNT = 30;


logic clk, rst, input_ready;
logic signed [17:0] R [MIC_COUNT-1:0];
logic signed [17:0] I [MIC_COUNT-1:0];
logic [4:0] gain = 5'd16;
logic zoom = 1; // 1 = 60deg, 0 = 180deg

logic [15:0] wr_data;
logic [9:0]  wr_addr;
logic        beamf_busy;

logic [15:0] rd_data;
logic [9:0]  rd_addr;

beamformer #(
    .MIC_COUNT(MIC_COUNT)
)
dut (
    .clk(clk),
    .rst(rst),
    .R(R),
    .I(I),
    .input_ready(input_ready),
    .gain(gain),
    .zoom(zoom),
    .wr_data(wr_data),
    .wr_addr(wr_addr),
    .beamf_busy(beamf_busy)
);

framebuffer dut_fb (
    .rd_data(rd_data),
    .rd_addr(rd_addr),
    .wr_addr(wr_addr),
    .wr_data(wr_data),
    .clk(clk),
    .rst(rst),
    .beamf_busy(beamf_busy),
    .tx_busy(1'b0),
    .swapped()
);

always #5 clk = ~clk;
integer fd, p;
integer k;
initial begin
    clk = 0;
    rst = 1;
    input_ready = 0;
    for (k = 0; k < MIC_COUNT; k++) begin
        R[k] = 18'h1ffff;
        I[k] = 18'h1ffff;
    end

    @(posedge clk); #1;
    rst = 0;

    @(posedge clk); #1;
    input_ready = 1;
    @(posedge clk); #1;
    input_ready = 0;

  
    #8000000;

    repeat (4) @(posedge clk);

    fd = $fopen("framebuffer.txt", "w");
    for (p = 0; p <= 1023; p++) begin
        rd_addr = p[9:0];
        @(posedge clk); #1;
        $fwrite(fd, "%d\n", rd_data[5:0]);
    end
    $fclose(fd);

    $finish;
end


initial begin
    $dumpfile("beamformer_tb.vcd");
    $dumpvars(0, beamformer_tb);
end

endmodule