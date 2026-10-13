`timescale 1ns/1ps
module tb_int8_dot;
    localparam integer N = 8;
    logic clk = 0;
    always #5 clk = ~clk;

    logic rst_n = 0, start = 0;
    logic signed [N*8-1:0] a_vec, b_vec;
    logic signed [31:0] bias_in;
    logic busy1, busy2, busy4;
    logic done1, done2, done4;
    logic signed [31:0] sum1, sum2, sum4;
    logic signed [7:0] q1, q2, q4;

    int8_dot_accel #(.VECTOR_LEN(N), .PE_COUNT(1)) p1(
        .clk(clk), .rst_n(rst_n), .start(start),
        .a_vec(a_vec), .b_vec(b_vec), .bias_in(bias_in),
        .busy(busy1), .done(done1), .sum_out(sum1), .q_out(q1));
    int8_dot_accel #(.VECTOR_LEN(N), .PE_COUNT(2)) p2(
        .clk(clk), .rst_n(rst_n), .start(start),
        .a_vec(a_vec), .b_vec(b_vec), .bias_in(bias_in),
        .busy(busy2), .done(done2), .sum_out(sum2), .q_out(q2));
    int8_dot_accel #(.VECTOR_LEN(N), .PE_COUNT(4)) p4(
        .clk(clk), .rst_n(rst_n), .start(start),
        .a_vec(a_vec), .b_vec(b_vec), .bias_in(bias_in),
        .busy(busy4), .done(done4), .sum_out(sum4), .q_out(q4));

    task automatic check_case(
        input logic signed [N*8-1:0] a,
        input logic signed [N*8-1:0] b,
        input logic signed [31:0] bias,
        input logic signed [31:0] expected_sum,
        input logic signed [7:0] expected_q
    );
    begin
        @(negedge clk);
        a_vec = a;
        b_vec = b;
        bias_in = bias;
        start = 1;
        @(negedge clk);
        start = 0;
        // PE=1 finishes last. All result registers persist after done.
        wait(done1 == 1);
        #1;
        if (sum1 !== expected_sum || sum2 !== expected_sum || sum4 !== expected_sum ||
            q1 !== expected_q || q2 !== expected_q || q4 !== expected_q)
            $fatal(1, "FAIL: expected sum=%0d q=%0d; got PE1=%0d/%0d PE2=%0d/%0d PE4=%0d/%0d",
                expected_sum, expected_q, sum1, q1, sum2, q2, sum4, q4);
        $display("PASS: PE=1,2,4; sum=%0d quantized=%0d", expected_sum, expected_q);
    end
    endtask

    initial begin
        #5000;
        $fatal(1, "Simulation timeout");
    end

    initial begin
        a_vec = '0;
        b_vec = '0;
        bias_in = 0;
        repeat (2) @(negedge clk);
        rst_n = 1;

        // Dot = 960, SHIFT=7 -> 7, ReLU remains 7
        check_case({-8'sd5,8'sd15,-8'sd10,8'sd10,-8'sd20,8'sd30,-8'sd10,8'sd20},
                   {-8'sd8,8'sd8,-8'sd8,8'sd8,-8'sd8,8'sd8,-8'sd8,8'sd8},
                   32'sd0, 32'sd960, 8'sd7);

        // All positive 127 values saturate after arithmetic shift.
        check_case({8{8'sd127}}, {8{8'sd127}},
                   32'sd0, 32'sd129032, 8'sd127);

        // Negative result is rectified to zero.
        check_case({8{8'sd127}}, {8{8'sh80}},
                   32'sd0, -32'sd130048, 8'sd0);

        $display("All RTL testbench checks passed.");
        $finish;
    end
endmodule
