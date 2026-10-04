// Mutant fourni par le parcours : une copie de rtl/moteur/requant.sv avec un bug planté.
// Ne l'ouvre pas avant d'avoir écrit tes tests : c'est à eux de le trouver.
`timescale 1ns / 1ps

// Mutant : une copie de requant.sv avec UN bug volontaire.
// Ne le lis pas avant d'avoir écrit tes tests.

module requant (
    input  logic signed [31:0] acc_i,
    input  logic signed [31:0] bias_i,
    input  logic signed [31:0] m0_i,
    input  logic        [4:0]  shift_i,
    input  logic signed [7:0]  zp_i,
    input  logic               relu_i,
    output logic signed [7:0]  q_o
);

    logic signed [63:0] v_s;
    logic signed [63:0] p_s;
    logic signed [63:0] r_s;
    logic signed [63:0] y_s;
    logic signed [63:0] plancher_s;

    always_comb begin : comb_0
        v_s        = 64'(acc_i) + 64'(bias_i);
        p_s        = v_s * 64'(m0_i);
        r_s        = (p_s + (64'sd1 <<< (30 + shift_i))) >>> (31 + shift_i);
        y_s        = r_s + 64'(zp_i);
        plancher_s = (relu_i == 1'b1) ? 64'(zp_i) : -64'sd128;
        q_o = 8'(y_s);
    end : comb_0

endmodule : requant
