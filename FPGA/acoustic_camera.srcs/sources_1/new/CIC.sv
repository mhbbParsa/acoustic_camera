`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/14/2026 11:32:18 PM
// Design Name: 
// Module Name: CIC
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
module CIC #(
    parameter DECIMATION_FACTOR = 64
)(
    output logic signed [17:0] audio,
    input logic                PDM,
    input logic                enable,
    input logic                decimate,
    input logic                clk,
    input logic                n_reset
);


logic signed [1+4*$clog2(DECIMATION_FACTOR):0] integrator1, integrator2, integrator3, integrator4;
logic signed [1+4*$clog2(DECIMATION_FACTOR):0] comb1, comb2, comb3, comb4;
logic signed [1+4*$clog2(DECIMATION_FACTOR):0] d1, d2, d3, d4;

always_ff @(posedge clk, negedge n_reset) begin
    if(!n_reset) begin
        integrator1 <= 0;
        integrator2 <= 0;
        integrator3 <= 0;
        integrator4 <= 0;

        d1 <= 0;
        d2 <= 0;
        d3 <= 0;
        d4 <= 0;

        comb1 <= 0;
        comb2 <= 0;
        comb3 <= 0;
        comb4 <= 0;
    end
    else if(enable) begin
        integrator4 <= integrator4 + integrator3;
        integrator3 <= integrator3 + integrator2;
        integrator2 <= integrator2 + integrator1;
        integrator1 <= integrator1 + (PDM ? (+1) : (-1));

        if(decimate) begin
                comb4 <= comb3       - d4;
                comb3 <= comb2       - d3;
                comb2 <= comb1       - d2;
                comb1 <= integrator4 - d1;

                d4 <= comb3;
                d3 <= comb2;
                d2 <= comb1;
                d1 <= integrator4;
        end
    end 
end


assign audio = comb4[1+4*$clog2(DECIMATION_FACTOR):4*$clog2(DECIMATION_FACTOR)-16];

endmodule