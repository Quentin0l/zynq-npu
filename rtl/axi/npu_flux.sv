`timescale 1ns / 1ps
// Provenance : leçon 6 du parcours « NPU sur ZedBoard » (spécification et ports
// fournis ; le corps, TODO, à écrire par l'auteur du dépôt).

// =============================================================================
// npu_flux.sv : l'aiguillage du flux entrant (S_AXIS, le canal MM2S du DMA).
// Le registre FLUX choisit la destination des mots de 64 bits qui arrivent.
//
// Spécification.
//   F1. FLUX = 0, BOUCLE : le flux ressort tel quel sur M_AXIS, comme dans la
//       version 1.0 (m_t*_o = s_t*_i, s_tready_o = m_tready_i). Pour tester le DMA.
//   F2. FLUX = 1, TAMPON : chaque mot accepté s'écrit dans le tampon de poids,
//       à l'adresse du compteur, qui avance ensuite de 1. Le tampon prend un mot
//       par cycle : s_tready_o = 1. Écriture : w_we_o = s_tvalid_i,
//       w_waddr_o = le compteur, w_wdata_o = s_tdata_i.
//   F3. FLUX = 2, FILE : le flux va à la file de poids de la couche en flux
//       (ws_tdata_o = s_tdata_i, ws_tvalid_o = s_tvalid_i, s_tready_o = ws_tready_i).
//   F4. FLUX = 3 : réservé. Rien ne passe : s_tready_o = 0.
//   F5. Hors de son mode, chaque sortie reste muette : m_tvalid_o = 0 sauf en
//       BOUCLE, ws_tvalid_o = 0 sauf en FILE, w_we_o = 0 sauf en TAMPON.
//       Les données (m_tdata_o, ws_tdata_o, w_wdata_o) peuvent suivre s_tdata_i
//       en permanence : seuls les VALID et les WE comptent.
//   F6. Le compteur d'adresse : addr_load_i = 1 le charge avec addr_val_i
//       (prioritaire) ; sinon, il avance de 1 à chaque mot écrit (w_we_o = 1).
//       Reset asynchrone actif bas : 0. w_addr_o le rend lisible par l'ARM
//       (registre W_ADDR) : après un chargement, il vaut l'adresse du mot suivant.
//   TLAST et TKEEP ne servent qu'en BOUCLE : ailleurs, ils sont ignorés.
// =============================================================================

module npu_flux #(
    parameter w_addr_width_g = 15
) (
    input  logic                      clock_i,
    input  logic                      resetb_i,
    input  logic [1:0]                flux_i,        // registre FLUX
    input  logic                      addr_load_i,   // l'ARM écrit W_ADDR
    input  logic [w_addr_width_g-1:0] addr_val_i,    // ... avec cette valeur
    output logic [w_addr_width_g-1:0] w_addr_o,      // le compteur, relu par W_ADDR
    // S_AXIS : le flux entrant
    input  logic [63:0]               s_tdata_i,
    input  logic [7:0]                s_tkeep_i,
    input  logic                      s_tlast_i,
    input  logic                      s_tvalid_i,
    output logic                      s_tready_o,
    // M_AXIS : la boucle de retour (F1)
    output logic [63:0]               m_tdata_o,
    output logic [7:0]                m_tkeep_o,
    output logic                      m_tlast_o,
    output logic                      m_tvalid_o,
    input  logic                      m_tready_i,
    // La file de poids du moteur (F3)
    output logic [63:0]               ws_tdata_o,
    output logic                      ws_tvalid_o,
    input  logic                      ws_tready_i,
    // Le port d'écriture du tampon de poids (F2)
    output logic                      w_we_o,
    output logic [w_addr_width_g-1:0] w_waddr_o,
    output logic [63:0]               w_wdata_o
);

    localparam logic [1:0] boucle_p = 2'd0;
    localparam logic [1:0] tampon_p = 2'd1;
    localparam logic [1:0] file_p   = 2'd2;

    logic [w_addr_width_g-1:0] addr_s;   // le compteur d'adresse (F6)

    // -------------------------------------------------------------------------
    // TODO 1 : les données, recopiées en permanence (F5) : m_tdata_o, m_tkeep_o,
    //          m_tlast_o, ws_tdata_o, w_wdata_o ; et w_waddr_o, w_addr_o = addr_s.
    // TODO 2 : l'aiguillage, dans un processus comb_aiguillage (always_comb) :
    //          valeurs par défaut muettes (F5), puis un case sur flux_i (F1 à F4).
    // TODO 3 : le compteur addr_s, dans un processus seq_adresse (F6).
    // Supprime les lignes « assign … » ci-dessous.
    // -------------------------------------------------------------------------

    // TODO 1 : les données, recopiées en permanence (F5)
    assign m_tdata_o  = s_tdata_i;
    assign m_tkeep_o  = s_tkeep_i;
    assign m_tlast_o  = s_tlast_i;
    assign ws_tdata_o = s_tdata_i;
    assign w_wdata_o  = s_tdata_i;
    assign w_waddr_o  = addr_s;
    assign w_addr_o   = addr_s;

    // TODO 2 : l'aiguillage
    always_comb begin : comb_aiguillage
        // F5 : tout est muet par défaut ; chaque mode n'ouvre que son chemin.
        m_tvalid_o  = 1'b0;
        ws_tvalid_o = 1'b0;
        w_we_o      = 1'b0;
        s_tready_o  = 1'b0;
        case (flux_i)
            boucle_p: begin              // F1 : comme la boucle de la version 1
                m_tvalid_o = s_tvalid_i;
                s_tready_o = m_tready_i;
            end
            tampon_p: begin              // F2 : le tampon accepte un mot par cycle
                w_we_o     = s_tvalid_i;
                s_tready_o = 1'b1;
            end
            file_p: begin                // F3 : c'est la file qui décide
                ws_tvalid_o = s_tvalid_i;
                s_tready_o  = ws_tready_i;
            end
            default: ;                   // F4 : FLUX = 3, rien ne passe
        endcase
    end : comb_aiguillage

    // TODO 3 : le compteur d'adresse (F6)
    always_ff @(posedge clock_i or negedge resetb_i) begin : seq_adresse
        if (resetb_i == 1'b0)
            addr_s <= '0;
        else if (addr_load_i == 1'b1)
            addr_s <= addr_val_i;
        else if (w_we_o == 1'b1)
            addr_s <= addr_s + 1'b1;
    end : seq_adresse
endmodule : npu_flux
