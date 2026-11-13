module FP32_ACC(
    input wire clk,
    input wire rst,
    input wire en,
    input signed [7:0] normalized_exponent,
    input wire [21:0] normalized_fraction,
    input wire fraction_sign,
    input wire [2:0] product_class,
    input wire [31:0] acc_in_fp32,
    output reg [31:0] acc_out_fp32);

    localparam  [2:0] ZERO = 3'b000;
    localparam  [2:0] SUBNORMAL = 3'b001;
    localparam  [2:0] NORMAL = 3'b010;
    localparam  [2:0] INFINITY = 3'b011;
    localparam  [2:0] NaN = 3'b100;
    //Accumulator Unpack
    wire acc_sign;
    wire [7:0] acc_exponent;
    wire [22:0] acc_fraction;
    wire [2:0] acc_class;
    wire acc_is_nan;
    wire acc_is_inf;
    wire acc_is_zero;
    wire acc_is_normal;
    wire acc_is_subnormal;

    wire [23:0] acc_significand;
    wire signed [8:0] acc_actual_exponent;
    wire signed [8:0] exponent_extended;

    assign acc_significand = acc_is_normal ? {1'b1, acc_fraction}:
                             acc_is_subnormal ? {1'b0, acc_fraction}:24'b0;
    assign acc_exponent = acc_in_fp32[30:23];
    assign acc_fraction = acc_in_fp32[22:0];

    assign acc_class = classification_fp32(acc_exponent,acc_fraction);

    assign acc_is_zero = (acc_class == ZERO);
    assign acc_is_inf = (acc_class == INFINITY);
    assign acc_is_nan = (acc_class == NaN);
    assign acc_is_normal = (acc_class == NORMAL);
    assign acc_is_subnormal = (acc_class == SUBNORMAL);

    assign acc_sign = acc_is_zero ? 1'b0: acc_in_fp32[31];
    
    assign exponent_extended = {{1{normalized_exponent[7]}}, normalized_exponent};

    assign acc_actual_exponent = acc_is_zero ? exponent_extended:acc_is_subnormal? -9'sd126:
                                ($signed({1'b0,acc_exponent})-9'sd127);

    //Accumulator Extended
    wire [27:0] fraction_extended;
    wire [27:0] acc_extended;

    assign fraction_extended = {1'b0,normalized_fraction, 2'b00, 3'b000};
    assign acc_extended = {1'b0, acc_significand,3'b000};

    function [28:0] shift_right_sticky(input [28:0] value, input [8:0] shift_amount);
        reg [28:0] shifted_value;
        reg sticky_value;

        begin
            shifted_value = 29'b0;
            sticky_value = 1'b0;
            
            if(|shift_amount[8:5])begin
                shifted_value = 29'b0;
                sticky_value = |value;
            end
            else begin
                if (shift_amount[0])begin
                    sticky_value = sticky_value | shifted_value[0];
                    shifted_value = shifted_value >> 1;
                    shifted_value[0] = shifted_value[0] | sticky_value;
                end
                if (shift_amount[1])begin
                    sticky_value = sticky_value | shifted_value[1:0];
                    shifted_value = shifted_value >> 2;
                    shifted_value[0] = shifted_value[0] | sticky_value;
                end
                if (shift_amount[2])begin
                    sticky_value = sticky_value | shifted_value[3:0];
                    shifted_value = shifted_value >> 4;
                    shifted_value[0] = shifted_value[0] | sticky_value;
                end
                if (shift_amount[3])begin
                    sticky_value = sticky_value | shifted_value[7:0];
                    shifted_value = shifted_value >> 8;
                    shifted_value[0] = shifted_value[0] | sticky_value;
                end
                if (shift_amount[4])begin
                    sticky_value = sticky_value | shifted_value[16:0];
                    shifted_value = shifted_value >> 16;
                    shifted_value[0] = shifted_value[0] | sticky_value;
                end

            end
            shifted_value[0] = shifted_value[0] | sticky_value;

            shift_right_sticky = shifted_value; 
        end  
        
    endfunction 
  

    wire [27:0] aligned_fraction;
    wire [27:0] aligned_acc;
    wire signed [8:0] common_exponent;

    wire exponent_product_ge_acc;
    wire [8:0] exponent_difference;

    reg [27:0] aligned_fraction_reg;
    reg [27:0] aligned_acc_reg;
    reg signed [8:0] common_exponent_reg;
    
    assign exponent_product_ge_acc =
    (exponent_extended >= acc_actual_exponent);

    assign exponent_difference =
        exponent_product_ge_acc ?
        (exponent_extended - acc_actual_exponent) :
        (acc_actual_exponent - exponent_extended);

    always @(*) begin
        aligned_fraction_reg = fraction_extended;
        aligned_acc_reg = acc_extended;

        if (exponent_product_ge_acc) begin
            common_exponent_reg = exponent_extended;

            aligned_acc_reg =
                shift_right_sticky(
                    {1'b0, acc_extended},
                    exponent_difference
                );
        end
        else begin
            common_exponent_reg = acc_actual_exponent;

            aligned_fraction_reg =
                shift_right_sticky(
                    {1'b0, fraction_extended},
                    exponent_difference
                );
        end
    end

    assign aligned_fraction = aligned_fraction_reg;
    assign aligned_acc = aligned_acc_reg;
    assign common_exponent = common_exponent_reg;

 
    //Addition or Subtraction
function [29:0] adder(
    input [27:0] fraction_significand,
    input fraction_sign,
    input [27:0] acc_significand,
    input acc_sign
);

    reg [28:0] result_sum;
    reg result_sign;
    reg [28:0] difference;

    begin
        result_sum  = 29'b0;
        result_sign = 1'b0;
        difference  = 29'b0;

        if (fraction_sign == acc_sign) begin
            result_sum = {1'b0, fraction_significand}
                       + {1'b0, acc_significand};
            result_sign = fraction_sign;
        end
        else begin
            difference = {1'b0, fraction_significand}
                       - {1'b0, acc_significand};

            if (difference[28] == 1'b0) begin
                result_sum  = difference;
                result_sign = fraction_sign;
            end
            else begin
                result_sum = {1'b0,
                              (~difference[27:0] + 28'd1)};
                result_sign = acc_sign;
            end
        end

        adder = {result_sign, result_sum};
    end

endfunction

    wire result_sign;
    wire [28:0] result_sum;
    wire [29:0] adder_result;
    assign adder_result = adder(aligned_fraction, fraction_sign, aligned_acc, acc_sign);
    assign result_sign = adder_result[29];
    assign result_sum = adder_result[28:0];

    //Normalization 
    function [37:0] normalization_fp32 (input [28:0] result_sum, input signed [8:0] common_exponent);
        
        reg [28:0] variable_fraction;
        reg signed [8:0] variable_exponent;
        integer i;
        begin
            variable_exponent = common_exponent;
            variable_fraction = result_sum;
            if( variable_fraction == 29'b0)begin
                variable_exponent = 9'sd0;
            end
            else if (result_sum[27] == 1'b1) begin
                variable_fraction = result_sum >> 1;
                variable_fraction[0] = result_sum[1]|result_sum[0];
                variable_exponent = variable_exponent + 9'sd1;
            end
            else
            begin
                
                if(variable_fraction[26:11] == 16'b0)
                begin
                    variable_fraction = variable_fraction<<16;
                    variable_exponent = variable_exponent - 9'sd16;
                end

                if(variable_fraction[26:19] == 8'b0)
                begin
                    variable_fraction = variable_fraction<<8;
                    variable_exponent = variable_exponent - 9'sd8;
                end

                if(variable_fraction[26:23] == 4'b0)
                begin
                    variable_fraction = variable_fraction<<4;
                    variable_exponent = variable_exponent - 9'sd4;
                end

                if(variable_fraction[26:25] == 2'b0)
                begin
                    variable_fraction = variable_fraction<<2;
                    variable_exponent = variable_exponent - 9'sd2;
                end
                if(variable_fraction[26] == 1'b0)
                begin
                    variable_fraction = variable_fraction<<1;
                    variable_exponent = variable_exponent - 9'sd1;
                end
            
            end
            

            normalization_fp32 = { variable_exponent, variable_fraction};
        end 
        endfunction

    wire [37:0] normalization_fp32_result;
    assign normalization_fp32_result= normalization_fp32(result_sum, common_exponent);

    wire signed [8:0] final_exponent;
    wire [28:0] final_fraction;
    assign final_exponent = normalization_fp32_result[37:29];
    assign final_fraction = normalization_fp32_result[28:0];
    function [31:0] pack_fp32(input result_sign, input signed [8:0] unbiased_exponent, input [28:0] normalized_fraction);

        reg [23:0] significand;
        reg [24:0] rounded_significand;

        reg [28:0] subnormal_fraction;
        reg [23:0]subnormal_significand;
        reg signed [8:0] subnormal_shift;
        reg[7:0] biased_exponent;
        reg signed[8:0] final_exponent;

        begin
            if (normalized_fraction == 29'b0)begin
                pack_fp32 = 32'b0;
            end
            else if(unbiased_exponent < -9'sd126)begin
                subnormal_shift = -9'sd126 - unbiased_exponent;
                subnormal_fraction = shift_right_sticky(normalized_fraction,subnormal_shift);

                subnormal_significand = {1'b0, subnormal_fraction[25:3]};
                if(subnormal_fraction[2] && (subnormal_fraction[1]||subnormal_fraction[0]||subnormal_fraction[3]))begin
                    subnormal_significand = subnormal_significand + 24'd1;
                end
                if(subnormal_significand[23])begin
                    pack_fp32 = {result_sign,8'h01,23'b0};
                end
                else begin
                    pack_fp32 = {result_sign,8'h00,subnormal_significand[22:0]};
                end
            end
            else begin
                significand = normalized_fraction[26:3];
                rounded_significand = {1'b0, significand};
                final_exponent = unbiased_exponent;
                if(normalized_fraction[2] && (normalized_fraction[1]||normalized_fraction[0]||normalized_fraction[3]))begin
                    rounded_significand = rounded_significand + 25'd1;
                end

                if(rounded_significand[24])begin
                    rounded_significand = rounded_significand >>1;
                    final_exponent = final_exponent + 9'sd1;
                end

                if(final_exponent > 9'sd127)begin
                    pack_fp32 = {result_sign,8'hFF, 23'b0};
                end
                else begin
                    biased_exponent = final_exponent + 9'sd127;
                    pack_fp32 = {result_sign, biased_exponent, rounded_significand[22:0]};
                end
            end
        end
        endfunction

    function [2:0] classification_fp32(input [7:0] exponent, input [22:0] fraction);
        begin
            if (exponent == 8'b0)
                if (fraction == 23'b0)
                    classification_fp32 = ZERO;
                else
                    classification_fp32 = SUBNORMAL;
            else if (exponent == 8'b11111111)
                if (fraction == 23'b0)
                    classification_fp32 = INFINITY;
                else
                    classification_fp32 = NaN;
            else
                classification_fp32 = NORMAL;
        end
        endfunction


    wire [31:0] packed_result;
    reg special_case;
    reg [31:0] special_result;
    wire [31:0] selected_result;

    assign packed_result = pack_fp32(result_sign,final_exponent, final_fraction);

    always @(*) begin
        special_case = 1'b0;
        special_result = 32'b0;
        if(acc_is_nan||(product_class == NaN))begin
            special_case = 1'b1;
            special_result = 32'h7FC00000;
        end
        else if (acc_is_inf) begin
            special_case = 1'b1;
            if((product_class == INFINITY) && (acc_sign != fraction_sign))begin
                special_result = 32'h7FC00000;
            end
            else begin
                special_result = { acc_sign, 8'hFF, 23'b0};
            end
        end
        else if(product_class == INFINITY) begin
            special_case = 1'b1;
            special_result = { fraction_sign, 8'hFF, 23'b0};
        end
        else if(product_class == ZERO)begin
            special_case = 1'b1;
            if(acc_is_zero)
                special_result = 32'b0;
            else
                special_result = acc_in_fp32;
        end
    end

    assign selected_result = special_case? special_result: packed_result;
    always @(posedge clk) begin
        if(rst)
            acc_out_fp32 <=32'b0;
        else if (en)
            acc_out_fp32 <=selected_result; 
    end
endmodule