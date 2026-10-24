module FP16_MAC(
    input wire clk,
    input wire rst,
    input wire en,
    input wire [15:0] a_fp16,
    input wire [15:0] b_fp16,
    output wire [31:0] acc);

        wire signed [7:0] normalized_exponent;
        wire [21:0] normalized_fraction;
        wire fraction_sign;

        wire [31:0] acc_feedback;
        assign acc= acc_feedback;

        FP16_Multiply U1(.a_fp16(a_fp16), .b_fp16(b_fp16), .normalized_exponent(normalized_exponent),.normalized_product(normalized_fraction),.product_sign(fraction_sign));


        FP16_ACC U2(.clk(clk), .rst(rst), .en(en), .normalized_exponent(normalized_exponent), .normalized_fraction(normalized_fraction),
                    .fraction_sign(fraction_sign), .acc_in_fp32(acc_feedback), .acc_out_fp32(acc_feedback));
            endmodule
