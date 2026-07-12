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
    parameter int MIC_COUNT = 30
)
(
    output logic        [15:0] wr_data,
    output logic         [9:0] wr_addr,
    output logic               frame_ready,
    input  logic               clk,
    input  logic               rst,
    input  logic signed [17:0] R [MIC_COUNT-1:0],
    input  logic signed [17:0] I [MIC_COUNT-1:0],
    input  logic               input_ready,
    input  logic         [4:0] gain,
    input  logic               zoom// 1 = 60deg, 0 = 180deg
);

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

logic [9:0] pixel_ctr;
logic [$clog2(MIC_COUNT)-1:0] mic_ctr;
logic signed [38:0] pixel_buffer_R, pixel_buffer_I;
logic signed [23:0] s_axis_phase_tdata;
logic [47:0] m_axis_dout_tdata;
logic signed [17:0] sin;
logic signed [17:0] cos;
logic s_axis_phase_tvalid, m_axis_dout_tvalid, s_axis_phase_tready;

logic signed [38:0] RC, IC, RS, IS;
logic signed [17:0] UX, VY;
logic signed [35:0] re_sq, img_sq;

logic signed [5:0] U, V; //FIX7_6
logic signed [5:0] U_next, V_next; //FIX7_6
logic [9:0] next_pixel_ctr;
logic signed [17:0] re,img;
logic [34:0] power;

enum logic [2:0] {IDLE, CALCULATING, WAITING1, WAITING2, WRITING1, WRITING2} state;

//scaled_radians (half turns)
//in  = FIXED18_15
//out = FIXED18_16
//takes 22 cycles
cordic_0 cordic_inst (
    .aclk       (clk),
    .s_axis_phase_tdata   (s_axis_phase_tdata),
    .m_axis_dout_tdata    (m_axis_dout_tdata),
    .s_axis_phase_tvalid (s_axis_phase_tvalid),
    .s_axis_phase_tready (s_axis_phase_tready),
    .m_axis_dout_tvalid (m_axis_dout_tvalid)
);


always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        pixel_ctr <= 0;
        mic_ctr <= 0;
        state <= IDLE;
        s_axis_phase_tvalid <= 0;
        pixel_buffer_R <= 0;
        pixel_buffer_I <= 0;
        frame_ready <= 0;
    end
    else begin
        case(state)
        IDLE: begin
            if(input_ready) begin
                state <= WAITING1;
                s_axis_phase_tvalid <= 1;
            end
            else begin
                state <= IDLE;
                s_axis_phase_tvalid <= 0;
            end
            UX <= U*(X[0] >>> zoom); // must match the WAITING2 shift below, or mic 0's first term
            VY <= V*(Y[0] >>> zoom); // stays wrong for the rest of the frame whenever zoom=0
            frame_ready <= 0;
        end
        WAITING1: begin
            if(s_axis_phase_tready) begin
                s_axis_phase_tvalid <= 0;
                state <= WAITING2;
            end
        end
        WAITING2: begin
            if(m_axis_dout_tvalid) begin
                state <= CALCULATING;
                RC <= R[mic_ctr]*cos;
                IC <= I[mic_ctr]*cos;
                RS <= R[mic_ctr]*sin;
                IS <= I[mic_ctr]*sin;

                if(mic_ctr == MIC_COUNT - 1) begin
                    //next pixel's U/V
                    UX <= U_next*(X[0] >>> zoom);
                    VY <= V_next*(Y[0] >>> zoom);
                end
                else begin
                    UX <= U*(X[mic_ctr + 1] >>> zoom);
                    VY <= V*(Y[mic_ctr + 1] >>> zoom);
                end
            end
            else begin
                state <= WAITING2;
            end
        end
        CALCULATING: begin
            if(mic_ctr == MIC_COUNT-1) begin
                mic_ctr <= 0;
                state <= WRITING1;
                s_axis_phase_tvalid <= 0;
            end
            else begin
                mic_ctr <= mic_ctr + 1;
                state <= WAITING1;
                s_axis_phase_tvalid <= 1;
            end
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
            s_axis_phase_tvalid <= 0;
        end
        WRITING2: begin
            wr_data <= (power >>> (31 - gain));
            wr_addr <= pixel_ctr; // capture together with wr_data, before pixel_ctr advances below
            if(pixel_ctr == 1023) begin
                    pixel_ctr <= 0;
                    state <= IDLE;
                    s_axis_phase_tvalid <= 0;
                    frame_ready <= 1;
            end
            else begin
                    pixel_ctr <= pixel_ctr +1;
                    state <= WAITING1;
                    s_axis_phase_tvalid <= 1;
            end
        end
        endcase
    end
end


always_comb begin
    U = {pixel_ctr[4:0], 1'b0} - 31; //FIX7_6
    V = 31 - {pixel_ctr[9:5], 1'b0}; //FIX7_6

    next_pixel_ctr = (pixel_ctr == 10'd1023) ? 10'd0 : pixel_ctr + 10'd1;
    U_next = {next_pixel_ctr[4:0], 1'b0} - 31; //FIX6_5
    V_next = 31 - {next_pixel_ctr[9:5], 1'b0}; //FIX6_5

    s_axis_phase_tdata = mic_ctr[0]? (UX + VY) : (UX + VY + 14'sd328); //FIX18_15

    sin = m_axis_dout_tdata[41:24]; //FIX18_16
    cos = m_axis_dout_tdata[17:0]; //FIX18_16

    re = pixel_buffer_R >>> 21;
    img = pixel_buffer_I >>> 21;

    power = re_sq + img_sq;
end



endmodule
