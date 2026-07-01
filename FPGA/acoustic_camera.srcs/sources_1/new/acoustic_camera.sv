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
    parameter int CLOCK_DIVIDER = 50,
    parameter DECIMATION_FACTOR = 64,
    parameter int N = 1000,
    parameter signed [31:0] COS_w = 32'hC97F276E,
    parameter signed [31:0] SIN_w = 32'h73D0D6F3
)(
    output logic       mic_clk,
    output logic [3:0] red,
    output logic [3:0] green,
    output logic [3:0] blue,
    output logic       hsync,
    output logic       vsync,
    input  logic       data [14:0],
    input  logic       clk,
    input  logic       n_reset
);

logic signed [17:0] audio [MIC_COUNT-1:0];
logic signed [17:0] R [MIC_COUNT-1:0];
logic signed [17:0] I [MIC_COUNT-1:0];
logic [3:0] framebuffer [1023:0];


logic goertzel_valid;
logic audio_ready;


master_mic #(
    .MIC_COUNT(MIC_COUNT),
    .CLOCK_DIVIDER(CLOCK_DIVIDER),
    .DECIMATION_FACTOR (DECIMATION_FACTOR)
)
mics (
    .audio(audio),
    .mic_clk(mic_clk),
    .audio_ready(audio_ready),
    .data(data),
    .clk(clk),
    .n_reset(n_reset)
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
    .n_reset(n_reset),
    .audio(audio)
);

beamformer #(
    .MIC_COUNT(MIC_COUNT)
)
beamf (
    .framebuffer(framebuffer),
    .clk(clk),
    .n_reset(n_reset),
    .R(R),
    .I(I),
    .input_ready(goertzel_valid)
);

vga_controller
vga (
    .red(red),
    .green(green),
    .blue(blue),
    .hsync(hsync),
    .vsync(vsync),
    .clk(clk),
    .n_reset(n_reset),
    .framebuffer(framebuffer)
);
endmodule
