`timescale 1ns / 1ps
// Provenance : exercice 0001 du parcours (spécification fournie, TODO écrits par l'auteur du dépôt).

// =============================================================================
// mac.sv : multiplieur-accumulateur (MAC) int8 x int8, première brique du NPU.
//
// Spécification. Les tests la vérifient à la lettre.
//   S1. resetb_i = 0 (asynchrone, actif bas)           : acc_o <= 0
//   S2. front montant avec clear_i = 1                  : acc_o <= 0
//       (clear_i est PRIORITAIRE sur valid_i)
//   S3. front montant avec valid_i = 1 (et clear_i = 0) : acc_o <= acc_o + a_i * b_i
//   S4. sinon                                           : acc_o garde sa valeur
//   a_i et b_i sont des entiers SIGNÉS sur 8 bits (complément à 2).
//   acc_o est un entier signé sur acc_width_g bits : les 16 bits d'un produit,
//   plus des bits de garde pour que la somme ne déborde pas.
// =============================================================================

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

    // Registre accumulateur : la somme partielle reste ici, dans le MAC,
    // au lieu de repartir en mémoire à chaque produit.
    logic signed [acc_width_g-1:0] acc_s;

    // -------------------------------------------------------------------------
    // TODO 1 : décris le registre accumulateur dans un processus seq_0
    //          (always_ff), en appliquant S1, S2, S3, S4 dans cet ordre.
    //          Supprime la ligne « assign acc_s = '0; » ci-dessous : tant
    //          qu'elle est là, l'accumulateur reste bloqué à 0.
    // -------------------------------------------------------------------------

    always_ff@(posedge clock_i, negedge resetb_i) begin: seq_0
        if (resetb_i == 1'b0)
            acc_s <= '0;
        else if (clear_i == 1'b1)
            acc_s <= '0;
        else if (valid_i ==1'b1 ) 
            acc_s <= acc_s + a_i * b_i;
    end : seq_0

    assign acc_o = acc_s;

endmodule : mac
