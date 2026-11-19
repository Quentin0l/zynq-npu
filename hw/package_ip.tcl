# package_ip.tcl : empaquette le NPU (rtl/axi/npu_axi.v et ce qu'il instancie) en IP Vivado.
# Le dossier rtl/ devient le dépôt d'IP : component.xml et xgui/ y sont écrits,
# à côté des sources, qui ne sont jamais copiées.
# Lancer depuis la racine du dépôt :  vivado -mode batch -source hw/package_ip.tcl
set racine [file normalize [file dirname [info script]]/..]

# 1. Un projet jetable qui contient les sources de l'IP : l'enveloppe, ses
#    registres, l'aiguillage du flux, et le moteur.
set axi    [list npu_axi.v npu_regs.sv npu_flux.sv]
set moteur [list mac.sv mac_row.sv weight_buffer.sv pass_engine.sv requant.sv \
                 lut_ram.sv weight_fifo.sv layer_seq.sv layer_engine.sv]
create_project -force npu_ip $racine/hw/build/npu_ip -part xc7z020clg484-1
foreach f $axi    { add_files -norecurse $racine/rtl/axi/$f }
foreach f $moteur { add_files -norecurse $racine/rtl/moteur/$f }
set_property top npu_axi [current_fileset]
update_compile_order -fileset sources_1

# 2. L'empaquetage : Vivado infère s_axi, s_axis, m_axis, l'horloge et le reset.
ipx::package_project -root_dir $racine/rtl -vendor quentin.local -library user \
    -taxonomy /UserIP -force
set ip [ipx::current_core]
set_property display_name {NPU} $ip
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
