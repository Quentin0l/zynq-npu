// Mutant fourni par le parcours : une copie de rtl/tableau/pe.sv avec un bug planté.
// Ne l'ouvre pas avant d'avoir écrit tes tests : c'est à eux de le trouver.
`timescale 1ns / 1ps

// Processing Element (output-stationary) :
//   acc <= acc + a_i * b_i ; a et b sont retransmis au voisin avec 1 cycle de retard
module pe #(
    parameter data_w_g = 8,
    parameter acc_w_g  = 32
) (
    input  logic                       clock_i,
    input  logic                       resetb_i,
    input  logic                       clear_i,   // remise a zero synchrone de l'accumulateur
    input  logic signed [data_w_g-1:0] a_i,       // depuis le PE de gauche
    input  logic signed [data_w_g-1:0] b_i,       // depuis le PE du haut
    output logic signed [data_w_g-1:0] a_o,       // vers le PE de droite
    output logic signed [data_w_g-1:0] b_o,       // vers le PE du bas
    output logic signed [acc_w_g-1:0]  acc_o
);

    always_ff @(posedge clock_i or negedge resetb_i) begin : seq_0
        if (resetb_i == 1'b0) begin : reset_b
            a_o   <= '0;
            b_o   <= '0;
            acc_o <= '0;
        end : reset_b
        else begin : run_b
            a_o <= a_i;
            b_o <= b_i;
            if (clear_i == 1'b1)
                acc_o <= '0;
            else
                acc_o <= acc_o + $unsigned(a_i) * $unsigned(b_i);
        end : run_b
    end : seq_0

endmodule : pe
