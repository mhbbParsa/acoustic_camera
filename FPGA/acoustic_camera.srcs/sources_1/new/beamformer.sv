`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/22/2026 05:48:26 PM
// Design Name: 
// Module Name: beamformer
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


module beamformer #(
    parameter MIC_COUNT = 30
)
(
    output logic [3:0] framebuffer [1023:0],
    input logic               clk,
    input logic               n_reset,
    input logic signed [17:0] R [MIC_COUNT-1:0],
    input logic signed [17:0] I [MIC_COUNT-1:0],
    input logic               input_ready
);
localparam CORDIC_DELAY = 22;

//even MK = vdd mic
//odd  MK = gnd mic
localparam signed [13:0] X [MIC_COUNT-1:0] = '{
    14'sd2414,   // MK24
    14'sd4717,   // MK29
    14'sd1347,   // MK10
    14'sd1044,   // MK23
    14'sd3047,   // MK16
    14'sd4509,   // MK21
    14'sd694,    // MK0
    14'sd1117,   // MK3
    14'sd4585,   // MK26
    14'sd3521,   // MK13
    14'sd2991,   // MK18
    14'sd1941,   // MK5
    14'sd2687,   // MK8
    14'sd996,    // MK11
    -14'sd3820,  // MK22
    -14'sd1986,  // MK27
    -14'sd1773,  // MK28
    -14'sd496,   // MK15
    -14'sd4720,  // MK12
    -14'sd4101,  // MK17
    14'sd136,    // MK2
    -14'sd886,   // MK1
    -14'sd2149,  // MK14
    -14'sd2795,  // MK9
    -14'sd2846,  // MK20
    -14'sd1238,  // MK7
    -14'sd649,   // MK6
    -14'sd200,   // MK19
    -14'sd2049,  // MK4
    -14'sd3001  // MK25
};

localparam signed [13:0] Y [MIC_COUNT-1:0] = '{
    14'sd4214,   // MK24
    14'sd2479,   // MK29
    -14'sd2879,  // MK10
    -14'sd4640,  // MK23
    14'sd2568,   // MK16
    14'sd607,    // MK21
    14'sd0,      // MK0
    14'sd1457,   // MK3
    -14'sd2118,  // MK26
    -14'sd774,   // MK13
    -14'sd2977,  // MK18
    -14'sd1235,  // MK5
    14'sd981,    // MK8
    14'sd3175,   // MK11
    14'sd2658,   // MK22
    14'sd4746,   // MK27
    -14'sd4929,  // MK28
    -14'sd3831,  // MK15
    -14'sd1506,  // MK12
    14'sd170,    // MK17
    -14'sd1545,  // MK2
    14'sd812,    // MK1
    14'sd3056,   // MK14
    14'sd1154,   // MK9
    -14'sd3411,  // MK20
    -14'sd2384,  // MK7
    14'sd2416,   // MK6
    14'sd4328,   // MK19
    -14'sd363,   // MK4
    -14'sd1739  // MK25
};


logic [$clog2(CORDIC_DELAY)-1:0] waiting_ctr;
logic [9:0] pixel_ctr;
logic [$clog2(MIC_COUNT)-1:0] mic_ctr;
logic signed [38:0] pixel_buffer_R, pixel_buffer_I;
logic signed [17:0] steering_cycles;
logic [41:0] cordic_out;
logic signed [17:0] sin;
logic signed [17:0] cos;
logic phase_valid, cordic_valid;

logic signed [38:0] RC, IC, RS, IS;
logic signed [17:0] UX, VY;
logic signed [35:0] re_sq, img_sq;

logic signed [5:0] U, V; //FIX6_5
logic signed [5:0] U_next, V_next; //FIX6_5
logic [9:0] next_pixel_ctr;
logic signed [17:0] re,img;
logic [34:0] power;

enum logic [2:0] {IDLE, CALCULATING1, CALCULATING2, WAITING, WRITING1, WRITING2} state;

//scaled_radians (half turns)
//in  = FIXED18_15
//out = FIXED18_16
//takes 22 cycles
cordic_0 cordic_inst (
    .aclk       (clk),
    .s_axis_phase_tdata   (steering_cycles),
    .m_axis_dout_tdata    (cordic_out),
    .s_axis_phase_tvalid (phase_valid),
    .m_axis_dout_tvalid (cordic_valid)
);


always_ff @(posedge clk or negedge n_reset) begin
    if (!n_reset) begin
        waiting_ctr <= 0;
        pixel_ctr <= 0;
        mic_ctr <= 0;
        state <= IDLE;
        phase_valid <= 0;
        pixel_buffer_R <= 0;
        pixel_buffer_I <= 0;
    end
    else begin
        case(state)
        IDLE: begin
            if(input_ready) begin
                phase_valid <= 1;
                state <= WAITING;
            end
            else begin
                phase_valid <= 0;
                state <= IDLE;
                
            end
            UX <= U*X[0];
            VY <= V*Y[0];
            steering_cycles <= (UX + VY + 14'sd328); //FIX18_15
        end
        WAITING: begin
            if(cordic_valid) begin
                phase_valid <= 0;
                state <= CALCULATING1;
            end
            else begin
                phase_valid <= 0;
                state <= WAITING;
            end
        end
        CALCULATING1: begin
            state <= CALCULATING2;
            RC <= R[mic_ctr]*cos;
            IC <= I[mic_ctr]*cos;
            RS <= R[mic_ctr]*sin;
            IS <= I[mic_ctr]*sin;
            if(mic_ctr == MIC_COUNT - 1) begin
                //next pixel's U/V
                UX <= U_next*X[0];
                VY <= V_next*Y[0];
            end
            else begin
                UX <= U*X[mic_ctr + 1];
                VY <= V*Y[mic_ctr + 1];
            end
        end
        CALCULATING2: begin
            if(mic_ctr == MIC_COUNT-1) begin
                mic_ctr <= 0;
                state <= WRITING1;
            end
            else begin
                mic_ctr <= mic_ctr + 1;
                state <= WAITING;
            end
            steering_cycles <= mic_ctr[0]? (UX + VY + 14'sd328) : (UX + VY); //FIX18_15
            phase_valid <= 1;
            //to compensate for the fact that odd mics sample 250ns later
            pixel_buffer_R <= pixel_buffer_R + RC - IS;
            pixel_buffer_I <= pixel_buffer_I + IC + RS;
        end
        WRITING1: begin
            re_sq <= re*re;
            img_sq <= img*img;
            pixel_buffer_R <= 0;
            pixel_buffer_I <= 0;
            state <= WRITING2;
            phase_valid <= 0;
        end
        WRITING2: begin
            framebuffer[pixel_ctr] <= power[32:29];
            phase_valid <= 0;
            if(pixel_ctr == 1023) begin
                    pixel_ctr <= 0;
                    state <= IDLE;
            end
            else begin
                    pixel_ctr <= pixel_ctr +1;
                    state <= WAITING;
            end
        end
        endcase
    end
end


always_comb begin
    U = {pixel_ctr[4:0], 1'b0} - 31; //FIX6_5
    V = {pixel_ctr[9:5], 1'b0} - 31; //FIX6_5

    next_pixel_ctr = (pixel_ctr == 10'd1023) ? 10'd0 : pixel_ctr + 10'd1;
    U_next = {next_pixel_ctr[4:0], 1'b0} - 31; //FIX6_5
    V_next = {next_pixel_ctr[9:5], 1'b0} - 31; //FIX6_5


    sin = cordic_out[41:24]; //FIX18_16
    cos = cordic_out[17:0]; //FIX18_16

    re = pixel_buffer_R >>> 21;
    img = pixel_buffer_I >>> 21;

    power = re_sq + img_sq;
end





endmodule
