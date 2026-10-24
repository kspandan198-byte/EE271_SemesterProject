`timescale 1ns/1ps

module FP16_tb;

    logic        clk;
    logic        rst;
    logic        en;
    logic [15:0] a_fp16;
    logic [15:0] b_fp16;
    wire  [31:0] acc;

    FP16_MAC DUT (
        .clk   (clk),
        .rst   (rst),
        .en    (en),
        .a_fp16(a_fp16),
        .b_fp16(b_fp16),
        .acc   (acc)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst    = 1'b1;
        en     = 1'b0;
        a_fp16 = 16'h0000;
        b_fp16 = 16'h0000;

        @(posedge clk);
        #1;

        rst = 1'b0;
        en  = 1'b1;

        // Test 1: 1.0 × 1.0 = 1.0
        a_fp16 = 16'h3C00;
        b_fp16 = 16'h3C00;

        @(posedge clk);
        #1;
        $display("Test 1: 1.0 x 1.0");
        $display("acc = %h, expected = 3F800000",
                 acc);

        // Test 2: previous acc + (2.0 × 2.0)
        // 1.0 + 4.0 = 5.0
        a_fp16 = 16'h4000;
        b_fp16 = 16'h4000;

        @(posedge clk);
        #1;
        $display("Test 2: 2.0 x 2.0");
        $display("acc = %h, expected = 40A00000",
                 acc);

        // Test 3: previous acc + (1.0 × 0.5)
        // 5.0 + 0.5 = 5.5
        a_fp16 = 16'h3C00;
        b_fp16 = 16'h3800;

        @(posedge clk);
        #1;
        $display("Test 3: 1.0 x 0.5");
        $display("acc = %h, expected = 40B00000",
                 acc);

        // Hold test
        en = 1'b0;

        @(posedge clk);
        #1;
        $display("Hold test: acc = %h, expected = 40B00000",
                 acc);

        $finish;
    end
endmodule