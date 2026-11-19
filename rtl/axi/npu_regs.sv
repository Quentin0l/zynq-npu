`timescale 1ns / 1ps
// Provenance : leçon 2 (poignée de main AXI4-Lite, SCRATCH, CYCLES), puis leçon 6
// du parcours « NPU sur ZedBoard » (carte des registres, descripteur et lecture
// fournis ; TODO A et B, la commande et les fenêtres, à écrire par l'auteur du dépôt).

// =============================================================================
// npu_regs.sv : les registres du NPU, version 2. Un esclave AXI4-Lite (32 bits de
// données, 12 bits d'adresse) qui pilote le moteur : commande, descripteur de la
// couche, chargement des biais et des activations, lecture des sorties.
//
//   | Offset | Nom       | Accès | Contenu                                           |
//   |--------|-----------|-------|---------------------------------------------------|
//   | 0x00   | VERSION   | L     | 0x4E50_5502 : « NPU », version 02                 |
//   | 0x04   | SCRATCH   | L/É   | comme en version 1                                |
//   | 0x08   | CYCLES    | L     | comme en version 1                                |
//   | 0x0C   | CTRL      | É     | bit 0 : START                                     |
//   | 0x10   | STATUS    | L     | bit 0 : BUSY, bit 1 : DONE                        |
//   | 0x14   | DUREE     | L     | cycles de la dernière couche (BUSY = 1)           |
//   | 0x18   | FLUX      | L/É   | destination de S_AXIS : 0 BOUCLE, 1 TAMPON, 2 FILE|
//   | 0x1C   | W_ADDR    | L/É   | prochaine adresse du tampon de poids (TAMPON)     |
//   | 0x20   | BIAS_ADDR | L/É   | prochaine adresse de biais                        |
//   | 0x24   | BIAS_DATA | É     | fenêtre : écrit un biais int32                    |
//   | 0x28   | ACT_ADDR  | L/É   | prochaine adresse du tampon d'activations         |
//   | 0x2C   | ACT_DATA  | L/É   | fenêtre : un octet signé du tampon d'activations  |
//   | 0x30   | N         | L/É   | descripteur : nombre d'entrées                    |
//   | 0x34   | M         | L/É   | descripteur : nombre de sorties                   |
//   | 0x38   | W_BASE    | L/É   | descripteur : première tuile dans le tampon       |
//   | 0x3C   | IN_BASE   | L/É   | descripteur : zone des entrées                    |
//   | 0x40   | OUT_BASE  | L/É   | descripteur : zone des sorties                    |
//   | 0x44   | BIAS_BASE | L/É   | descripteur : premier biais de la couche          |
//   | 0x48   | M0        | L/É   | descripteur : multiplicateur (2^30 avec AIfES)    |
//   | 0x4C   | SHIFT     | L/É   | descripteur : décalage                            |
//   | 0x50   | ZP        | L/É   | descripteur : point zéro de la sortie (signé)     |
//   | 0x54   | OPTIONS   | L/É   | descripteur : bit 0 RELU, bit 1 W_STREAM          |
//
//   R1 à R5 : comme en version 1 (VERSION, SCRATCH, CYCLES, adresses inconnues
//   lues à 0, réponses OKAY). Les champs trop courts sont tronqués à l'écriture,
//   et lus avec des zéros devant (ZP et ACT_DATA : étendus avec leur signe).
//   R6. START : une écriture acceptée dans CTRL avec wdata_i[0] = 1 met start_o à 1
//       pendant ce seul cycle, sauf si busy_i = 1 : elle est alors ignorée.
//   R7. DONE passe à 1 au cycle où done_i = 1, et revient à 0 au START suivant.
//       STATUS se lit {30'b0, DONE, busy_i}.
//   R8. DUREE : remise à 0 au START, puis + 1 à chaque cycle où busy_i = 1.
//       Elle vaut T(n+2)+m+1 sans bulle (de CLEAR à DONE compris).
//   R9. BIAS_DATA : une écriture acceptée met bias_we_o à 1 pendant ce cycle
//       (le biais wdata_i, à l'adresse BIAS_ADDR), puis BIAS_ADDR + 1.
//       Une écriture dans BIAS_ADDR fixe l'adresse.
//   R10. ACT_DATA : une écriture acceptée met act_we_o à 1 pendant ce cycle (l'octet
//       wdata_i[7:0], à l'adresse ACT_ADDR), sauf si busy_i = 1 : le séquenceur tient
//       alors le tampon. Une lecture acceptée rend l'octet à ACT_ADDR. Chacune fait
//       ensuite ACT_ADDR + 1 (+ 2 si les deux tombent au même cycle). Une écriture
//       dans ACT_ADDR fixe l'adresse, et l'emporte.
//   R11. WSTRB ne compte que pour SCRATCH : les autres registres s'écrivent en entier.
//   Le descripteur doit rester stable de START à DONE : c'est à l'ARM d'y veiller.
// =============================================================================

module npu_regs #(
    parameter addr_width_g      = 12,
    parameter version_g         = 32'h4E50_5502,
    parameter dim_width_g       = 10,
    parameter w_addr_width_g    = 15,
    parameter act_addr_width_g  = 11,
    parameter bias_addr_width_g = 10
) (
    input  logic                         clock_i,
    input  logic                         resetb_i,
    input  logic [addr_width_g-1:0]      awaddr_i,
    input  logic                         awvalid_i,
    output logic                         awready_o,
    input  logic [31:0]                  wdata_i,
    input  logic [3:0]                   wstrb_i,
    input  logic                         wvalid_i,
    output logic                         wready_o,
    output logic [1:0]                   bresp_o,
    output logic                         bvalid_o,
    input  logic                         bready_i,
    input  logic [addr_width_g-1:0]      araddr_i,
    input  logic                         arvalid_i,
    output logic                         arready_o,
    output logic [31:0]                  rdata_o,
    output logic [1:0]                   rresp_o,
    output logic                         rvalid_o,
    input  logic                         rready_i,
    output logic                         start_o,
    input  logic                         busy_i,
    input  logic                         done_i,
    output logic [1:0]                   flux_o,
    output logic                         w_addr_load_o,
    output logic [w_addr_width_g-1:0]    w_addr_val_o,
    input  logic [w_addr_width_g-1:0]    w_addr_i,
    output logic                         bias_we_o,
    output logic [bias_addr_width_g-1:0] bias_waddr_o,
    output logic signed [31:0]           bias_wdata_o,
    output logic                         act_we_o,
    output logic [act_addr_width_g-1:0]  act_waddr_o,
    output logic signed [7:0]            act_wdata_o,
    output logic [act_addr_width_g-1:0]  act_raddr_o,
    input  logic signed [7:0]            act_rdata_i,
    output logic [dim_width_g-1:0]       n_o,
    output logic [dim_width_g-1:0]       m_o,
    output logic [w_addr_width_g-1:0]    w_base_o,
    output logic [act_addr_width_g-1:0]  in_base_o,
    output logic [act_addr_width_g-1:0]  out_base_o,
    output logic [bias_addr_width_g-1:0] bias_base_o,
    output logic signed [31:0]           m0_o,
    output logic        [4:0]            shift_o,
    output logic signed [7:0]            zp_o,
    output logic                         relu_o,
    output logic                         w_stream_o
);
    typedef logic [addr_width_g-3:0] mot_t;
    localparam mot_t version_p   = 'h00 >> 2;
    localparam mot_t scratch_p   = 'h04 >> 2;
    localparam mot_t cycles_p    = 'h08 >> 2;
    localparam mot_t ctrl_p      = 'h0C >> 2;
    localparam mot_t status_p    = 'h10 >> 2;
    localparam mot_t duree_p     = 'h14 >> 2;
    localparam mot_t flux_p      = 'h18 >> 2;
    localparam mot_t w_addr_p    = 'h1C >> 2;
    localparam mot_t bias_addr_p = 'h20 >> 2;
    localparam mot_t bias_data_p = 'h24 >> 2;
    localparam mot_t act_addr_p  = 'h28 >> 2;
    localparam mot_t act_data_p  = 'h2C >> 2;
    localparam mot_t n_p         = 'h30 >> 2;
    localparam mot_t m_p         = 'h34 >> 2;
    localparam mot_t w_base_p    = 'h38 >> 2;
    localparam mot_t in_base_p   = 'h3C >> 2;
    localparam mot_t out_base_p  = 'h40 >> 2;
    localparam mot_t bias_base_p = 'h44 >> 2;
    localparam mot_t m0_p        = 'h48 >> 2;
    localparam mot_t shift_p     = 'h4C >> 2;
    localparam mot_t zp_p        = 'h50 >> 2;
    localparam mot_t options_p   = 'h54 >> 2;

    logic  wr_go_s, rd_go_s;
    mot_t  wr_mot_s, rd_mot_s;
    logic [31:0] lecture_s, scratch_s, cycles_s, duree_s;
    logic  done_s;
    logic [bias_addr_width_g-1:0] bias_addr_s;
    logic [act_addr_width_g-1:0]  act_addr_s;
    logic  act_rd_s;

    assign wr_go_s   = awvalid_i & wvalid_i & (~bvalid_o | bready_i);
    assign awready_o = wr_go_s;
    assign wready_o  = wr_go_s;
    assign bresp_o   = 2'b00;
    assign wr_mot_s  = awaddr_i[addr_width_g-1:2];
    always_ff @(posedge clock_i or negedge resetb_i) begin : seq_b
        if (resetb_i == 1'b0)          bvalid_o <= 1'b0;
        else if (wr_go_s == 1'b1)      bvalid_o <= 1'b1;
        else if (bready_i == 1'b1)     bvalid_o <= 1'b0;
    end : seq_b

    assign rd_go_s   = arvalid_i & (~rvalid_o | rready_i);
    assign arready_o = rd_go_s;
    assign rresp_o   = 2'b00;
    assign rd_mot_s  = araddr_i[addr_width_g-1:2];
    always_ff @(posedge clock_i or negedge resetb_i) begin : seq_r
        if (resetb_i == 1'b0) begin
            rvalid_o <= 1'b0;
            rdata_o  <= '0;
        end
        else if (rd_go_s == 1'b1) begin
            rvalid_o <= 1'b1;
            rdata_o  <= lecture_s;
        end
        else if (rready_i == 1'b1)
            rvalid_o <= 1'b0;
    end : seq_r

    // SCRATCH, CYCLES (version 1, fourni).
    always_ff @(posedge clock_i or negedge resetb_i) begin : seq_scratch
        if (resetb_i == 1'b0)
            scratch_s <= '0;
        else if (wr_go_s == 1'b1 && wr_mot_s == scratch_p)
            for (int b = 0; b < 4; b++)
                if (wstrb_i[b] == 1'b1) scratch_s[8*b +: 8] <= wdata_i[8*b +: 8];
    end : seq_scratch
    always_ff @(posedge clock_i or negedge resetb_i) begin : seq_cycles
        if (resetb_i == 1'b0) cycles_s <= '0;
        else                  cycles_s <= cycles_s + 1'b1;
    end : seq_cycles

    // Descripteur, FLUX (fourni).
    always_ff @(posedge clock_i or negedge resetb_i) begin : seq_descripteur
        if (resetb_i == 1'b0) begin
            n_o <= '0; m_o <= '0; w_base_o <= '0; in_base_o <= '0; out_base_o <= '0;
            bias_base_o <= '0; m0_o <= '0; shift_o <= '0; zp_o <= '0;
            relu_o <= 1'b0; w_stream_o <= 1'b0; flux_o <= '0;
        end
        else if (wr_go_s == 1'b1) begin
            case (wr_mot_s)
                n_p:         n_o         <= wdata_i[dim_width_g-1:0];
                m_p:         m_o         <= wdata_i[dim_width_g-1:0];
                w_base_p:    w_base_o    <= wdata_i[w_addr_width_g-1:0];
                in_base_p:   in_base_o   <= wdata_i[act_addr_width_g-1:0];
                out_base_p:  out_base_o  <= wdata_i[act_addr_width_g-1:0];
                bias_base_p: bias_base_o <= wdata_i[bias_addr_width_g-1:0];
                m0_p:        m0_o        <= wdata_i;
                shift_p:     shift_o     <= wdata_i[4:0];
                zp_p:        zp_o        <= wdata_i[7:0];
                options_p: begin
                    relu_o     <= wdata_i[0];
                    w_stream_o <= wdata_i[1];
                end
                flux_p:      flux_o      <= wdata_i[1:0];
                default: ;
            endcase
        end
    end : seq_descripteur

    // -------------------------------------------------------------------------
    // TODO A : la commande, selon R6 à R8.
    // -------------------------------------------------------------------------
    // R6 : START n'existe qu'au cycle où l'ARM écrit 1 dans CTRL, et seulement si
    // le moteur est libre. Une écriture pendant BUSY est ignorée.
    assign start_o = wr_go_s & (wr_mot_s == ctrl_p) & wdata_i[0] & ~busy_i;

    always_ff @(posedge clock_i or negedge resetb_i) begin : seq_commande
        if (resetb_i == 1'b0) begin : raz
            done_s  <= 1'b0;
            duree_s <= '0;
        end : raz
        else if (start_o == 1'b1) begin : depart
            done_s  <= 1'b0;   // R7 : DONE retombe au START
            duree_s <= '0;     // R8 : DUREE repart de 0
        end : depart
        else begin : suivi
            // Deux if indépendants, pas une chaîne : done_i monte dans l'état DONE,
            // où busy_i vaut encore 1. Avec un else if, DONE ne monterait jamais.
            if (done_i == 1'b1)
                done_s <= 1'b1;               // R7
            if (busy_i == 1'b1)
                duree_s <= duree_s + 1'b1;    // R8
        end : suivi
    end : seq_commande

    // -------------------------------------------------------------------------
    // TODO B : les fenêtres, selon R9 et R10.
    // -------------------------------------------------------------------------
    // R9 : chaque écriture acceptée dans BIAS_DATA écrit un biais.
    assign bias_we_o = wr_go_s & (wr_mot_s == bias_data_p);
    // R10 : chaque écriture acceptée dans ACT_DATA écrit un octet, sauf pendant
    // une couche (le séquenceur tient alors le tampon) ; act_rd_s marque une
    // lecture acceptée de ACT_DATA.
    assign act_we_o  = wr_go_s & (wr_mot_s == act_data_p) & ~busy_i;
    assign act_rd_s  = rd_go_s & (rd_mot_s == act_data_p);

    always_ff @(posedge clock_i or negedge resetb_i) begin : seq_fenetres
        if (resetb_i == 1'b0) begin : raz
            bias_addr_s <= '0;
            act_addr_s  <= '0;
        end : raz
        else begin : avance
            // BIAS_ADDR : une écriture la fixe, sinon chaque biais écrit la fait avancer.
            if (wr_go_s == 1'b1 && wr_mot_s == bias_addr_p)
                bias_addr_s <= wdata_i[bias_addr_width_g-1:0];
            else if (bias_we_o == 1'b1)
                bias_addr_s <= bias_addr_s + 1'b1;
            // ACT_ADDR : une écriture la fixe (et l'emporte), sinon + 1 par écriture
            // et + 1 par lecture de ACT_DATA, donc + 2 si les deux tombent ensemble.
            if (wr_go_s == 1'b1 && wr_mot_s == act_addr_p)
                act_addr_s <= wdata_i[act_addr_width_g-1:0];
            else
                act_addr_s <= act_addr_s + act_addr_width_g'(act_we_o)
                                         + act_addr_width_g'(act_rd_s);
        end : avance
    end : seq_fenetres

    // Les fenêtres : adresses et données (fourni).
    assign bias_waddr_o = bias_addr_s;
    assign bias_wdata_o = wdata_i;
    assign act_waddr_o  = act_addr_s;
    assign act_wdata_o  = wdata_i[7:0];
    assign act_raddr_o  = act_addr_s;

    // W_ADDR : l'ARM charge le compteur de npu_flux.sv (fourni).
    assign w_addr_load_o = wr_go_s & (wr_mot_s == w_addr_p);
    assign w_addr_val_o  = wdata_i[w_addr_width_g-1:0];

    // La lecture (fourni).
    always_comb begin : comb_lecture
        case (rd_mot_s)
            version_p:   lecture_s = version_g;
            scratch_p:   lecture_s = scratch_s;
            cycles_p:    lecture_s = cycles_s;
            status_p:    lecture_s = {30'b0, done_s, busy_i};
            duree_p:     lecture_s = duree_s;
            flux_p:      lecture_s = 32'(flux_o);
            w_addr_p:    lecture_s = 32'(w_addr_i);
            bias_addr_p: lecture_s = 32'(bias_addr_s);
            act_addr_p:  lecture_s = 32'(act_addr_s);
            act_data_p:  lecture_s = 32'(act_rdata_i);
            n_p:         lecture_s = 32'(n_o);
            m_p:         lecture_s = 32'(m_o);
            w_base_p:    lecture_s = 32'(w_base_o);
            in_base_p:   lecture_s = 32'(in_base_o);
            out_base_p:  lecture_s = 32'(out_base_o);
            bias_base_p: lecture_s = 32'(bias_base_o);
            m0_p:        lecture_s = m0_o;
            shift_p:     lecture_s = 32'(shift_o);
            zp_p:        lecture_s = 32'(zp_o);
            options_p:   lecture_s = {30'b0, w_stream_o, relu_o};
            default:     lecture_s = '0;
        endcase
    end : comb_lecture
endmodule : npu_regs
