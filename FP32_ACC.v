module FP16_ACC(
    input logic clk,
    input logic rst,
    input logic en,
    input signed [7:0] normalized_exponent,
    input wire [21:0] normalized_fraction,
    input wire fraction_sign,
    input logic [31:0] acc_in_fp32,
    output logic [31:0] acc_out_fp32
);

//Accumulator
wire acc_sign;
wire [7:0] acc_exponent;
wire [22:0] acc_fraction;

//Accumulator Unpack
assign acc_sign = acc_in_fp32[31];
assign acc_exponent = acc_in_fp32[30:23];
assign acc_fraction = acc_in_fp32[22:0];

wire [23:0] acc_significand;
assign acc_significand = {1'b1, acc_fraction};

wire signed [8:0] acc_actual_exponent;
assign acc_actual_exponent = $signed({1'b0, acc_exponent})- 9'sd127;

//Accumulator Extended
wire [24:0] fraction_extended;
wire [24:0] acc_extended;

assign fraction_extended = {normalized_fraction, 3'b000};
assign acc_extended = {1'b0, acc_significand};

wire signed [8:0] exponent_extended;

assign exponent_extended = {{1{normalized_exponent[7]}}, normalized_exponent};

wire [24:0] aligned_fraction, aligned_acc;
wire signed [8:0] common_exponent;

assign aligned_fraction = (exponent_extended >=acc_actual_exponent)? fraction_extended: fraction_extended >>(acc_actual_exponent - exponent_extended);
assign aligned_acc = (acc_actual_exponent >=exponent_extended)? acc_extended: acc_extended >>(exponent_extended - acc_actual_exponent);

assign common_exponent = (exponent_extended >= acc_actual_exponent)? exponent_extended: acc_actual_exponent;

//Addition or Subtraction
function [26:0] adder( input [24:0] fraction_significand, input fraction_sign, input [24:0] acc_significand, input acc_sign);
    reg [25:0] result_sum;
    reg result_sign;
    begin
        if(fraction_sign == acc_sign) begin
            result_sum = {1'b0, fraction_significand} + {1'b0, acc_significand};
            result_sign = fraction_sign;
        end
        else if(fraction_significand >= acc_significand) begin
            result_sum = {1'b0, fraction_significand} - {1'b0, acc_significand};
            result_sign = fraction_sign;
        end
        else begin
            result_sum = {1'b0, acc_significand} - {1'b0, fraction_significand};
            result_sign = acc_sign;
        end
    
    adder = { result_sign, result_sum};
    end
    endfunction

wire result_sign;
wire [25:0] result_sum;
wire [26:0] adder_result;
assign adder_result = adder(aligned_fraction, fraction_sign, aligned_acc, acc_sign);
assign result_sign = adder_result[26];
assign result_sum = adder_result[25:0];

//Normalization 
function [34:0] normalization_fp32 (input [25:0] result_sum, input signed [8:0] common_exponent);
    
    reg [25:0] variable_fraction;
    reg signed [8:0] variable_exponent;
    integer i;
    begin
        variable_exponent = common_exponent;
        variable_fraction = result_sum;
        if( variable_fraction == 26'b0)begin
            variable_exponent = 9'sd0;
        end
        else if (result_sum[24] == 1'b1) begin
            variable_fraction = variable_fraction >> 1;
            variable_exponent = variable_exponent + 9'sd1;
        end
        else
        begin
            for (i =0; i<23; i=i+1)begin
                if(variable_fraction[23] == 1'b0)
                begin
                    variable_fraction = variable_fraction<<1;
                    variable_exponent = variable_exponent - 9'sd1;
                end
        
            end
        end

        normalization_fp32 = { variable_exponent, variable_fraction};
    end 
    endfunction

wire [34:0] normalization_fp32_result;
assign normalization_fp32_result= normalization_fp32(result_sum, common_exponent);

wire signed [8:0] final_exponent;
wire [25:0] final_fraction;
assign final_exponent = normalization_fp32_result[34:26];
assign final_fraction = normalization_fp32_result[25:0];
function [31:0] pack_fp32(input result_sign, input signed [8:0] unbiased_exponent, input [25:0] normalized_fraction);

    reg[7:0] biased_exponent;
    reg [22:0] fraction;

    begin
        if (normalized_fraction == 26'b0)begin
            pack_fp32 = 32'b0;
        end
        else begin
            biased_exponent = unbiased_exponent +9'sd127;
            fraction = normalized_fraction[22:0];
            pack_fp32 = { result_sign, biased_exponent,fraction};
        end 
    end
    endfunction

wire [31:0] packed_result;

assign packed_result = pack_fp32(result_sign,final_exponent, final_fraction);

always @(posedge clk) begin
    if(rst)
        acc_out_fp32 <=32'b0;
    else if (en)
        acc_out_fp32 <=packed_result; 
end


endmodule
