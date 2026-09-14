`timescale 1ns/1ps
//
// Standalone requant test. requant is purely combinational, so there is no
// clock here - drive the inputs, let them settle, compare.
//
// Vectors come from tb.py. NCASES must match the number of cases it emits;
// it prints the count and a legend when you run it.
//
module tb_requant;
    localparam int N      = 16;
    localparam int NCASES = 12;

    // DUT interface
    logic signed [31:0] acc     [0:N-1];
    logic signed [31:0] bias    [0:N-1];
    logic signed [31:0] m;
    logic        [7:0]  s;
    logic               relu_en;
    logic signed [7:0]  out_8   [0:N-1];

    requant dut (
        .out_32  (acc),
        .bias    (bias),
        .m       (m),
        .s       (s),
        .relu_en (relu_en),
        .out_8   (out_8)
    );

    // vector storage
    logic [31:0] acc_mem  [0:NCASES*N-1];
    logic [31:0] bias_mem [0:NCASES*N-1];
    logic [31:0] m_mem    [0:NCASES-1];
    logic [7:0]  s_mem    [0:NCASES-1];
    logic [7:0]  relu_mem [0:NCASES-1];
    logic [7:0]  exp_mem  [0:NCASES*N-1];

    int c, j, base;
    int case_errors, total_errors, cases_failed;

    initial begin
        $readmemh("rq_acc.hex",  acc_mem);
        $readmemh("rq_bias.hex", bias_mem);
        $readmemh("rq_m.hex",    m_mem);
        $readmemh("rq_s.hex",    s_mem);
        $readmemh("rq_relu.hex", relu_mem);
        $readmemh("rq_exp.hex",  exp_mem);

        total_errors = 0;
        cases_failed = 0;

        for (c = 0; c < NCASES; c++) begin
            base = c * N;

            m       = $signed(m_mem[c]);
            s       = s_mem[c];
            relu_en = relu_mem[c][0];
            for (j = 0; j < N; j++) begin
                acc[j]  = $signed(acc_mem[base + j]);
                bias[j] = $signed(bias_mem[base + j]);
            end

            #1;  // combinational settle

            case_errors = 0;
            for (j = 0; j < N; j++) begin
                if (out_8[j] !== $signed(exp_mem[base + j])) begin
                    if (case_errors < 4)
                        $display("  case %0d lane %0d: acc=%0d bias=%0d m=%0d s=%0d relu=%0b -> got %0d exp %0d",
                                 c, j,
                                 $signed(acc_mem[base + j]),
                                 $signed(bias_mem[base + j]),
                                 $signed(m_mem[c]), s_mem[c], relu_mem[c][0],
                                 out_8[j], $signed(exp_mem[base + j]));
                    case_errors++;
                end
            end

            if (case_errors) begin
                $display("case %0d FAIL (%0d/%0d lanes)", c, case_errors, N);
                cases_failed++;
            end else begin
                $display("case %0d pass", c);
            end
            total_errors += case_errors;
        end

        $display("--------------------------------------------------");
        if (total_errors)
            $display("REQUANT FAIL: %0d lanes across %0d/%0d cases",
                     total_errors, cases_failed, NCASES);
        else
            $display("REQUANT PASS: %0d cases, %0d lanes", NCASES, NCASES*N);

        $finish;
    end
endmodule