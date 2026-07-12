`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/11/2026 12:07:45 PM
// Design Name: 
// Module Name: digit_disp
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


module digit_disp #(
    parameter int LED_MUX_HZ = 200,
    parameter int CLK_HZ = 100_000_000
)(
    output logic [6:0] seg,
    output logic [3:0] an,
    output logic       dp,
    input  logic [4:0] gain,
    input  logic       clk,
    input  logic       rst
);
    
logic [3:0] ones_digit, tens_digit;
logic [6:0] ones_seg, tens_seg;
logic [$clog2(CLK_HZ/LED_MUX_HZ)-1:0] ctr;

assign dp = 1'b1;

sevenseg ones_sevenseg(
    .seg(ones_seg), 
    .digit(ones_digit)
);

sevenseg tens_sevenseg(
    .seg(tens_seg), 
    .digit(tens_digit)
);


always_ff @(posedge clk or posedge rst) begin
    if(rst) begin
        ctr <= 0;
    end
    else if(ctr == CLK_HZ/LED_MUX_HZ/2) begin
        seg <= ones_seg;
        an <= 4'b1110;
        ctr <= ctr + 1;
    end
    else if(ctr == CLK_HZ/LED_MUX_HZ) begin
        seg <= tens_seg;
        an <= 4'b1101;
        ctr <= 0;
    end
    else
        ctr <= ctr + 1;
end

always_comb begin
    if(gain > 29) begin
        tens_digit = 4'd3;
        ones_digit = gain - 5'd30;
    end
    else if(gain > 19) begin
        tens_digit = 4'd2;
        ones_digit = gain - 5'd20;
    end
    else if(gain > 9) begin
        tens_digit = 4'd1;
        ones_digit = gain - 5'd10;
    end
    else begin
        tens_digit = 4'd0;
        ones_digit = gain;
    end
end
    
endmodule
