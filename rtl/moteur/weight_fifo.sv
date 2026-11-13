`timescale 1ns / 1ps
// Provenance : ajouté le 2026-11-13 par le parcours, pour les poids de la couche 1
// du réseau réel, qui ne tiennent pas dans les BRAM et arrivent en flux.

// =============================================================================
// weight_fifo.sv : une petite file (FIFO) pour les poids qui arrivent en flux,
// mot après mot, depuis la DDR (plus tard par l'AXI DMA, en S3). Elle absorbe les
// irrégularités du flux : le DMA pousse un mot quand il en a un, le moteur en
// prend un quand il en a besoin.
//
// Spécification.
//   F1. Entrée, poignée de main d'AXI4-Stream : un mot entre au front montant où
//       s_tvalid_i = 1 et s_tready_o = 1. s_tready_o vaut 1 tant que la file
//       n'est pas pleine, et ne dépend que de bascules : aucun chemin
//       combinatoire d'une entrée vers une sortie.
//   F2. Sortie : m_valid_o = 1 tant que la file n'est pas vide. m_data_o est alors
//       le plus ancien mot, lu sans attendre de front. pop_i = 1 le retire au
//       front suivant (sans effet si la file est vide).
//   F3. Les mots sortent dans l'ordre où ils sont entrés.
//   F4. Reset (resetb_i, actif bas) : la file est vide.
// =============================================================================

module weight_fifo #(
    parameter width_g      = 64,
    parameter depth_g      = 16,   // une puissance de deux
    parameter addr_width_g = $clog2(depth_g)
) (
    input  logic               clock_i,
    input  logic               resetb_i,
    // Entrée du flux
    input  logic [width_g-1:0] s_tdata_i,
    input  logic               s_tvalid_i,
    output logic               s_tready_o,
    // Sortie vers le moteur
    output logic [width_g-1:0] m_data_o,
    output logic               m_valid_o,
    input  logic               pop_i
);

    localparam logic [addr_width_g:0] plein_p = depth_g;

    logic [width_g-1:0]    mem_s [depth_g];
    // Un bit de plus que l'adresse : il distingue « pleine » de « vide ».
    logic [addr_width_g:0] wr_s;
    logic [addr_width_g:0] rd_s;
    logic                  push_s;
    logic                  pop_s;

    assign s_tready_o = ((wr_s - rd_s) != plein_p);
    assign m_valid_o  = (wr_s != rd_s);
    assign push_s     = s_tvalid_i && s_tready_o;
    assign pop_s      = pop_i && m_valid_o;
    assign m_data_o   = mem_s[rd_s[addr_width_g-1:0]];

    // La mémoire : pas de reset, comme les autres tampons.
    always_ff @(posedge clock_i) begin : seq_mem
        if (push_s == 1'b1)
            mem_s[wr_s[addr_width_g-1:0]] <= s_tdata_i;
    end : seq_mem

    // Les deux pointeurs.
    always_ff @(posedge clock_i or negedge resetb_i) begin : seq_ptr
        if (resetb_i == 1'b0) begin : raz
            wr_s <= '0;
            rd_s <= '0;
        end : raz
        else begin : avance
            if (push_s == 1'b1)
                wr_s <= wr_s + 1'b1;
            if (pop_s == 1'b1)
                rd_s <= rd_s + 1'b1;
        end : avance
    end : seq_ptr

endmodule : weight_fifo
