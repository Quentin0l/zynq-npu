`timescale 1ns / 1ps
// Provenance : leçon 2 du parcours « NPU sur ZedBoard » (fourni).

// =============================================================================
// npu_axi.v : l'enveloppe du NPU, le module de tête de son IP Vivado.
//
// Pourquoi un fichier Verilog-2001 au milieu d'un dépôt SystemVerilog ? Parce
// que l'IP Packager de Vivado n'accepte pas un module de tête en SystemVerilog
// (UG1118, « Package a Specified Directory » : « wrap in a Verilog top before
// packaging »). Les modules qu'il instancie, eux, restent en SystemVerilog.
//
// L'enveloppe parle la langue de Vivado, le cœur parle ISMIN :
//   - les ports suivent les noms standard d'AXI (s_axi_*, s_axis_*, m_axis_*),
//     pour que Vivado reconnaisse seul les trois interfaces ;
//   - l'horloge s'appelle axi_aclk et le reset axi_aresetn (actif bas, d'après
//     le « n » final), sans préfixe s_ ou m_, pour qu'ils servent aux trois
//     interfaces à la fois (UG994, « Inferring AXI Interfaces ») ;
//   - à l'intérieur, on retrouve clock_i, resetb_i et les suffixes _i / _o.
//
// Version 1.0 de l'IP : une coquille. Les interfaces sont déjà les définitives,
// l'intérieur ne l'est pas encore :
//   - S_AXI  : les registres de npu_regs.sv (VERSION, SCRATCH, CYCLES) ;
//   - S_AXIS → M_AXIS : une boucle de retour, mot pour mot. Elle servira à
//     mettre au point l'AXI DMA (leçon 5), avant d'être remplacée par le NPU.
// =============================================================================

module npu_axi (
    input  wire        axi_aclk,
    input  wire        axi_aresetn,
    // S_AXI : les registres (AXI4-Lite, esclave)
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
    // S_AXIS : le flux entrant (AXI4-Stream, esclave), 8 octets par mot
    input  wire [63:0] s_axis_tdata,
    input  wire [7:0]  s_axis_tkeep,
    input  wire        s_axis_tlast,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    // M_AXIS : le flux sortant (AXI4-Stream, maître)
    output wire [63:0] m_axis_tdata,
    output wire [7:0]  m_axis_tkeep,
    output wire        m_axis_tlast,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready
);

    // -------------------------------------------------------------------------
    // Les registres.
    // -------------------------------------------------------------------------
    npu_regs #(
        .addr_width_g(12),
        .version_g   (32'h4E50_5501)   // « NPU » en ASCII, puis la version 01
    ) u_regs (
        .clock_i  (axi_aclk),
        .resetb_i (axi_aresetn),
        .awaddr_i (s_axi_awaddr),
        .awvalid_i(s_axi_awvalid),
        .awready_o(s_axi_awready),
        .wdata_i  (s_axi_wdata),
        .wstrb_i  (s_axi_wstrb),
        .wvalid_i (s_axi_wvalid),
        .wready_o (s_axi_wready),
        .bresp_o  (s_axi_bresp),
        .bvalid_o (s_axi_bvalid),
        .bready_i (s_axi_bready),
        .araddr_i (s_axi_araddr),
        .arvalid_i(s_axi_arvalid),
        .arready_o(s_axi_arready),
        .rdata_o  (s_axi_rdata),
        .rresp_o  (s_axi_rresp),
        .rvalid_o (s_axi_rvalid),
        .rready_i (s_axi_rready)
    );

    // -------------------------------------------------------------------------
    // La boucle de retour : ce qui entre ressort, tel quel. Le TREADY remonte
    // du puits vers la source, le TVALID et les données descendent.
    // -------------------------------------------------------------------------
    assign m_axis_tdata  = s_axis_tdata;
    assign m_axis_tkeep  = s_axis_tkeep;
    assign m_axis_tlast  = s_axis_tlast;
    assign m_axis_tvalid = s_axis_tvalid;
    assign s_axis_tready = m_axis_tready;

endmodule
