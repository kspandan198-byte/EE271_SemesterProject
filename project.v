module FP16_MAC(
    input logic clk,
    input logic rst,
    input logic en,
    input logic [15:0] a_fp16,
    input logic [15:0] b_fp16,
    output logic [31:0] acc
);

wire signed [7:0] normalized_exponent;
wire [21:0] normalized_fraction;
wire fraction_sign;

wire [31:0] acc_in_fp32 
assign acc_in_fp32= acc;

FP16_Multiply U1(.a_fp16(a_fp16), .b_fp16(b_fp16), .normalized_exponent(normalized_exponent),.normalized_fraction(normalized_fraction),.fraction_sign(fraction_sign));


FP16_ACC U2(.clk(clk), .rst(rst), .en(en), .normalized_exponent(normalized_exponent), .normalized_fraction(normalized_fraction),
            .product_sign(fraction_sign), .acc_in_fp32(acc_in_fp32), .acc_out_fp32(acc_in_fp32));


endmodule