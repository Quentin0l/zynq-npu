// Mutant fourni par le parcours : une copie de rtl/moteur/pass_engine.sv avec un bug planté.
// Ne l'ouvre pas avant d'avoir écrit tes tests : c'est à eux de le trouver.
`timescale 1ns / 1ps

// Mutant : une copie de pass_engine.sv avec UN bug volontaire.
// Ne le lis pas avant d'avoir écrit tes tests.

module pass_engine #(
    parameter nb_mac_g     = 8,
    parameter acc_width_g  = 32,
    parameter depth_g      = 2048,
    parameter addr_width_g = $clog2(depth_g)
) (
    input  logic                            clock_i,
    input  logic                            resetb_i,
    // Chargement des poids (le rôle de l'ARM, plus tard)
    input  logic                            we_i,
    input  logic [addr_width_g-1:0]         waddr_i,
    input  logic [nb_mac_g*8-1:0]           wdata_i,
    // Pilotage d'une passe
    input  logic                            clear_i,
    input  logic [addr_width_g-1:0]         base_i,
    input  logic                            valid_i,
    input  logic signed [7:0]               x_i,
    // Résultats : un champ de acc_width_g bits par MAC
    output logic [nb_mac_g*acc_width_g-1:0] acc_o
);

    logic [addr_width_g-1:0] raddr_s;
    logic [nb_mac_g*8-1:0]   rdata_s;
    logic signed [7:0]       x_d_s;
    logic                    valid_d_s;
    logic                    clear_d_s;

    always_ff @(posedge clock_i or negedge resetb_i) begin : seq_0
        if (resetb_i == 1'b0)
            raddr_s <= '0;
        else if (clear_i == 1'b1)
            raddr_s <= '0;
        else if (valid_i == 1'b1)
            raddr_s <= raddr_s + 1'b1;
    end : seq_0

    always_ff @(posedge clock_i or negedge resetb_i) begin : seq_1
        if (resetb_i == 1'b0) begin : raz
            x_d_s     <= '0;
            valid_d_s <= 1'b0;
            clear_d_s <= 1'b0;
        end : raz
        else begin : retard
            x_d_s     <= x_i;
            valid_d_s <= valid_i;
            clear_d_s <= clear_i;
        end : retard
    end : seq_1

    weight_buffer #(
        .width_g(nb_mac_g*8),
        .depth_g(depth_g)
    ) buffer_inst (
        .clock_i(clock_i),
        .we_i   (we_i),
        .waddr_i(waddr_i),
        .wdata_i(wdata_i),
        .raddr_i(raddr_s),
        .rdata_o(rdata_s)
    );

    mac_row #(
        .nb_mac_g   (nb_mac_g),
        .acc_width_g(acc_width_g)
    ) row_inst (
        .clock_i (clock_i),
        .resetb_i(resetb_i),
        .clear_i (clear_d_s),
        .valid_i (valid_d_s),
        .x_i     (x_d_s),
        .w_i     (rdata_s),
        .acc_o   (acc_o)
    );

endmodule : pass_engine
