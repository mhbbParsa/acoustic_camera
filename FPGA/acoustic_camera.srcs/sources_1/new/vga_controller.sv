`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/24/2026 11:37:33 PM
// Design Name: 
// Module Name: vga_controller
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


module vga_controller(
    output logic [3:0] red,
    output logic [3:0] green,
    output logic [3:0] blue,
    output logic hsync,
    output logic vsync,
    input logic  clk,
    input logic  n_reset,
    input logic [5:0] framebuffer [1023:0]
    );

logic [9:0] h_cnt; // 0–799
logic [9:0] v_cnt; // 0–524
logic [3:0] r, g, b;

logic display;

logic [3:0] v_image_ctr, h_image_ctr;
logic [9:0] image_pixel_ctr;


logic [1:0] clk_ctr;
logic clock_enable;
always_ff @(posedge clk or negedge n_reset) begin
    if(!n_reset) begin
        clk_ctr <= 0;
        clock_enable <= 0;
    end
    else if (clk_ctr == 3) begin
       clk_ctr <= 0;
       clock_enable <= 1;
    end
    else begin
        clk_ctr <= clk_ctr + 1;
        clock_enable <= 0;
    end
end

always_ff @(posedge clk or negedge n_reset) begin
    if(!n_reset) begin
        h_cnt <= 0;
        v_cnt <= 0;
        v_image_ctr <= 0;
        h_image_ctr <= 0;
        image_pixel_ctr <= 0;
    end
    else if(clock_enable) begin
        if (h_cnt == 799) begin
            h_cnt <= 0;
            if (v_cnt == 524)
                v_cnt <= 0;
            else
                v_cnt <= v_cnt + 1;
        end
        else
            h_cnt <= h_cnt + 1;

        if(display) begin
            if(h_image_ctr == 14) begin
                h_image_ctr <= 0;
                if(image_pixel_ctr[4:0] == 31) begin
                    if(v_image_ctr == 14) begin
                        v_image_ctr <= 0;
                        if (image_pixel_ctr == 1023)
                            image_pixel_ctr <= 0;
                        else
                            image_pixel_ctr <= image_pixel_ctr + 1;
                    end
                    else begin
                        image_pixel_ctr <= image_pixel_ctr - 31;
                        v_image_ctr <= v_image_ctr + 1;
                    end
                end
                else begin
                    image_pixel_ctr <= image_pixel_ctr + 1;
                end
            end
            else begin
                h_image_ctr <= h_image_ctr + 1;
            end
        end
    end
end





always_comb begin
    if (framebuffer[image_pixel_ctr] < 16) begin        // black to blue
        r = 0;
        g = 0;
        b = framebuffer[image_pixel_ctr];
    end else if (framebuffer[image_pixel_ctr] < 32) begin  // blue to cyan
        r = 0;
        g = framebuffer[image_pixel_ctr] - 16;
        b = 4'hF;
    end else if (framebuffer[image_pixel_ctr] < 48) begin  // cyan to yellow
        r = framebuffer[image_pixel_ctr] - 32;
        g = 4'hF;
        b = 47 - framebuffer[image_pixel_ctr];
    end else begin              // yellow to red
        r = 4'hF;
        g = 63 - framebuffer[image_pixel_ctr];
        b = 0;
    end
end

assign red = display? r : 4'b0;
assign blue = display? b : 4'b0;
assign green = display? g : 4'b0; 


assign hsync = ~(h_cnt >= 656 && h_cnt < 752);
assign vsync = ~(v_cnt >= 490 && v_cnt < 492);
assign display = (h_cnt > 79 && h_cnt < 560 && v_cnt < 480);


endmodule
