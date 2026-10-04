// Mutant fourni par le parcours : une copie de rtl/moteur/mac.sv avec un bug planté.
// Ne l'ouvre pas avant d'avoir écrit tes tests : c'est à eux de le trouver.
`timescale 1ns / 1ps

// Mutant : une copie de mac.sv avec UN bug volontaire.
// Ne le lis pas avant d'avoir écrit tes tests : tout l'intérêt est de trouver
// toi-même quels bugs un banc de test naïf laisse passer.

module mac #(
    parameter acc_width_g = 32
) (
    input  logic                          clock_i,
    input  logic                          resetb_i,
    input  logic                          clear_i,
    input  logic                          valid_i,
    input  logic signed [7:0]             a_i,
    input  logic signed [7:0]             b_i,
    output logic signed [acc_width_g-1:0] acc_o
);

    logic signed [acc_width_g-1:0] acc_s;

    always_ff @(posedge clock_i or negedge resetb_i) begin : seq_0
        if (resetb_i == 1'b0)
            acc_s <= '0;
        else if (valid_i == 1'b1)
            acc_s <= acc_s + a_i * b_i;
        else if (clear_i == 1'b1)
            acc_s <= '0;
    end : seq_0

    assign acc_o = acc_s;

endmodule : mac
