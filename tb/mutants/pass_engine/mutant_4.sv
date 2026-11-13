// Mutant fourni par le parcours : une copie de rtl/moteur/pass_engine.sv avec un bug planté.
// Ne l'ouvre pas avant d'avoir écrit tes tests : c'est à eux de le trouver.
`timescale 1ns / 1ps

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
    // Poids en flux (E6)
    input  logic                            stream_i,   // 1 : le poids vient de ws_data_i
    input  logic [nb_mac_g*8-1:0]           ws_data_i,  // le mot de poids, avec x_i et valid_i
    // Résultats : un champ de acc_width_g bits par MAC
    output logic [nb_mac_g*acc_width_g-1:0] acc_o
);

    // Signaux internes, déjà déclarés pour toi.
    logic [addr_width_g-1:0] raddr_s;    // compteur d'adresse de lecture
    logic [nb_mac_g*8-1:0]   rdata_s;    // mot lu dans le tampon, un cycle plus tard
    logic signed [7:0]       x_d_s;      // x_i retardé d'un cycle
    logic                    valid_d_s;  // valid_i retardé d'un cycle
    logic                    clear_d_s;  // clear_i retardé d'un cycle
    logic [nb_mac_g*8-1:0]   ws_d_s;     // ws_data_i retardé d'un cycle (E6)
    logic                    stream_d_s; // stream_i retardé d'un cycle (E6)
    logic [nb_mac_g*8-1:0]   w_row_s;    // le mot de poids que reçoit la rangée

    // -------------------------------------------------------------------------
    // TODO 1a : le compteur d'adresse raddr_s, dans un processus seq_0
    //           (reset asynchrone actif bas), selon E2, E3 et E4.
    // TODO 1b : les trois registres de retard x_d_s, valid_d_s, clear_d_s,
    //           dans un processus seq_1 (E5).
    // TODO 1c : instancie weight_buffer (lecture à raddr_s, sortie sur rdata_s)
    //           et ta mac_row (qui reçoit les signaux RETARDÉS et rdata_s),
    //           avec une instanciation par nom.
    //           Supprime la ligne « assign acc_o = '0; » ci-dessous.
    // (Les TODO 2 à 4 sont les tests, dans test_pass_engine.py.)
    // -------------------------------------------------------------------------

    always_ff @(posedge clock_i or negedge resetb_i) begin: seq_0
        if(resetb_i == 1'b0)
            raddr_s <= '0;
        
        else if (clear_i == 1'b1)
            raddr_s <= base_i;
        else if (valid_i == 1'b1)
            raddr_s<= raddr_s +1;
    end: seq_0

    always_ff @(posedge clock_i or negedge resetb_i) begin : seq_1
        if (resetb_i == 1'b0) begin : raz
            x_d_s <= '0;
            valid_d_s<= '0;
            clear_d_s <= '0;
            ws_d_s <= '0;
            stream_d_s <= 1'b0;
        end : raz
        else begin : retard
            x_d_s <= x_i;   // à chaque front, sans condition : x_d_s vaudra au cycle suivant ce que x_i vaut maintenant
            valid_d_s <= valid_i;
            clear_d_s <= clear_i;
            ws_d_s <= ws_data_i;    // E6 : le mot du flux prend le même retard que x
            stream_d_s <= stream_i;
        end : retard
    end : seq_1
    
    
weight_buffer #(
    .width_g(nb_mac_g*8),
    .depth_g(depth_g)
) wb(
    .clock_i(clock_i),
    .we_i(we_i),  
    .waddr_i(waddr_i), 
    .wdata_i(wdata_i), // valeure aléatoire 
    .raddr_i(raddr_s),
    .rdata_o(rdata_s)
);


// E6 : la rangée reçoit le mot du tampon, ou celui du flux.
assign w_row_s = (stream_d_s == 1'b1) ? ws_data_i : rdata_s;

mac_row #(
    .nb_mac_g   (nb_mac_g),
    .acc_width_g(acc_width_g)
) mr(
    .clock_i(clock_i),
    .resetb_i(resetb_i),
    .clear_i(clear_d_s),
    .valid_i(valid_d_s),
    .x_i(x_d_s),
    .w_i(w_row_s),
    .acc_o(acc_o)

);

endmodule : pass_engine
