`timescale 1ns / 1ps

// =============================================================================
// systolic_tile.sv : le tableau systolique et ses deux décalages d'entrée.
// Câblage fourni par le parcours (leçon 8).
//
// En entrée, la tuile telle qu'elle est rangée, sans décalage. À chaque cycle k :
//   a_col_i : la colonne k de la tuile A, voie r = A[r][k] (pour la ligne r)
//   b_row_i : la ligne k de la tuile B,   voie c = B[k][c] (pour la colonne c)
// Les deux skew retardent la voie r de r cycles : le tableau reçoit A[r][k] au
// cycle k + r et B[k][c] au cycle k + c, comme le demande son en-tête.
// C[r][c] est complet K + 2*n_g - 2 fronts après le front qui échantillonne
// la première colonne.
// =============================================================================

module systolic_tile #(
    parameter n_g      = 8,
    parameter data_w_g = 8,
    parameter acc_w_g  = 32
) (
    input  logic                       clock_i,
    input  logic                       resetb_i,
    input  logic                       clear_i,
    input  logic [n_g*data_w_g-1:0]    a_col_i,
    input  logic [n_g*data_w_g-1:0]    b_row_i,
    output logic [n_g*n_g*acc_w_g-1:0] c_o
);

    logic [n_g*data_w_g-1:0] a_skew_s;   // voie r : A[r][k] au cycle k + r
    logic [n_g*data_w_g-1:0] b_skew_s;   // voie c : B[k][c] au cycle k + c

    skew #(
        .n_g      (n_g),
        .data_w_g (data_w_g)
    ) skew_a_u (
        .clock_i  (clock_i),
        .resetb_i (resetb_i),
        .data_i   (a_col_i),
        .data_o   (a_skew_s)
    );

    skew #(
        .n_g      (n_g),
        .data_w_g (data_w_g)
    ) skew_b_u (
        .clock_i  (clock_i),
        .resetb_i (resetb_i),
        .data_i   (b_row_i),
        .data_o   (b_skew_s)
    );

    systolic_array #(
        .n_g      (n_g),
        .data_w_g (data_w_g),
        .acc_w_g  (acc_w_g)
    ) array_u (
        .clock_i  (clock_i),
        .resetb_i (resetb_i),
        .clear_i  (clear_i),
        .a_row_i  (a_skew_s),
        .b_col_i  (b_skew_s),
        .c_o      (c_o)
    );

endmodule : systolic_tile
