`timescale 1ns / 1ps

// =============================================================================
// skew.sv : le décalage d'entrée du tableau systolique (leçon 8).
// Squelette fourni par le parcours ; le TODO 1 est à écrire.
//
// Le tableau veut A[r][k] sur sa ligne r au cycle k + r. Or une tuile est
// rangée colonne par colonne : au cycle k, on sait fournir toute la colonne k
// (A[0][k] ... A[n-1][k]) d'un coup. Ce module retarde chaque voie de son
// numéro de ligne. Le même module sert pour B, voie c = colonne c.
//
// Spécification. Les tests (tb/test_skew.py) la vérifient à la lettre.
//   D1. data_i porte n_g voies de data_w_g bits : la voie r occupe les bits
//       r*data_w_g +: data_w_g. data_o est organisé de la même façon.
//   D2. La voie r de data_o est la voie r de data_i retardée de r cycles.
//       La voie 0 passe sans retard (un fil), la voie n_g-1 traverse n_g-1
//       bascules.
//   D3. Reset asynchrone actif bas : toutes les bascules à 0. Tant que data_i
//       reste à 0, data_o vaut 0.
//   Ni valid ni enable : les bascules avancent à chaque front. Quand aucune
//   tuile ne passe, on présente des zéros, et ce sont des zéros qui avancent.
// =============================================================================

module skew #(
    parameter n_g      = 8,
    parameter data_w_g = 8
) (
    input  logic                    clock_i,
    input  logic                    resetb_i,
    input  logic [n_g*data_w_g-1:0] data_i,
    output logic [n_g*data_w_g-1:0] data_o
);

    // -------------------------------------------------------------------------
    // TODO 1 : une boucle generate sur les voies r = 0 .. n_g-1.
    //   - voie 0 : un fil, de la tranche 0 de data_i à la tranche 0 de data_o ;
    //   - voie r > 0 : r bascules en chaîne, un registre à décalage de profondeur
    //     r, déclaré DANS le bloc generate (comme ta rangée de MAC : chaque
    //     copie a ses propres fils) ; sa dernière bascule sort sur la tranche r.
    // Tant que ce TODO n'est pas écrit, toutes les voies passent sans retard :
    // tout compile, mais le tableau reçoit des données non décalées.
    // -------------------------------------------------------------------------
    assign data_o = data_i;

endmodule : skew
