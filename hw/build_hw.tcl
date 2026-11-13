# build_hw.tcl : reconstruit le système depuis le dépôt : projet, block design,
# bitstream, puis le XSA que lira Vitis (hw/build/system.xsa).
# Prérequis : l'IP du NPU est empaquetée (hw/package_ip.tcl), et le block design
# est exporté dans hw/bd/system.tcl (File → Export → Export Block Design).
# Lancer depuis hw/build :  vivado -mode batch -source ../build_hw.tcl
set racine [file normalize [file dirname [info script]]/..]

# 1. Le projet, sur la carte ZedBoard. En batch, Vivado ne charge pas le magasin
#    de cartes XHub : on lui dit où il se trouve.
set_param board.repoPaths [list [file normalize ~/.Xilinx/Vivado/2026.1/xhub/board_store/xilinx_board_store/XilinxBoardStore/Vivado/2026.1/boards]]
create_project -force npu_zed $racine/hw/build/npu_zed -part xc7z020clg484-1
set_property board_part [lindex [get_board_parts *zedboard*] end] [current_project]

# 2. Le dépôt d'IP : rtl/, où vit l'IP du NPU.
set_property ip_repo_paths [list $racine/rtl] [current_project]
update_ip_catalog

# 3. Le block design, recréé par le script de write_bd_tcl, puis son enveloppe HDL.
source $racine/hw/bd/system.tcl
validate_bd_design
save_bd_design
make_wrapper -files [get_files system.bd] -top
add_files -norecurse [glob $racine/hw/build/npu_zed/npu_zed.gen/sources_1/bd/system/hdl/system_wrapper.v]
set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1

# 4. Synthèse, implémentation, bitstream. Deux tâches à la fois : la mémoire suit.
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
set wns [get_property STATS.WNS [get_runs impl_1]]
set whs [get_property STATS.WHS [get_runs impl_1]]
puts "TIMING : WNS = $wns ns, WHS = $whs ns"
if {$wns < 0 || $whs < 0} {
    error "Timing non respecté : pas de XSA."
}

# 5. Le XSA, bitstream compris.
write_hw_platform -fixed -include_bit -force $racine/hw/build/system.xsa
puts "XSA : $racine/hw/build/system.xsa"
