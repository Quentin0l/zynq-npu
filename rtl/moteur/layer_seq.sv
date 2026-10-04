`timescale 1ns / 1ps
// Provenance : exercice 0006 du parcours (spécification, seq_0 et comb_1 fournis ; transitions et compteurs écrits par l'auteur du dépôt).

// =============================================================================
// layer_seq.sv : le séquenceur. Il exécute UNE couche dense entière, seul :
// T = ⌈m/P⌉ passes, et chaque passe = remise à zéro, n entrées, vidage de ses
// sorties. C'est le nid de boucles de la couche, devenu matériel.
//
// Spécification. Les tests la vérifient à la lettre, cycle par cycle.
//   Six états (FSM_Moore) : IDLE, CLEAR, STREAM, WAIT, DRAIN, DONE.
//   Quatre compteurs : j (entrée de la passe), k (MAC en cours de vidage),
//   o (sortie de la couche), wbase (adresse de la tuile de la passe suivante).
//   P = nb_mac_g.
//
//   S1. IDLE   : busy_o = 0. Prépare la couche : o <- 0, wbase <- w_base_i.
//                Si start_i = 1 : -> CLEAR.
//   S2. CLEAR  : 1 cycle. clear_o = 1 et base_o = wbase : le moteur de passe les
//                prend à ce front. Prépare la passe : j <- 0, k <- 0,
//                wbase <- wbase + n_i (la tuile suivante). -> STREAM.
//   S3. STREAM : n_i cycles. valid_o = 1, act_raddr_o = in_base_i + j.
//                j <- j + 1. Si j = n_i - 1 (dernière entrée) : -> WAIT.
//   S4. WAIT   : 1 cycle, aucun compteur ne bouge. Le moteur de passe retarde
//                tout d'un cycle (E5 de l'exercice 0004) : c'est pendant ce
//                cycle que le dernier produit entre dans les accumulateurs.
//                -> DRAIN.
//   S5. DRAIN  : une sortie par cycle. sel_o = k, bias_raddr_o = bias_base_i + o,
//                act_we_o = 1, act_waddr_o = out_base_i + o. k <- k + 1, o <- o + 1.
//                Si o = m_i - 1 (dernière sortie de la couche) : -> DONE.
//                Sinon, si k = P - 1 (dernier MAC de la passe) : -> CLEAR.
//                Sinon : on reste en DRAIN.
//   S6. DONE   : 1 cycle. done_o = 1. -> IDLE.
//   busy_o = 1 dans tous les états sauf IDLE.
//   Durée : de CLEAR (inclus) à DONE (exclu), T·(n + 2) + m cycles.
//   Le descripteur (n_i, m_i et les bases) reste stable de start_i à done_o.
// =============================================================================

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
    // TODO 1a : les transitions, dans un processus comb_0 (always_comb) : un
    //           case sur current_state_s, avec un default, selon S1 à S6.
    //           Ce sont les conditions de sortie des boucles.
    // TODO 1b : les compteurs j_s, k_s, o_s et wbase_s, dans un processus seq_1
    //           (always_ff, reset asynchrone actif bas qui les met tous à 0) :
    //           un case sur current_state_s dit, pour chaque état, quels
    //           compteurs changent et comment, selon S1 à S6.
    //           Supprime les cinq lignes « assign … » ci-dessous.
    // -------------------------------------------------------------------------

    always_comb begin :comb_0
    case(current_state_s)
        IDLE: next_state_s = (start_i == 1'b1)? CLEAR : IDLE;
        CLEAR: next_state_s = STREAM;
        STREAM: next_state_s = (j_s == n_i - 1'b1)? WAIT : STREAM;
        WAIT: next_state_s = DRAIN;
        DRAIN: if (o_s == m_i - 1'b1 )
                    next_state_s = DONE;
                else if (k_s == nb_mac_g - 1'b1) 
                    next_state_s = CLEAR;
                else 
                    next_state_s = DRAIN;
                         
        DONE: next_state_s = IDLE;
        default : next_state_s = IDLE;
    endcase

    end: comb_0
    


    always_ff @(posedge clock_i or negedge resetb_i) begin: seq_1
        if (resetb_i == 1'b0) begin
            j_s          <= '0;
            k_s          <= '0;
            o_s          <= '0;
            wbase_s      <= '0;
        end
        else begin
            case(current_state_s)
                IDLE: begin
                    o_s <= '0;
                    wbase_s <= w_base_i;
                end
                CLEAR: begin
                    j_s <= '0;
                    k_s <= '0;
                    wbase_s <= wbase_s + n_i;

                end
                STREAM: j_s <= j_s + 1'b1;
                DRAIN: begin
                        k_s <= k_s + 1'b1;
                        o_s <= o_s + 1'b1;
                
                end
                default : ;
 

            endcase
        end
    end: seq_1

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
