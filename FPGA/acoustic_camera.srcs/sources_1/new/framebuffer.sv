`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/10/2026 08:03:46 PM
// Design Name: 
// Module Name: framebuffer
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


module framebuffer(
    output logic [15:0] rd_data,
    input  logic [9:0]  rd_addr,
    input  logic [15:0] wr_data,
    input  logic [9:0]  wr_addr,
    input  logic clk,
    input  logic rst,
    input  logic frame_ready,
    input  logic UART_busy
);

(* ram_style = "block" *) logic [15:0] buffer1 [1023:0];
(* ram_style = "block" *) logic [15:0] buffer2 [1023:0];

logic select;
logic [15:0] rd_data1, rd_data2;

// each buffer gets its own dedicated, purely-synchronous read/write process
// (no async reset, no cross-array muxing inside the process) so Vivado
// infers a block RAM per buffer instead of falling back to flip-flops.
always_ff @(posedge clk) begin
    if (select)
        buffer1[wr_addr] <= wr_data;
    else
        buffer2[wr_addr] <= wr_data;
        
    rd_data1 <= buffer1[rd_addr];
    rd_data2 <= buffer2[rd_addr];
end

assign rd_data = select ? rd_data2 : rd_data1;

always_ff @(posedge clk or posedge rst) begin
    if (rst)
        select <= 0;
    else if (frame_ready && !UART_busy)
        select <= !select;
end

endmodule
