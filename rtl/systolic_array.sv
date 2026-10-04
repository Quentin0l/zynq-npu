`timescale 1ns / 1ps

// Reseau systolique n_g x n_g output-stationary : C = A x B
// Les donnees doivent arriver deja decalees (skew) :
//   ligne r   : A[r][k] presente au cycle k + r sur a_row_i[r]
//   colonne c : B[k][c] presente au cycle k + c sur b_col_i[c]
// Resultat C[r][c] disponible dans c_o apres 3*n_g - 2 fronts d'horloge.
module systolic_array #(
    parameter n_g      = 4,
    parameter data_w_g = 8,
    parameter acc_w_g  = 32
) (
    input  logic                           clock_i,
    input  logic                           resetb_i,
    input  logic                           clear_i,
    input  logic [n_g*data_w_g-1:0]        a_row_i,  // tranche r = entree de la ligne r
    input  logic [n_g*data_w_g-1:0]        b_col_i,  // tranche c = entree de la colonne c
    output logic [n_g*n_g*acc_w_g-1:0]     c_o       // tranche r*n_g+c = C[r][c]
);

    // Fils horizontaux (a) et verticaux (b) entre PE, bords compris
    /* verilator lint_off UNUSEDSIGNAL */
    logic signed [data_w_g-1:0] a_s [n_g][n_g+1];
    logic signed [data_w_g-1:0] b_s [n_g+1][n_g];
    /* verilator lint_on UNUSEDSIGNAL */

    genvar r, c;
    generate
        for (r = 0; r < n_g; r++) begin : edge_g
            assign a_s[r][0] = a_row_i[r*data_w_g +: data_w_g];
            assign b_s[0][r] = b_col_i[r*data_w_g +: data_w_g];
        end : edge_g

        for (r = 0; r < n_g; r++) begin : row_g
            for (c = 0; c < n_g; c++) begin : col_g
                pe #(
                    .data_w_g (data_w_g),
                    .acc_w_g  (acc_w_g)
                ) pe_u (
                    .clock_i  (clock_i),
                    .resetb_i (resetb_i),
                    .clear_i  (clear_i),
                    .a_i      (a_s[r][c]),
                    .b_i      (b_s[r][c]),
                    .a_o      (a_s[r][c+1]),
                    .b_o      (b_s[r+1][c]),
                    .acc_o    (c_o[(r*n_g+c)*acc_w_g +: acc_w_g])
                );
            end : col_g
        end : row_g
    endgenerate

endmodule : systolic_array
