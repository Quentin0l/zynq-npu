`timescale 1ns / 1ps
// Provenance : leçon 6 du parcours « NPU sur ZedBoard » (fourni).

// =============================================================================
// tb_npu_v2.sv : banc xsim de l'IP npu_axi 2.0, à travers ses vraies interfaces.
// Un maître AXI4-Lite et une source AXI4-Stream écrits à la main font ce que
// feront l'ARM et le DMA : charger poids, biais et entrées, poser le descripteur,
// lancer, attendre, relire. Les sorties sont comparées à une référence calculée
// ici même, d'après la spécification Q1 à Q5 de requant.sv, avec m0 = 2^30.
// Lancer : hw/sim/run_v2.sh. Messages sans accents : xsim les affiche mal.
// =============================================================================

module tb_npu_v2;

    localparam P = 8;   // MAC du moteur

    // Registres (octets)
    localparam logic [11:0] VERSION = 12'h000, CTRL = 12'h00C, STATUS = 12'h010,
        DUREE = 12'h014, FLUX = 12'h018, W_ADDR = 12'h01C, BIAS_ADDR = 12'h020,
        BIAS_DATA = 12'h024, ACT_ADDR = 12'h028, ACT_DATA = 12'h02C, N = 12'h030,
        M = 12'h034, W_BASE = 12'h038, IN_BASE = 12'h03C, OUT_BASE = 12'h040,
        BIAS_BASE = 12'h044, M0 = 12'h048, SHIFT = 12'h04C, ZP = 12'h050, OPTIONS = 12'h054;

    logic clock_s = 1'b0;
    logic resetb_s = 1'b0;
    always #5 clock_s = ~clock_s;

    logic [11:0] awaddr_s, araddr_s;
    logic        awvalid_s, awready_s, wvalid_s, wready_s, bvalid_s, bready_s;
    logic        arvalid_s, arready_s, rvalid_s, rready_s;
    logic [31:0] wdata_s, rdata_s;
    logic [3:0]  wstrb_s;
    logic [1:0]  bresp_s, rresp_s;
    logic [63:0] s_tdata_s, m_tdata_s;
    logic [7:0]  s_tkeep_s, m_tkeep_s;
    logic        s_tlast_s, m_tlast_s, s_tvalid_s, m_tvalid_s, s_tready_s, m_tready_s;

    npu_axi dut (
        .axi_aclk     (clock_s),   .axi_aresetn  (resetb_s),
        .s_axi_awaddr (awaddr_s),  .s_axi_awvalid(awvalid_s), .s_axi_awready(awready_s),
        .s_axi_wdata  (wdata_s),   .s_axi_wstrb  (wstrb_s),   .s_axi_wvalid (wvalid_s),
        .s_axi_wready (wready_s),  .s_axi_bresp  (bresp_s),   .s_axi_bvalid (bvalid_s),
        .s_axi_bready (bready_s),  .s_axi_araddr (araddr_s),  .s_axi_arvalid(arvalid_s),
        .s_axi_arready(arready_s), .s_axi_rdata  (rdata_s),   .s_axi_rresp  (rresp_s),
        .s_axi_rvalid (rvalid_s),  .s_axi_rready (rready_s),
        .s_axis_tdata (s_tdata_s), .s_axis_tkeep (s_tkeep_s), .s_axis_tlast (s_tlast_s),
        .s_axis_tvalid(s_tvalid_s),.s_axis_tready(s_tready_s),
        .m_axis_tdata (m_tdata_s), .m_axis_tkeep (m_tkeep_s), .m_axis_tlast (m_tlast_s),
        .m_axis_tvalid(m_tvalid_s),.m_axis_tready(m_tready_s)
    );

    int erreurs = 0;

    // -------------------------------------------------------------------------
    // Le maître AXI4-Lite : celui de tb_npu_axi.sv.
    // -------------------------------------------------------------------------
    always @(posedge clock_s) begin : contre_pression
        bready_s <= ($urandom % 3 != 0);
        rready_s <= ($urandom % 3 != 0);
    end : contre_pression

    task automatic ecrire(input logic [11:0] a, input logic [31:0] d);
        @(posedge clock_s);
        awaddr_s <= a; wdata_s <= d; wstrb_s <= 4'b1111; awvalid_s <= 1'b1; wvalid_s <= 1'b1;
        do @(posedge clock_s); while (!(awready_s && wready_s));
        awvalid_s <= 1'b0; wvalid_s <= 1'b0;
    endtask

    task automatic lire(input logic [11:0] a, output logic [31:0] d);
        @(posedge clock_s);
        araddr_s <= a; arvalid_s <= 1'b1;
        do @(posedge clock_s); while (!arready_s);
        arvalid_s <= 1'b0;
        while (!(rvalid_s && rready_s)) @(posedge clock_s);
        d = rdata_s;
    endtask

    task automatic verifier(input string quoi, input logic [31:0] lu, input logic [31:0] attendu);
        if (lu !== attendu) begin
            $display("ECHEC  %s : lu %h, attendu %h", quoi, lu, attendu);
            erreurs++;
        end
        else
            $display("ok     %s = %h", quoi, lu);
    endtask

    // -------------------------------------------------------------------------
    // La source AXI4-Stream : ce que fera le DMA (MM2S), avec des trous.
    // -------------------------------------------------------------------------
    logic [63:0] mots_s [$];

    task automatic pousser(input int trous);
        foreach (mots_s[i]) begin
            while (($urandom % 100) < trous) @(posedge clock_s);
            s_tdata_s <= mots_s[i]; s_tvalid_s <= 1'b1; s_tlast_s <= (i == mots_s.size() - 1);
            do @(posedge clock_s); while (!s_tready_s);
            s_tvalid_s <= 1'b0; s_tlast_s <= 1'b0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Une couche : ses poids, ses biais, ses entrées, et la référence.
    // -------------------------------------------------------------------------
    int n_c, m_c, shift_c, zp_c;
    bit relu_c;
    logic signed [7:0]  w_c [64][64];   // w_c[o][j] : poids de la sortie o pour l'entrée j
    logic signed [31:0] b_c [64];
    logic signed [7:0]  x_c [64];

    function automatic logic signed [7:0] reference(int o);
        logic signed [63:0] acc, r, y, plancher;
        acc = 0;
        for (int j = 0; j < n_c; j++) acc += 64'(w_c[o][j]) * 64'(x_c[j]);
        acc += 64'(b_c[o]);                          // Q1
        r = (acc * 64'sd1073741824) >>> (31 + shift_c);   // Q2, Q3 avec m0 = 2^30
        y = r + zp_c;                                 // Q4
        plancher = relu_c ? zp_c : -128;              // Q5
        if (y > 127)           return 8'sd127;
        else if (y < plancher) return 8'(plancher);
        else                   return 8'(y);
    endfunction

    task automatic tirer_couche(input int n, input int m, input int shift, input int zp, input bit relu);
        n_c = n; m_c = m; shift_c = shift; zp_c = zp; relu_c = relu;
        for (int o = 0; o < m; o++) begin
            for (int j = 0; j < n; j++) w_c[o][j] = $urandom;
            b_c[o] = $signed($urandom % 4001) - 2000;
        end
        for (int j = 0; j < n; j++) x_c[j] = $urandom;
    endtask

    // Les mots du flux, dans l'ordre où le moteur les consomme : tuile après
    // tuile, une colonne par mot, l'octet k pour le MAC k (couche_en_mots).
    task automatic preparer_mots();
        mots_s.delete();
        for (int t = 0; t < (m_c + P - 1) / P; t++)
            for (int j = 0; j < n_c; j++) begin
                logic [63:0] mot = '0;
                for (int k = 0; k < P; k++)
                    if (t * P + k < m_c) mot[8*k +: 8] = w_c[t * P + k][j];
                mots_s.push_back(mot);
            end
    endtask

    task automatic charger_biais_et_entrees();
        ecrire(BIAS_ADDR, 0);
        for (int o = 0; o < m_c; o++) ecrire(BIAS_DATA, b_c[o]);
        ecrire(ACT_ADDR, 0);
        for (int j = 0; j < n_c; j++) ecrire(ACT_DATA, 32'(x_c[j]));
    endtask

    task automatic poser_descripteur(input bit en_flux);
        ecrire(N, n_c);       ecrire(M, m_c);
        ecrire(W_BASE, 0);    ecrire(IN_BASE, 0);
        ecrire(OUT_BASE, 1024); ecrire(BIAS_BASE, 0);
        ecrire(M0, 32'h4000_0000);   // 2^30 : les échelles d'AIfES sont des puissances de deux
        ecrire(SHIFT, shift_c); ecrire(ZP, 32'(zp_c));
        ecrire(OPTIONS, {30'b0, en_flux, relu_c});
    endtask

    // DUREE compte les cycles ou BUSY = 1, de CLEAR a DONE compris : T(n+2)+m+1.
    // En flux, chaque bulle (file vide en STREAM) ajoute un cycle.
    task automatic attendre_et_comparer(input string nom, input bit en_flux);
        logic [31:0] v;
        int t, attendu;
        do lire(STATUS, v); while (v[1] !== 1'b1);   // DONE
        verifier({nom, " : STATUS apres la couche (DONE, pas BUSY)"}, v, 32'h2);
        t = (m_c + P - 1) / P;
        attendu = t * (n_c + 2) + m_c + 1;
        lire(DUREE, v);
        if (en_flux ? (v < attendu) : (v != attendu)) begin
            $display("ECHEC  %s : DUREE = %0d, attendu %0d%s", nom, v, attendu, en_flux ? " au moins" : "");
            erreurs++;
        end
        else
            $display("ok     %s : DUREE = %0d cycles, dont %0d bulles", nom, v, v - attendu);
        ecrire(ACT_ADDR, 1024);
        for (int o = 0; o < m_c; o++) begin
            lire(ACT_DATA, v);
            if (v !== 32'(reference(o))) begin
                $display("ECHEC  %s : sortie %0d = %0d, attendu %0d", nom, o, $signed(v), reference(o));
                erreurs++;
            end
        end
        $display("       %s : %0d sorties comparees", nom, m_c);
    endtask

    // Moniteur de M_AXIS (mode BOUCLE)
    logic [63:0] recus_s [$];
    always @(posedge clock_s) if (m_tvalid_s && m_tready_s) recus_s.push_back(m_tdata_s);

    // -------------------------------------------------------------------------
    // Le scénario
    // -------------------------------------------------------------------------
    logic [31:0] v_s;

    initial begin : scenario
        awvalid_s = 1'b0; wvalid_s = 1'b0; arvalid_s = 1'b0;
        s_tvalid_s = 1'b0; s_tdata_s = '0; s_tkeep_s = 8'hFF; s_tlast_s = 1'b0;
        m_tready_s = 1'b1;
        repeat (3) @(posedge clock_s);
        resetb_s = 1'b1;

        // 1. Identité
        lire(VERSION, v_s); verifier("VERSION", v_s, 32'h4E50_5502);

        // 2. Le descripteur se relit
        ecrire(N, 784); lire(N, v_s); verifier("N", v_s, 784);
        ecrire(ZP, 32'hFFFF_FFFD); lire(ZP, v_s); verifier("ZP (signe)", v_s, 32'hFFFF_FFFD);
        ecrire(OPTIONS, 3); lire(OPTIONS, v_s); verifier("OPTIONS", v_s, 3);

        // 3. FLUX = 0 : la boucle de la version 1 marche toujours
        ecrire(FLUX, 0);
        mots_s = '{64'h1111_2222_3333_4444, 64'h5555_6666_7777_8888, 64'h9999_AAAA_BBBB_CCCC};
        pousser(30);
        repeat (5) @(posedge clock_s);
        if (recus_s.size() != 3 || recus_s[2] !== 64'h9999_AAAA_BBBB_CCCC) begin
            $display("ECHEC  BOUCLE : %0d mots recus", recus_s.size());
            erreurs++;
        end
        else
            $display("ok     BOUCLE : 3 mots recus intacts");

        // 4. Une couche, poids charges dans le tampon (FLUX = 1), trois passes
        tirer_couche(16, 20, 4, -3, 1'b1);
        preparer_mots();
        ecrire(FLUX, 1);
        ecrire(W_ADDR, 0);
        pousser(20);
        lire(W_ADDR, v_s); verifier("TAMPON : W_ADDR apres chargement", v_s, mots_s.size());
        charger_biais_et_entrees();
        poser_descripteur(1'b0);
        ecrire(CTRL, 1);
        attendre_et_comparer("TAMPON", 1'b0);

        // 5. Une couche, poids en flux (FLUX = 2), deux passes, sans ReLU
        tirer_couche(24, 16, 3, 5, 1'b0);
        preparer_mots();
        charger_biais_et_entrees();
        poser_descripteur(1'b1);
        ecrire(FLUX, 2);
        fork
            pousser(40);   // le DMA pousse...
            ecrire(CTRL, 1);   // ... pendant que l'ARM lance la couche
        join
        attendre_et_comparer("FILE", 1'b1);

        if (erreurs == 0) $display("TOUT PASSE");
        else              $display("%0d ECHEC(S)", erreurs);
        $finish;
    end : scenario

    initial begin : garde_fou
        #2ms;
        $display("ECHEC  le banc est bloque : un TREADY qui ne monte jamais, ou une couche sans DONE");
        $finish;
    end : garde_fou

endmodule : tb_npu_v2
