`timescale 1ns / 1ps
// Provenance : exercice 0006 du parcours (fourni).

// =============================================================================
// lut_ram.sv : une petite RAM à lecture ASYNCHRONE. La donnée sort dans le même
// cycle que l'adresse, sans attendre de front. Vivado la construit en RAM
// distribuée, dans les LUT (UG901, tableau 4-1). Fournie : c'est un exemple
// résolu, lis-la. Comparer avec weight_buffer.sv (exercice 0004), lu en synchrone.
//
//   - Écriture synchrone : au front montant, si we_i = 1, ram_s[waddr_i] <= wdata_i.
//   - Lecture asynchrone : rdata_o = ram_s[raddr_i], dans le même cycle.
//   - Pas de reset : comme une BRAM, son contenu ne se remet pas à zéro.
// Elle sert deux fois dans layer_engine.sv : tampon d'activations (8 bits) et
// mémoire des biais (32 bits).
// =============================================================================

module lut_ram #(
    parameter width_g      = 8,
    parameter depth_g      = 1024,
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

    // Port de lecture : combinatoire, aucune latence.
    assign rdata_o = ram_s[raddr_i];

endmodule : lut_ram
