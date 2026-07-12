`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/10/2026 05:43:52 PM
// Design Name: 
// Module Name: UART
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


module UART #(
    parameter int CLK_HZ = 100_000_000,
    parameter int BAUD   = 921_600
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        frame_ready,
    input  logic [15:0] rd_data,
    output logic [9:0]  rd_addr,
    output logic        tx,
    output logic        UART_busy
);
    localparam int DIV = CLK_HZ / BAUD;
    logic [$clog2(DIV)-1:0] div;
    logic enable;
    assign enable = (div == DIV-1);
    always_ff @(posedge clk) begin
        if (rst || enable || !UART_busy)
            div <= '0;
        else
            div <= div + 1;
    end

    
    enum logic [1:0] {IDLE, START, DATA, STOP} state;

    logic [7:0] out_shift;
    logic [2:0] bitc;
    logic [1:0] hdr;      //2 = 0xAA, 1 = 0x55, 0 = pixel bytes
    logic       hi;       //high byte of pixel
    logic [9:0] pixel;

    assign rd_addr = pixel;
    assign UART_busy = (state != IDLE);

    logic [7:0] next_byte;
    assign next_byte = (hdr == 2) ? 8'hAA : (hdr == 1) ? 8'h55 : hi ? rd_data[15:8] : rd_data[7:0];

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;  tx <= 1'b1;
        end else case (state)
            IDLE: begin
                tx <= 1'b1;
                if (frame_ready) begin
                    hdr <= 2;  hi <= 0;  pixel <= '0;
                    state  <= START;
                end
            end
            START: if (enable) begin
                tx    <= 1'b0;          //start bit
                out_shift <= next_byte;     //latch the byte once
                bitc  <= '0;
                state    <= DATA;
            end
            DATA: if (enable) begin
                tx    <= out_shift[0];      //LSB first
                out_shift <= out_shift >> 1;
                bitc  <= bitc + 1;
                if (bitc == 7) state <= STOP;
            end
            STOP: if (enable) begin
                tx <= 1'b1;             
                if (hdr != 0) begin
                    hdr <= hdr - 1;
                    state <= START;
                end
                else if (!hi) begin
                    hi  <= 1;
                    state <= START;
                end
                else if (pixel != 1023) begin
                    hi  <= 0;
                    pixel <= pixel+1;
                    state <= START;
                end
                else 
                    state <= IDLE;
            end
        endcase
    end
endmodule