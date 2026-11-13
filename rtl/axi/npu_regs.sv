`timescale 1ns / 1ps
// Provenance : leçon 2 du parcours « NPU sur ZedBoard » (spécification et poignée
// de main AXI4-Lite fournies ; TODO 1 à 3, les registres, à écrire par l'auteur du dépôt).

// =============================================================================
// npu_regs.sv : les registres du NPU, vus par l'ARM à travers le port GP0.
// Un esclave AXI4-Lite : 32 bits de données, 12 bits d'adresse (4 Ko).
//
// Spécification des registres. Version 0 de la carte : elle grandira avec le NPU.
//   Une adresse désigne un octet ; un registre fait 4 octets. Le numéro du mot
//   est donc l'adresse privée de ses 2 bits de poids faible : addr[11:2].
//
//   | Offset | Nom     | Accès | Contenu                                     | Reset       |
//   |--------|---------|-------|---------------------------------------------|-------------|
//   | 0x00   | VERSION | L     | version_g : « NPU » en ASCII, puis 0x01      | 0x4E50_5501 |
//   | 0x04   | SCRATCH | L/É   | ce que l'ARM y a écrit                       | 0           |
//   | 0x08   | CYCLES  | L     | nombre de fronts de clock_i depuis le reset  | 0           |
//
//   R1. VERSION : constante. Une écriture n'a aucun effet.
//   R2. SCRATCH : au front où une écriture est acceptée (wr_go_s = 1) à l'adresse
//       0x04, chaque octet b tel que wstrb_i[b] = 1 prend l'octet b de wdata_i ;
//       les autres octets gardent leur valeur.
//   R3. CYCLES : +1 à chaque front, sans condition ; repasse à 0 après 2^32 - 1.
//       Une écriture n'a aucun effet.
//   R4. Toute autre adresse se lit 0 ; une écriture y est sans effet.
//   R5. Toutes les réponses sont OKAY (bresp_o = rresp_o = 2'b00).
//
// Poignée de main (fournie, lis-la). Les règles d'ARM IHI 0022, chapitre A3 :
//   - Un transfert a lieu au front où VALID et READY valent 1 tous les deux.
//   - Un VALID ne doit jamais attendre un READY. Un READY, lui, peut attendre un
//     VALID : c'est ce que fait cet esclave.
//   A1. Écriture : AWREADY = WREADY = 1 quand l'adresse ET la donnée sont là, et
//       que la réponse précédente est partie ou part à ce front. wr_go_s marque ce
//       front : c'est le seul moment où un registre peut être écrit.
//   A2. Réponse d'écriture : BVALID monte au front de wr_go_s, et retombe au front
//       où BREADY = 1.
//   A3. Lecture : ARREADY = 1 quand ARVALID = 1 et que la donnée précédente est
//       partie ou part à ce front (rd_go_s). RDATA prend lecture_s à ce front.
//   A4. BVALID et RVALID sont des bascules : ils ne dépendent pas des READY du maître.
// =============================================================================

module npu_regs #(
    parameter addr_width_g = 12,
    parameter version_g    = 32'h4E50_5501
) (
    input  logic                    clock_i,
    input  logic                    resetb_i,
    // Canal AW : adresse d'écriture
    input  logic [addr_width_g-1:0] awaddr_i,
    input  logic                    awvalid_i,
    output logic                    awready_o,
    // Canal W : donnée d'écriture
    input  logic [31:0]             wdata_i,
    input  logic [3:0]              wstrb_i,
    input  logic                    wvalid_i,
    output logic                    wready_o,
    // Canal B : réponse d'écriture
    output logic [1:0]              bresp_o,
    output logic                    bvalid_o,
    input  logic                    bready_i,
    // Canal AR : adresse de lecture
    input  logic [addr_width_g-1:0] araddr_i,
    input  logic                    arvalid_i,
    output logic                    arready_o,
    // Canal R : donnée lue
    output logic [31:0]             rdata_o,
    output logic [1:0]              rresp_o,
    output logic                    rvalid_o,
    input  logic                    rready_i
);

    // Numéros de mot des registres.
    localparam logic [addr_width_g-3:0] version_p = 'd0;
    localparam logic [addr_width_g-3:0] scratch_p = 'd1;
    localparam logic [addr_width_g-3:0] cycles_p  = 'd2;

    logic                    wr_go_s;    // une écriture est acceptée à ce front (A1)
    logic                    rd_go_s;    // une lecture est acceptée à ce front (A3)
    logic [addr_width_g-3:0] wr_mot_s;   // numéro du mot écrit
    logic [addr_width_g-3:0] rd_mot_s;   // numéro du mot lu
    logic [31:0]             lecture_s;  // la valeur du mot rd_mot_s
    logic [31:0]             scratch_s;  // le registre SCRATCH
    logic [31:0]             cycles_s;   // le registre CYCLES

    // -------------------------------------------------------------------------
    // Écriture (fourni) : A1 et A2.
    // -------------------------------------------------------------------------
    assign wr_go_s   = awvalid_i & wvalid_i & (~bvalid_o | bready_i);
    assign awready_o = wr_go_s;
    assign wready_o  = wr_go_s;
    assign bresp_o   = 2'b00;
    assign wr_mot_s  = awaddr_i[addr_width_g-1:2];

    always_ff @(posedge clock_i or negedge resetb_i) begin : seq_b
        if (resetb_i == 1'b0)
            bvalid_o <= 1'b0;
        else if (wr_go_s == 1'b1)
            bvalid_o <= 1'b1;
        else if (bready_i == 1'b1)
            bvalid_o <= 1'b0;
    end : seq_b

    // -------------------------------------------------------------------------
    // Lecture (fourni) : A3.
    // -------------------------------------------------------------------------
    assign rd_go_s   = arvalid_i & (~rvalid_o | rready_i);
    assign arready_o = rd_go_s;
    assign rresp_o   = 2'b00;
    assign rd_mot_s  = araddr_i[addr_width_g-1:2];

    always_ff @(posedge clock_i or negedge resetb_i) begin : seq_r
        if (resetb_i == 1'b0) begin : raz
            rvalid_o <= 1'b0;
            rdata_o  <= '0;
        end : raz
        else if (rd_go_s == 1'b1) begin : capture
            rvalid_o <= 1'b1;
            rdata_o  <= lecture_s;
        end : capture
        else if (rready_i == 1'b1)
            rvalid_o <= 1'b0;
    end : seq_r

    // -------------------------------------------------------------------------
    // TODO 1 : le registre SCRATCH, dans un processus seq_scratch (always_ff,
    //          reset asynchrone actif bas), selon R2. Une boucle for sur les
    //          4 octets, avec scratch_s[8*b +: 8], évite d'écrire quatre if.
    // TODO 2 : le compteur CYCLES, dans un processus seq_cycles, selon R3.
    // TODO 3 : le multiplexeur de lecture, dans un processus comb_lecture
    //          (always_comb) : un case sur rd_mot_s, avec un default, selon R1 à R4.
    // Supprime les trois lignes « assign … » ci-dessous.
    // -------------------------------------------------------------------------
    assign scratch_s = '0;
    assign cycles_s  = '0;
    assign lecture_s = '0;

endmodule : npu_regs
