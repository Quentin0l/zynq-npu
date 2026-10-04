// Mutant fourni par le parcours : une copie de rtl/moteur/layer_seq.sv avec un bug planté.
// Ne l'ouvre pas avant d'avoir écrit tes tests : c'est à eux de le trouver.
`timescale 1ns / 1ps

// Mutant : une copie de layer_seq.sv avec UN bug volontaire.
// Ne le lis pas avant d'avoir écrit tes tests.

module layer_seq #(
    parameter nb_mac_g          = 8,
    parameter sel_width_g       = $clog2(nb_mac_g),
    parameter dim_width_g       = 10,   // n et m jusqu'à 1 023
    parameter w_addr_width_g    = 15,
    parameter act_addr_width_g  = 10,
    parameter bias_addr_width_g = 9
) (
    input  logic                         clock_i,
    input  logic                         resetb_i,
    input  logic                         start_i,
    // Descripteur de la couche
    input  logic [dim_width_g-1:0]       n_i,          // nombre d'entrées
    input  logic [dim_width_g-1:0]       m_i,          // nombre de sorties
    input  logic [w_addr_width_g-1:0]    w_base_i,     // première tuile, dans le tampon de poids
    input  logic [act_addr_width_g-1:0]  in_base_i,    // zone des entrées, dans le tampon d'activations
    input  logic [act_addr_width_g-1:0]  out_base_i,   // zone des sorties
    input  logic [bias_addr_width_g-1:0] bias_base_i,  // premier biais de la couche
    // Commandes du moteur de passe (exercice 0004)
    output logic                         clear_o,
    output logic [w_addr_width_g-1:0]    base_o,
    output logic                         valid_o,
    output logic [act_addr_width_g-1:0]  act_raddr_o,
    // Commandes du vidage
    output logic [sel_width_g-1:0]       sel_o,        // le MAC dont l'accumulateur est requantifié
    output logic [bias_addr_width_g-1:0] bias_raddr_o,
    output logic                         act_we_o,
    output logic [act_addr_width_g-1:0]  act_waddr_o,
    // État
    output logic                         busy_o,
    output logic                         done_o
);

    // FSM_Moore : les commandes ne dépendent que de l'état et des compteurs.
    // (Les bases du descripteur, ajoutées aux compteurs pour former les adresses,
    // sont des constantes pendant toute la couche.)
    typedef enum logic [2:0] {IDLE, CLEAR, STREAM, WAIT, DRAIN, DONE} state_t;
    state_t current_state_s, next_state_s;

    // Un compteur par indice de boucle, plus l'adresse de la tuile suivante.
    logic [dim_width_g-1:0]    j_s;      // boucle sur les n entrées d'une passe
    logic [sel_width_g-1:0]    k_s;      // boucle sur les P MAC à vider
    logic [dim_width_g-1:0]    o_s;      // numéro de la sortie, de 0 à m - 1, sur toute la couche
    logic [w_addr_width_g-1:0] wbase_s;  // adresse de la tuile de la passe suivante

    // -------------------------------------------------------------------------
    // Registre d'état (fourni).
    // -------------------------------------------------------------------------
    always_ff @(posedge clock_i or negedge resetb_i) begin : seq_0
        if (resetb_i == 1'b0)
            current_state_s <= IDLE;
        else
            current_state_s <= next_state_s;
    end : seq_0

    // -------------------------------------------------------------------------
    // Transitions : les conditions de sortie des boucles.
    // -------------------------------------------------------------------------
    always_comb begin : comb_0
        case (current_state_s)
            IDLE:
                if (start_i == 1'b1) next_state_s = CLEAR;
                else                 next_state_s = IDLE;
            CLEAR:
                next_state_s = STREAM;
            STREAM:
                if (j_s == n_i - 1'b1) next_state_s = WAIT;
                else                   next_state_s = STREAM;
            WAIT:
                next_state_s = DRAIN;
            DRAIN:
                if (k_s == sel_width_g'(nb_mac_g - 1))
                    next_state_s = (o_s >= m_i - 1'b1) ? DONE : CLEAR;
                else
                    next_state_s = DRAIN;
            DONE:
                next_state_s = IDLE;
            default:
                next_state_s = IDLE;
        endcase
    end : comb_0

    // -------------------------------------------------------------------------
    // Compteurs : les indices des boucles.
    // -------------------------------------------------------------------------
    always_ff @(posedge clock_i or negedge resetb_i) begin : seq_1
        if (resetb_i == 1'b0) begin : raz
            j_s     <= '0;
            k_s     <= '0;
            o_s     <= '0;
            wbase_s <= '0;
        end : raz
        else begin : compteurs
            case (current_state_s)
                IDLE: begin : prepare_couche
                    o_s     <= '0;
                    wbase_s <= w_base_i;
                end : prepare_couche
                CLEAR: begin : prepare_passe
                    j_s     <= '0;
                    k_s     <= '0;
                    wbase_s <= wbase_s + w_addr_width_g'(n_i);
                end : prepare_passe
                STREAM:
                    j_s <= j_s + 1'b1;
                DRAIN: begin : vide
                    k_s <= k_s + 1'b1;
                    o_s <= o_s + 1'b1;
                end : vide
                default: ;  // WAIT, DONE : aucun compteur ne bouge
            endcase
        end : compteurs
    end : seq_1

    // -------------------------------------------------------------------------
    // Sorties (fourni) : ce que fait chaque état.
    // -------------------------------------------------------------------------
    always_comb begin : comb_1
        clear_o  = 1'b0;
        valid_o  = 1'b0;
        act_we_o = 1'b0;
        done_o   = 1'b0;
        busy_o   = 1'b1;
        case (current_state_s)
            IDLE:    busy_o   = 1'b0;
            CLEAR:   clear_o  = 1'b1;
            STREAM:  valid_o  = 1'b1;
            DRAIN:   act_we_o = 1'b1;
            DONE:    done_o   = 1'b1;
            default: ;  // WAIT : rien
        endcase
    end : comb_1

    // Les adresses : une base du descripteur plus un compteur.
    assign base_o       = wbase_s;
    assign act_raddr_o  = in_base_i + act_addr_width_g'(j_s);
    assign sel_o        = k_s;
    assign bias_raddr_o = bias_base_i + bias_addr_width_g'(o_s);
    assign act_waddr_o  = out_base_i + act_addr_width_g'(o_s);

endmodule : layer_seq
