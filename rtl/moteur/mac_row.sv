`timescale 1ns / 1ps
// Provenance : exercice 0003 du parcours (spécification fournie, TODO écrit par l'auteur du dépôt).

// =============================================================================
// mac_row.sv : une rangée de nb_mac_g MAC, en dataflow output-stationary.
// Chaque MAC calcule UNE sortie de la couche : y[k] = somme sur j de W[k][j] * x[j].
//
// Spécification. Les tests la vérifient à la lettre.
//   R1. Le MAC k reçoit l'entrée x_i, la même pour tous (elle est diffusée),
//       et l'octet k de w_i : w_i[8k+7 : 8k]. L'octet 0 (bits 7:0) va au MAC 0.
//   R2. L'accumulateur du MAC k sort sur le champ k de acc_o :
//       acc_o[acc_width_g*(k+1)-1 : acc_width_g*k].
//   R3. clock_i, resetb_i, clear_i et valid_i vont à TOUS les MAC.
//   Chaque MAC est ton mac.sv de l'exercice 0001, réutilisé tel quel.
// =============================================================================

module mac_row #(
    parameter nb_mac_g    = 8,
    parameter acc_width_g = 32
) (
    input  logic                            clock_i,
    input  logic                            resetb_i,
    input  logic                            clear_i,
    input  logic                            valid_i,
    input  logic signed [7:0]               x_i,
    input  logic [nb_mac_g*8-1:0]           w_i,
    output logic [nb_mac_g*acc_width_g-1:0] acc_o
);

    // -------------------------------------------------------------------------
    // TODO 1 : instancie nb_mac_g fois ton module mac, dans une boucle generate
    //          labellée g_macs, avec une instanciation par nom.
    //          Pour découper un vecteur, utilise la tranche indexée +: :
    //          w_i[8*k +: 8] désigne les 8 bits qui commencent au bit 8*k.
    //          Supprime la ligne « assign acc_o = '0; » ci-dessous.
    // -------------------------------------------------------------------------

    //logic signed [7:0] w_s;
    //logic [acc_width_g-1:0] acc_s;
    genvar i;
    generate 
        for (i=0; i<nb_mac_g; i++) begin: g_macs
            //assign w_s = w_i[8*(i+1) -1: 8*i];
            
            mac mac_i(
                .clock_i(clock_i),
                .resetb_i(resetb_i),
                .clear_i(clear_i),
                .valid_i(valid_i),
                .a_i(x_i),
                .b_i  (w_i[8*i +: 8]),
                .acc_o(acc_o[acc_width_g*i +: acc_width_g])
            );
            //assign acc_o = {acc_o, acc_s};
        end: g_macs
    endgenerate

endmodule : mac_row
