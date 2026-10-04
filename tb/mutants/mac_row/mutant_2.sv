// Mutant fourni par le parcours : une copie de rtl/moteur/mac_row.sv avec un bug planté.
// Ne l'ouvre pas avant d'avoir écrit tes tests : c'est à eux de le trouver.
`timescale 1ns / 1ps

// Mutant : une copie de mac_row.sv avec UN bug volontaire.
// Ne le lis pas avant d'avoir écrit tes tests.

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

    genvar k;
    generate
        for (k = 0; k < nb_mac_g; k++) begin : g_macs
            mac #(
                .acc_width_g(acc_width_g)
            ) mac_inst (
                .clock_i (clock_i),
                .resetb_i(resetb_i),
                .clear_i ((k == 0) ? clear_i : 1'b0),
                .valid_i (valid_i),
                .a_i     (x_i),
                .b_i     (w_i[8*k +: 8]),
                .acc_o   (acc_o[acc_width_g*k +: acc_width_g])
            );
        end : g_macs
    endgenerate

endmodule : mac_row
