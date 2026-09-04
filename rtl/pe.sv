module pe (
    input  logic        clk, rst,
    input  logic signed [7:0]  in_a,
    input  logic signed [7:0]  in_b,
    output logic signed [7:0]  out_a,
    output logic signed [7:0]  out_b,
    output logic signed [31:0] acc
);
    always_ff @(posedge clk) begin
        if (rst) begin
            out_a <= 0; out_b <= 0; acc <= 0;
        end else begin
            out_a <= in_a;
            out_b <= in_b;
            acc   <= acc + (in_a * in_b);
        end
    end
endmodule