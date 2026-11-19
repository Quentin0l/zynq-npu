`timescale 1ns / 1ps
// Provenance : leçon 6 du parcours « NPU sur ZedBoard » (fourni).

// =============================================================================
// npu_axi.v : l'enveloppe du NPU, version 2.0. Mêmes ports qu'en 1.0 : le block
// design n'a pas à changer. L'intérieur, lui, devient le vrai NPU.
//
//   S_AXI  → npu_regs   : registres de contrôle, descripteur de couche, fenêtres
//                          vers les biais et le tampon d'activations
//   S_AXIS → npu_flux   : aiguillage du flux entrant selon le registre FLUX
//                           0 BOUCLE : vers M_AXIS (comme la 1.0, pour tester le DMA)
//                           1 TAMPON : vers le tampon de poids, mot après mot
//                           2 FILE   : vers la file de poids de la couche en flux
//   layer_engine         : le moteur, inchangé (rtl/moteur/)
//
// Les résultats (10 logits) se lisent par registres : M_AXIS ne sert qu'en BOUCLE.
// Timing : le vidage d'une sortie (biais, requant.sv et son produit 64 × 32 bits,
// écriture du tampon) tient en un cycle de 26,4 ns. FCLK_CLK0 passe donc à
// 33,33 MHz (leçon 6).
// =============================================================================

module npu_axi (
    input  wire        axi_aclk,
    input  wire        axi_aresetn,
    input  wire [11:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [11:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,
    input  wire [63:0] s_axis_tdata,
    input  wire [7:0]  s_axis_tkeep,
    input  wire        s_axis_tlast,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    output wire [63:0] m_axis_tdata,
    output wire [7:0]  m_axis_tkeep,
    output wire        m_axis_tlast,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready
);

    // Commande et état
    wire        start_s, busy_s, done_s;
    wire [1:0]  flux_s;
    // Chargement du tampon de poids par le flux
    wire        w_addr_load_s;
    wire [14:0] w_addr_val_s, w_addr_s;
    wire        w_we_s;
    wire [14:0] w_waddr_s;
    wire [63:0] w_wdata_s;
    // File de poids (couche en flux)
    wire [63:0] ws_tdata_s;
    wire        ws_tvalid_s, ws_tready_s;
    // Fenêtres vers les biais et les activations
    wire        bias_we_s;
    wire [9:0]  bias_waddr_s;
    wire [31:0] bias_wdata_s;
    wire        act_we_s;
    wire [10:0] act_waddr_s, act_raddr_s;
    wire [7:0]  act_wdata_s, act_rdata_s;
    // Descripteur de la couche
    wire [9:0]  n_s, m_s, bias_base_s;
    wire [14:0] w_base_s;
    wire [10:0] in_base_s, out_base_s;
    wire [31:0] m0_s;
    wire [4:0]  shift_s;
    wire [7:0]  zp_s;
    wire        relu_s, w_stream_s;

    npu_regs #(
        .addr_width_g(12),
        .version_g   (32'h4E50_5502)   // « NPU » en ASCII, version 02
    ) u_regs (
        .clock_i      (axi_aclk),
        .resetb_i     (axi_aresetn),
        .awaddr_i     (s_axi_awaddr),
        .awvalid_i    (s_axi_awvalid),
        .awready_o    (s_axi_awready),
        .wdata_i      (s_axi_wdata),
        .wstrb_i      (s_axi_wstrb),
        .wvalid_i     (s_axi_wvalid),
        .wready_o     (s_axi_wready),
        .bresp_o      (s_axi_bresp),
        .bvalid_o     (s_axi_bvalid),
        .bready_i     (s_axi_bready),
        .araddr_i     (s_axi_araddr),
        .arvalid_i    (s_axi_arvalid),
        .arready_o    (s_axi_arready),
        .rdata_o      (s_axi_rdata),
        .rresp_o      (s_axi_rresp),
        .rvalid_o     (s_axi_rvalid),
        .rready_i     (s_axi_rready),
        .start_o      (start_s),
        .busy_i       (busy_s),
        .done_i       (done_s),
        .flux_o       (flux_s),
        .w_addr_load_o(w_addr_load_s),
        .w_addr_val_o (w_addr_val_s),
        .w_addr_i     (w_addr_s),
        .bias_we_o    (bias_we_s),
        .bias_waddr_o (bias_waddr_s),
        .bias_wdata_o (bias_wdata_s),
        .act_we_o     (act_we_s),
        .act_waddr_o  (act_waddr_s),
        .act_wdata_o  (act_wdata_s),
        .act_raddr_o  (act_raddr_s),
        .act_rdata_i  (act_rdata_s),
        .n_o          (n_s),
        .m_o          (m_s),
        .w_base_o     (w_base_s),
        .in_base_o    (in_base_s),
        .out_base_o   (out_base_s),
        .bias_base_o  (bias_base_s),
        .m0_o         (m0_s),
        .shift_o      (shift_s),
        .zp_o         (zp_s),
        .relu_o       (relu_s),
        .w_stream_o   (w_stream_s)
    );

    npu_flux #(
        .w_addr_width_g(15)
    ) u_flux (
        .clock_i    (axi_aclk),
        .resetb_i   (axi_aresetn),
        .flux_i     (flux_s),
        .addr_load_i(w_addr_load_s),
        .addr_val_i (w_addr_val_s),
        .w_addr_o   (w_addr_s),
        .s_tdata_i  (s_axis_tdata),
        .s_tkeep_i  (s_axis_tkeep),
        .s_tlast_i  (s_axis_tlast),
        .s_tvalid_i (s_axis_tvalid),
        .s_tready_o (s_axis_tready),
        .m_tdata_o  (m_axis_tdata),
        .m_tkeep_o  (m_axis_tkeep),
        .m_tlast_o  (m_axis_tlast),
        .m_tvalid_o (m_axis_tvalid),
        .m_tready_i (m_axis_tready),
        .ws_tdata_o (ws_tdata_s),
        .ws_tvalid_o(ws_tvalid_s),
        .ws_tready_i(ws_tready_s),
        .w_we_o     (w_we_s),
        .w_waddr_o  (w_waddr_s),
        .w_wdata_o  (w_wdata_s)
    );

    layer_engine #(
        .nb_mac_g    (8),
        .w_depth_g   (32768),
        .act_depth_g (2048),
        .bias_depth_g(1024),
        .ws_depth_g  (16),
        .dim_width_g (10)
    ) u_moteur (
        .clock_i     (axi_aclk),
        .resetb_i    (axi_aresetn),
        .w_we_i      (w_we_s),
        .w_waddr_i   (w_waddr_s),
        .w_wdata_i   (w_wdata_s),
        .bias_we_i   (bias_we_s),
        .bias_waddr_i(bias_waddr_s),
        .bias_wdata_i(bias_wdata_s),
        .act_we_i    (act_we_s),
        .act_waddr_i (act_waddr_s),
        .act_wdata_i (act_wdata_s),
        .act_raddr_i (act_raddr_s),
        .act_rdata_o (act_rdata_s),
        .n_i         (n_s),
        .m_i         (m_s),
        .w_base_i    (w_base_s),
        .in_base_i   (in_base_s),
        .out_base_i  (out_base_s),
        .bias_base_i (bias_base_s),
        .m0_i        (m0_s),
        .shift_i     (shift_s),
        .zp_i        (zp_s),
        .relu_i      (relu_s),
        .w_stream_i  (w_stream_s),
        .ws_tdata_i  (ws_tdata_s),
        .ws_tvalid_i (ws_tvalid_s),
        .ws_tready_o (ws_tready_s),
        .start_i     (start_s),
        .busy_o      (busy_s),
        .done_o      (done_s)
    );

endmodule
