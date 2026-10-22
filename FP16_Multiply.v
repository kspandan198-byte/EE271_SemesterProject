module FP16_Multiply(
    input logic [15:0] a_fp16,
    input logic [15:0] b_fp16,
    output wire signed [7:0] normalized_exponent,
    output wire [21:0] normalized_product,
    output wire product_sign
);

localparam  [2:0] ZERO = 3'b000;
localparam  [2:0] SUBNORMAL = 3'b001;
localparam  [2:0] NORMAL = 3'b010;
localparam  [2:0] INFINITY = 3'b011;
localparam  [2:0] NaN = 3'b100;

//Unpack: Sign, Exponent, Mantissa
wire sign_a, sign_b;
wire [4:0] exponent_a, exponent_b;
wire [9:0] fraction_a, fraction_b;

assign sign_a = a_fp16[15];
assign exponent_a = a_fp16[14:10];
assign fraction_a = a_fp16[9:0];

assign sign_b = b_fp16[15];
assign exponent_b = b_fp16[14:10];
assign fraction_b = b_fp16[9:0];

function [2:0] classification(input [4:0] exponent, input [9:0] fraction);
    begin
        if (exponent == 5'b0)
            if (fraction == 10'b0)
                classification = ZERO;
            else
                classification = SUBNORMAL;
        else if (exponent == 5'b11111)
            if (fraction == 10'b0)
                classification = INFINITY;
            else
                classification = NaN;
        else
            classification = NORMAL;
    end
    endfunction

function [10:0] get_significand(input [9:0] fraction, input[2:0] classification_type);
    begin
        if(classification_type == NORMAL)
            get_significand = {1'b1, fraction};
        else if(classification_type == SUBNORMAL)
            get_significand = {1'b0, fraction};
        else
            get_significand = 11'b0;
    end
    endfunction

function signed [7:0] get_exponent(input [4:0] exponent, input [2:0] classification_type);
    begin
        if(classification_type == NORMAL)
            get_exponent = $signed({1'b0, exponent}) - 8'sd15;
        else if(classification_type == SUBNORMAL)
            get_exponent = -8'sd14;
        else
            get_exponent = 8'sd0;
    end
    endfunction

// Classification

wire [2:0] classification_a, classification_b;

assign classification_a = classification(exponent_a, fraction_a);
assign classification_b = classification(exponent_b, fraction_b);

//Significand
wire [10:0] significand_a, significand_b;
assign significand_a = get_significand(fraction_a, classification_a);
assign significand_b = get_significand(fraction_b, classification_b);
wire [21:0] raw_product;
assign raw_product = significand_a * significand_b;

//Exponent
wire signed [7:0] exponent_a_raw, exponent_b_raw;
assign exponent_a_raw = get_exponent(exponent_a, classification_a);
assign exponent_b_raw = get_exponent(exponent_b, classification_b);
wire signed [7:0] raw_exponent;
assign raw_exponent = exponent_a_raw + exponent_b_raw;

function [29:0] normalization (input [21:0] raw_product, input signed [7:0] raw_exponent);
    
    reg [21:0] variable_product;
    reg signed [7:0] variable_exponent;
    begin
        if (raw_product[21] == 1'b1) begin
            variable_product = raw_product >> 1;
            variable_exponent = raw_exponent + 8'sd1;
        end
        else
        begin
            variable_product = raw_product;
            variable_exponent = raw_exponent;
        end
        normalization = { variable_exponent, variable_product};
    end 
    endfunction

//Normalized Product
wire [29:0] normalized_result;

assign normalized_result = normalization(raw_product, raw_exponent);

assign normalized_exponent = normalized_result[29:22];
assign normalized_product = normalized_result[21:0];
assign product_sign = sign_a ^ sign_b;

endmodule