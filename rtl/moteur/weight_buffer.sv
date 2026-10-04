`timescale 1ns / 1ps
// Provenance : exercice 0004 du parcours (fourni : modèle de BRAM d'UG901).

// =============================================================================
// weight_buffer.sv : le tampon de poids. Une RAM double port simple (un port
// d'écriture, un port de lecture) que Vivado place en block RAM.
// D'après le modèle « Simple Dual-Port Block RAM with Single Clock » de UG901
// (v2022.2, chapitre 4). Fourni tel quel : c'est un exemple résolu, lis-le.
//
//   - Écriture synchrone : au front montant, si we_i = 1, ram_s[waddr_i] <= wdata_i.
//   - Lecture synchrone : au front montant, rdata_o <= ram_s[raddr_i].
//     La donnée sort donc UN CYCLE après l'adresse. C'est cette lecture synchrone
//     qui permet à Vivado d'utiliser une BRAM. Une lecture asynchrone
//     (assign rdata_o = ram_s[raddr_i];) l'obligerait à prendre de la RAM
//     distribuée, en LUT (UG901, tableau 4-1).
//   - Pas de reset : le contenu d'une BRAM ne se remet pas à zéro, il est
//     initialisé par le bitstream (UG473). Exception assumée aux conventions.
// =============================================================================

module weight_buffer #(
    parameter width_g      = 64,
    parameter depth_g      = 2048,
    parameter addr_width_g = $clog2(depth_g)
) (
    input  logic                    clock_i,
    input  logic                    we_i,
    input  logic [addr_width_g-1:0] waddr_i,
    input  logic [width_g-1:0]      wdata_i,
    input  logic [addr_width_g-1:0] raddr_i,
    output logic [width_g-1:0]      rdata_o
);

    logic [width_g-1:0] ram_s [depth_g];

    // Port d'écriture.
    always_ff @(posedge clock_i) begin : seq_write
        if (we_i == 1'b1)
            ram_s[waddr_i] <= wdata_i;
    end : seq_write

    // Port de lecture : la donnée sort un cycle après l'adresse.
    always_ff @(posedge clock_i) begin : seq_read
        rdata_o <= ram_s[raddr_i];
    end : seq_read

endmodule : weight_buffer
