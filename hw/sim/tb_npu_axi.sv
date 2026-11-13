`timescale 1ns / 1ps
// Provenance : leçon 2 du parcours « NPU sur ZedBoard » (fourni).

// =============================================================================
// tb_npu_axi.sv : banc xsim de l'IP npu_axi, pour vérifier les registres sur ce
// PC, avec le simulateur de Vivado, avant d'empaqueter (lancer : hw/sim/run.sh).
// Un maître AXI4-Lite écrit à la main, avec une contre-pression aléatoire sur
// BREADY et RREADY. Les messages sont sans accents : xsim les affiche mal.
// =============================================================================

module tb_npu_axi;

    logic clock_s = 1'b0;
    logic resetb_s = 1'b0;
    always #5 clock_s = ~clock_s;   // 100 MHz

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
    int nb_aw = 0;
    int nb_b = 0;

    // Autant de réponses B que d'écritures acceptées : rien ne doit se perdre.
    always @(posedge clock_s) begin : compte
        if (awvalid_s && awready_s) nb_aw++;
        if (bvalid_s && bready_s)   nb_b++;
    end : compte

    // Le maître fait parfois attendre les réponses.
    always @(posedge clock_s) begin : contre_pression
        bready_s <= ($urandom % 3 != 0);
        rready_s <= ($urandom % 3 != 0);
    end : contre_pression

    task automatic ecrire(input logic [11:0] a, input logic [31:0] d, input logic [3:0] s);
        @(posedge clock_s);
        awaddr_s <= a; wdata_s <= d; wstrb_s <= s; awvalid_s <= 1'b1; wvalid_s <= 1'b1;
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

    logic [31:0] v_s, c1_s, c2_s;

    initial begin : scenario
        awvalid_s = 1'b0; wvalid_s = 1'b0; arvalid_s = 1'b0;
        s_tdata_s = 64'h0123_4567_89AB_CDEF; s_tkeep_s = 8'hFF; s_tlast_s = 1'b1;
        s_tvalid_s = 1'b1; m_tready_s = 1'b0;
        repeat (3) @(posedge clock_s);
        resetb_s = 1'b1;

        lire(12'h000, v_s); verifier("R1 VERSION", v_s, 32'h4E50_5501);
        lire(12'h004, v_s); verifier("R2 SCRATCH au reset", v_s, 32'h0);
        ecrire(12'h004, 32'hDEAD_BEEF, 4'b1111);
        lire(12'h004, v_s); verifier("R2 SCRATCH ecrit", v_s, 32'hDEAD_BEEF);
        ecrire(12'h004, 32'h1122_3344, 4'b0101);       // octets 0 et 2 seulement
        lire(12'h004, v_s); verifier("R2 SCRATCH, WSTRB = 0101", v_s, 32'hDE22_BE44);
        ecrire(12'h000, 32'hFFFF_FFFF, 4'b1111);       // VERSION est en lecture seule
        lire(12'h000, v_s); verifier("R1 VERSION apres ecriture", v_s, 32'h4E50_5501);

        lire(12'h008, c1_s);
        repeat (100) @(posedge clock_s);
        lire(12'h008, c2_s);
        if (c2_s - c1_s < 100 || c2_s - c1_s > 130) begin
            $display("ECHEC  R3 CYCLES : +%0d en un peu plus de 100 cycles", c2_s - c1_s);
            erreurs++;
        end
        else
            $display("ok     R3 CYCLES : +%0d en un peu plus de 100 cycles", c2_s - c1_s);

        lire(12'h010, v_s); verifier("R4 adresse 0x010", v_s, 32'h0);

        for (int i = 0; i < 20; i++) ecrire(12'h004, i, 4'b1111);
        repeat (20) @(posedge clock_s);
        if (nb_aw != nb_b) begin
            $display("ECHEC  A1-A2 : %0d ecritures, %0d reponses", nb_aw, nb_b);
            erreurs++;
        end
        else
            $display("ok     A1-A2 : %0d ecritures, %0d reponses", nb_aw, nb_b);
        lire(12'h004, v_s); verifier("R2 SCRATCH apres 20 ecritures", v_s, 32'd19);

        m_tready_s = 1'b1;
        #1;
        if (m_tdata_s !== s_tdata_s || m_tvalid_s !== 1'b1 || s_tready_s !== 1'b1 || m_tlast_s !== 1'b1) begin
            $display("ECHEC  boucle de retour S_AXIS -> M_AXIS");
            erreurs++;
        end
        else
            $display("ok     boucle de retour S_AXIS -> M_AXIS");

        if (erreurs == 0) $display("TOUT PASSE");
        else              $display("%0d ECHEC(S)", erreurs);
        $finish;
    end : scenario

endmodule : tb_npu_axi
