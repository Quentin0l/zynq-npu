# package_ip.tcl : empaquette l'enveloppe du NPU (rtl/axi/npu_axi.v) en IP Vivado.
# Le dossier rtl/ devient le dépôt d'IP : component.xml et xgui/ y sont écrits,
# à côté des sources, qui ne sont jamais copiées.
# Lancer depuis la racine du dépôt :  vivado -mode batch -source hw/package_ip.tcl
set racine [file normalize [file dirname [info script]]/..]

# 1. Un projet jetable qui contient les sources de l'IP.
create_project -force npu_ip $racine/hw/build/npu_ip -part xc7z020clg484-1
add_files -norecurse [list $racine/rtl/axi/npu_axi.v $racine/rtl/axi/npu_regs.sv]
set_property top npu_axi [current_fileset]
update_compile_order -fileset sources_1

# 2. L'empaquetage : Vivado infère s_axi, s_axis, m_axis, l'horloge et le reset.
ipx::package_project -root_dir $racine/rtl -vendor quentin.local -library user \
    -taxonomy /UserIP -force
set ip [ipx::current_core]
set_property display_name {NPU (coquille)} $ip
set_property description {NPU int8 : registres AXI4-Lite, flux AXI4-Stream 64 bits} $ip

# 3. Ce que Vivado ne devine pas : axi_aclk cadence aussi les deux flux.
ipx::associate_bus_interfaces -busif s_axis -clock axi_aclk $ip
ipx::associate_bus_interfaces -busif m_axis -clock axi_aclk $ip

# 4. Vérifier, enregistrer.
ipx::create_xgui_files $ip
ipx::update_checksums $ip
ipx::check_integrity $ip
ipx::save_core $ip
close_project
