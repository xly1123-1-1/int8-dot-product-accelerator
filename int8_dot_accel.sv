// Parameterized INT8 dot-product engine. 1, 2, or 4 MACs per cycle.
// A and B contain VECTOR_LEN signed INT8 values packed little-element-first.
// Inputs are latched on start; done pulses for one cycle when result is valid.
module int8_dot_accel #(
    parameter integer VECTOR_LEN = 8,
    parameter integer PE_COUNT = 2,
    parameter integer SHIFT = 7,
    parameter integer RELU = 1
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic signed [VECTOR_LEN*8-1:0] a_vec,
    input  logic signed [VECTOR_LEN*8-1:0] b_vec,
    input  logic signed [31:0] bias_in,
    output logic busy,
    output logic done,
    output logic signed [31:0] sum_out,
    output logic signed [7:0] q_out
);
    localparam integer INDEX_WIDTH = $clog2(VECTOR_LEN + PE_COUNT + 1);

    logic signed [VECTOR_LEN*8-1:0] a_hold;
    logic signed [VECTOR_LEN*8-1:0] b_hold;
    logic signed [31:0] acc;
    logic [INDEX_WIDTH-1:0] index;
    logic signed [31:0] partial_sum;
    logic signed [31:0] finished_sum;
    logic signed [31:0] shifted_sum;
    logic signed [15:0] product;
    integer k;
    integer elem;

    // Parallel MAC lanes. Unrolled at synthesis time for each PE_COUNT.
    always_comb begin
        partial_sum = 32'sd0;
        product = 16'sd0;
        elem = 0;
        for (integer lane = 0; lane < PE_COUNT; lane = lane + 1) begin
            elem = int'(index) + lane;
            if (elem < VECTOR_LEN) begin
                product = $signed(a_hold[8*elem +: 8]) * $signed(b_hold[8*elem +: 8]);
                partial_sum = partial_sum + {{16{product[15]}}, product};
            end
        end
    end

    assign finished_sum = acc + partial_sum;
    assign shifted_sum = finished_sum >>> SHIFT;

    function automatic logic signed [7:0] quantize(input logic signed [31:0] val);
        logic signed [31:0] after_relu;
        begin
            after_relu = val;
            if (RELU != 0 && val < 0)
                after_relu = 0;
            if (after_relu > 127)
                quantize = 8'sd127;
            else if (after_relu < -128)
                quantize = -8'sd128;
            else
                quantize = after_relu[7:0];
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            done <= 1'b0;
            index <= '0;
            a_hold <= '0;
            b_hold <= '0;
            acc <= 32'sd0;
            sum_out <= 32'sd0;
            q_out <= 8'sd0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                a_hold <= a_vec;
                b_hold <= b_vec;
                acc <= bias_in;
                index <= '0;
                busy <= 1'b1;
            end else if (busy) begin
                if (int'(index) + PE_COUNT >= VECTOR_LEN) begin
                    sum_out <= finished_sum;
                    q_out <= quantize(shifted_sum);
                    busy <= 1'b0;
                    done <= 1'b1;
                end else begin
                    acc <= finished_sum;
                    index <= index + PE_COUNT;
                end
            end
        end
    end
endmodule
