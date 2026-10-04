`timescale 1ns / 1ps
// Provenance : exercice 0005 du parcours (spécification fournie, TODO écrit par l'auteur du dépôt).

// =============================================================================
// requant.sv : l'unité de requantification. Elle ramène la somme 32 bits d'un
// MAC à un int8, prêt pour la couche suivante. Purement combinatoire (pour
// l'instant) : la sortie suit les entrées sans horloge.
//
// Spécification. Les tests la vérifient à la lettre.
// Toute l'arithmétique interne se fait sur 64 bits SIGNÉS.
//   Q1. v = acc_i + bias_i                 (bias_i : le biais corrigé, en int32)
//   Q2. p = v * m0_i                        (m0_i : le multiplicateur entier, dans [2^30, 2^31))
//   Q3. s = 31 + shift_i ;  r = (p + 2^(s-1)) >>> s
//       Arrondi au plus proche (les demis vers le haut), puis décalage ARITHMÉTIQUE.
//   Q4. y = r + zp_i                        (zp_i : le point zéro de la sortie)
//   Q5. Saturation : q_o = y écrêté dans [plancher, 127], où
//       plancher = zp_i si relu_i = 1 (ReLU), et -128 sinon.
//   Domaine d'emploi : |acc_i + bias_i| < 2^31, et shift_i ≤ 31.
// =============================================================================

module requant (
    input  logic signed [31:0] acc_i,
    input  logic signed [31:0] bias_i,
    input  logic signed [31:0] m0_i,
    input  logic        [4:0]  shift_i,
    input  logic signed [7:0]  zp_i,
    input  logic               relu_i,
    output logic signed [7:0]  q_o
);

    // Signaux internes sur 64 bits signés, déjà déclarés pour toi.
    logic signed [63:0] v_s;         // Q1
    logic signed [63:0] p_s;         // Q2
    logic signed [63:0] r_s;         // Q3
    logic signed [63:0] y_s;         // Q4
    logic signed [63:0] plancher_s;  // Q5

    // -------------------------------------------------------------------------
    // TODO 1 : un processus combinatoire comb_0 (always_comb) qui calcule
    //          v_s, p_s, r_s, y_s, plancher_s, puis q_o, selon Q1 à Q5.
    //          Pour étendre un signal signé à 64 bits : 64'(acc_i).
    //          Supprime la ligne « assign q_o = '0; » ci-dessous.
    // -------------------------------------------------------------------------

    always_comb begin: comb_0
         v_s = 64'(acc_i) + 64'(bias_i);
         p_s = v_s * m0_i;
         r_s = (p_s + 2**(31 + shift_i-1)) >>> (31 + shift_i);
         y_s = r_s + 64'(zp_i);        
        plancher_s = (relu_i == 1'b1) ? 64'(zp_i) : -64'sd128;
        q_o = (y_s > 64'sd127)  ? 8'sd127 : (y_s < plancher_s) ? plancher_s[7:0] :y_s[7:0];

        

    end : comb_0
     

endmodule : requant
