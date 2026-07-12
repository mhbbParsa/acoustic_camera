`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/21/2026 07:20:19 PM
// Design Name: 
// Module Name: acoustic_camera
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


module acoustic_camera #(
    parameter int MIC_COUNT = 30,
    parameter int DECIMATION_FACTOR = 32,
    parameter int N = 1000,
    parameter signed [31:0] COS_w = 32'hC97F276E,
    parameter signed [31:0] SIN_w = 32'h73D0D6F3,
    parameter int CLK_HZ = 100_000_000,
    parameter int MIC_HZ = 2_000_000,
    parameter int BAUD   = 2_000_000,
    parameter int LED_MUX_HZ = 200
)(
    output logic       mic_clk,
    output logic       tx,
    output logic [6:0] seg,
    output logic       dp,
    output logic [3:0] an,
    output logic [5:0] led,
//    output logic [3:0] red,
//    output logic [3:0] green,
//    output logic [3:0] blue,
//    output logic       hsync,
//    output logic       vsync,
    input  logic       data [14:0],
    input  logic       clk,
    input  logic       rst,
    input  logic [4:0] gain,
    input  logic       zoom // 1 = 60deg, 0 = 180deg
);

assign led = 6'b111111;

logic signed [17:0] audio [MIC_COUNT-1:0];
logic signed [17:0] R [MIC_COUNT-1:0];
logic signed [17:0] I [MIC_COUNT-1:0];

logic goertzel_valid;
logic audio_ready;
logic frame_ready;
logic UART_busy;

logic [15:0] rd_data;
logic [9:0]  rd_addr;

logic [15:0] wr_data;
logic [9:0]  wr_addr;

master_mic #(
    .MIC_COUNT(MIC_COUNT),
    .CLK_HZ(CLK_HZ),
    .DECIMATION_FACTOR (DECIMATION_FACTOR),
    .MIC_HZ(MIC_HZ)
)
mics (
    .audio(audio),
    .mic_clk(mic_clk),
    .audio_ready(audio_ready),
    .data(data),
    .clk(clk),
    .rst(rst)
);

goertzel #(
    .N(N),
    .MIC_COUNT(MIC_COUNT),
    .COS_w(COS_w),
    .SIN_w(SIN_w)
)
goertzel_20KHz (
    .R(R),
    .I(I),
    .goertzel_valid(goertzel_valid),
    .clk(clk),
    .enable_goertzel(audio_ready),
    .rst(rst),
    .audio(audio)
);

beamformer #(
    .MIC_COUNT(MIC_COUNT)
)
beamf (
    .wr_addr(wr_addr),
    .wr_data(wr_data),
    .frame_ready(frame_ready),
    .clk(clk),
    .rst(rst),
    .R(R),
    .I(I),
    .input_ready(goertzel_valid),
    .gain(gain),
    .zoom(zoom)
);

framebuffer framebuffer(
    .rd_data(rd_data),
    .rd_addr(rd_addr),
    .wr_addr(wr_addr),
    .wr_data(wr_data),
    .clk(clk),
    .rst(rst),
    .frame_ready(frame_ready),
    .UART_busy(UART_busy)
);

UART #(
    .CLK_HZ(CLK_HZ),
    .BAUD(BAUD)
)
uart(
    .clk(clk),
    .rst(rst),
    .frame_ready(frame_ready),
    .rd_data(rd_data),
    .rd_addr(rd_addr),
    .tx(tx),
    .UART_busy(UART_busy)
);

/*
vga_controller
vga (
    .red(red),
    .green(green),
    .blue(blue),
    .hsync(hsync),
    .vsync(vsync),
    .clk(clk),
    .rst(rst),
    .rd_data(rd_data),
    .rd_addr(rd_addr),
);
*/

digit_disp #(
    .LED_MUX_HZ(LED_MUX_HZ),
    .CLK_HZ(CLK_HZ)
)
digit_disp(
    .clk(clk),
    .rst(rst),
    .seg(seg),
    .an(an),
    .dp(dp),
    .gain(gain)
);
endmodule
