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
    output logic        swapped,
    output logic [15:0] rd_data,
    input  logic [9:0]  rd_addr,
    input  logic [15:0] wr_data,
    input  logic [9:0]  wr_addr,
    input  logic clk,
    input  logic rst,
    input  logic beamf_busy,
    input  logic tx_busy
);

(* ram_style = "block" *) logic [15:0] buffer1 [1023:0];
(* ram_style = "block" *) logic [15:0] buffer2 [1023:0];

logic select;
logic [15:0] rd_data1, rd_data2;

logic not_already_swapped;

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
    if (rst) begin
        select <= 0;
        not_already_swapped <= 0;
    end
    else begin
        if (beamf_busy || tx_busy) 
            not_already_swapped <= 1;
        if (!beamf_busy && !tx_busy && not_already_swapped) begin
            not_already_swapped <= 0;
            select <= !select;
            swapped <= 1;
        end
        else
            swapped <= 0;
    end
end

endmodule
