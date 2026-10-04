`timescale 1ns / 1ps
// Provenance : exercice 0006 du parcours (câblage fourni).

// =============================================================================
// layer_engine.sv : une couche dense complète, d'int8 à int8, sans le banc.
// Fourni : c'est le câblage. Le cerveau, c'est ton layer_seq.sv.
//
//   tampon d'activations --x_s--> moteur de passe (0004) --acc_s--> mux P:1
//          ^                                                          |
//          |                                                   acc_sel_s
//          |                                                          v
//          +--- q_s (int8) <--- requantification (0005) <--- + biais b'
//
//   Le banc (plus tard l'ARM) charge les poids, les biais et les entrées,
//   pose le descripteur de la couche, envoie start_i, attend done_o, puis lit
//   les sorties par act_raddr_i / act_rdata_o.
//
//   Les deux petites mémoires sont des lut_ram, lues en asynchrone : x arrive
//   au moteur dans le cycle même où le séquenceur donne son adresse. Avec une
//   BRAM, il faudrait un étage de retard de plus sur valid (règle de la leçon 4).
// =============================================================================

module layer_engine #(
    parameter nb_mac_g          = 8,
    parameter w_depth_g         = 32768,  // mots du tampon de poids
    parameter act_depth_g       = 1024,   // tampon d'activations : deux zones de 512 octets
    parameter bias_depth_g      = 512,    // un biais int32 par sortie, toutes couches confondues
    parameter dim_width_g       = 10,     // n et m jusqu'à 1 023
    parameter sel_width_g       = $clog2(nb_mac_g),
    parameter w_addr_width_g    = $clog2(w_depth_g),
    parameter act_addr_width_g  = $clog2(act_depth_g),
    parameter bias_addr_width_g = $clog2(bias_depth_g)
) (
    input  logic                         clock_i,
    input  logic                         resetb_i,
    // Chargements (le rôle de l'ARM, plus tard)
    input  logic                         w_we_i,
    input  logic [w_addr_width_g-1:0]    w_waddr_i,
    input  logic [nb_mac_g*8-1:0]        w_wdata_i,
    input  logic                         bias_we_i,
    input  logic [bias_addr_width_g-1:0] bias_waddr_i,
    input  logic signed [31:0]           bias_wdata_i,
    input  logic                         act_we_i,
    input  logic [act_addr_width_g-1:0]  act_waddr_i,
    input  logic signed [7:0]            act_wdata_i,
    // Lecture des activations par le banc (quand busy_o = 0)
    input  logic [act_addr_width_g-1:0]  act_raddr_i,
    output logic signed [7:0]            act_rdata_o,
    // Descripteur de la couche : stable de start_i à done_o
    input  logic [dim_width_g-1:0]       n_i,
    input  logic [dim_width_g-1:0]       m_i,
    input  logic [w_addr_width_g-1:0]    w_base_i,
    input  logic [act_addr_width_g-1:0]  in_base_i,
    input  logic [act_addr_width_g-1:0]  out_base_i,
    input  logic [bias_addr_width_g-1:0] bias_base_i,
    input  logic signed [31:0]           m0_i,
    input  logic        [4:0]            shift_i,
    input  logic signed [7:0]            zp_i,
    input  logic                         relu_i,
    // Commande
    input  logic                         start_i,
    output logic                         busy_o,
    output logic                         done_o
);

    // Commandes produites par le séquenceur
    logic                         clear_s;
    logic                         valid_s;
    logic [w_addr_width_g-1:0]    base_s;
    logic [act_addr_width_g-1:0]  seq_raddr_s;
    logic [sel_width_g-1:0]       sel_s;
    logic [bias_addr_width_g-1:0] bias_raddr_s;
    logic                         seq_we_s;
    logic [act_addr_width_g-1:0]  seq_waddr_s;
    logic                         busy_s;

    // Chemin de données
    logic [nb_mac_g*32-1:0]       acc_s;      // les P accumulateurs du moteur de passe
    logic signed [31:0]           acc_sel_s;  // celui que l'on vide
    logic signed [31:0]           bias_s;     // son biais corrigé b'
    logic signed [7:0]            q_s;        // la sortie requantifiée
    logic signed [7:0]            x_s;        // l'octet lu dans le tampon d'activations

    // Accès au tampon d'activations : le séquenceur pendant une couche, le banc sinon.
    logic                         act_we_s;
    logic [act_addr_width_g-1:0]  act_waddr_s;
    logic [7:0]                   act_wdata_s;
    logic [act_addr_width_g-1:0]  act_raddr_s;

    // -------------------------------------------------------------------------
    // Le cerveau : ton séquenceur.
    // -------------------------------------------------------------------------
    layer_seq #(
        .nb_mac_g         (nb_mac_g),
        .sel_width_g      (sel_width_g),
        .dim_width_g      (dim_width_g),
        .w_addr_width_g   (w_addr_width_g),
        .act_addr_width_g (act_addr_width_g),
        .bias_addr_width_g(bias_addr_width_g)
    ) u_seq (
        .clock_i     (clock_i),
        .resetb_i    (resetb_i),
        .start_i     (start_i),
        .n_i         (n_i),
        .m_i         (m_i),
        .w_base_i    (w_base_i),
        .in_base_i   (in_base_i),
        .out_base_i  (out_base_i),
        .bias_base_i (bias_base_i),
        .clear_o     (clear_s),
        .base_o      (base_s),
        .valid_o     (valid_s),
        .act_raddr_o (seq_raddr_s),
        .sel_o       (sel_s),
        .bias_raddr_o(bias_raddr_s),
        .act_we_o    (seq_we_s),
        .act_waddr_o (seq_waddr_s),
        .busy_o      (busy_s),
        .done_o      (done_o)
    );

    // -------------------------------------------------------------------------
    // Le calcul : ton moteur de passe de l'exercice 0004, tel quel.
    // -------------------------------------------------------------------------
    pass_engine #(
        .nb_mac_g   (nb_mac_g),
        .acc_width_g(32),
        .depth_g    (w_depth_g)
    ) u_pass (
        .clock_i (clock_i),
        .resetb_i(resetb_i),
        .we_i    (w_we_i),
        .waddr_i (w_waddr_i),
        .wdata_i (w_wdata_i),
        .clear_i (clear_s),
        .base_i  (base_s),
        .valid_i (valid_s),
        .x_i     (x_s),
        .acc_o   (acc_s)
    );

    // -------------------------------------------------------------------------
    // Le vidage : un accumulateur à la fois, choisi par sel_s, vers ta
    // requantification de l'exercice 0005, avec son biais.
    // -------------------------------------------------------------------------
    assign acc_sel_s = acc_s[32*sel_s +: 32];

    lut_ram #(
        .width_g(32),
        .depth_g(bias_depth_g)
    ) u_bias (
        .clock_i(clock_i),
        .we_i   (bias_we_i),
        .waddr_i(bias_waddr_i),
        .wdata_i(bias_wdata_i),
        .raddr_i(bias_raddr_s),
        .rdata_o(bias_s)
    );

    requant u_requant (
        .acc_i  (acc_sel_s),
        .bias_i (bias_s),
        .m0_i   (m0_i),
        .shift_i(shift_i),
        .zp_i   (zp_i),
        .relu_i (relu_i),
        .q_o    (q_s)
    );

    // -------------------------------------------------------------------------
    // Le tampon d'activations : deux zones, lues et écrites par le séquenceur
    // pendant une couche, par le banc le reste du temps.
    // -------------------------------------------------------------------------
    assign act_we_s    = (busy_s == 1'b1) ? seq_we_s    : act_we_i;
    assign act_waddr_s = (busy_s == 1'b1) ? seq_waddr_s : act_waddr_i;
    assign act_wdata_s = (busy_s == 1'b1) ? q_s         : act_wdata_i;
    assign act_raddr_s = (busy_s == 1'b1) ? seq_raddr_s : act_raddr_i;

    lut_ram #(
        .width_g(8),
        .depth_g(act_depth_g)
    ) u_act (
        .clock_i(clock_i),
        .we_i   (act_we_s),
        .waddr_i(act_waddr_s),
        .wdata_i(act_wdata_s),
        .raddr_i(act_raddr_s),
        .rdata_o(x_s)
    );

    assign act_rdata_o = x_s;
    assign busy_o      = busy_s;

endmodule : layer_engine
