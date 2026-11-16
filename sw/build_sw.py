# build_sw.py : reconstruit la plateforme et l'application depuis git, dans un
# workspace jetable (sw/ci), pour vérifier que tout compile.
# Lancer depuis la racine du dépôt :  vitis -s sw/build_sw.py
import os
import shutil
import vitis

sw = os.path.dirname(os.path.abspath(__file__))
ws = os.path.join(sw, "ci")
xsa = os.path.normpath(os.path.join(sw, "..", "hw", "build", "system.xsa"))
shutil.rmtree(ws, ignore_errors=True)

client = vitis.create_client()
client.set_workspace(ws)

# 1. La plateforme : le XSA, un domaine standalone sur le premier Cortex-A9.
plateforme = client.create_platform_component(
    name="zed_npu", hw_design=xsa, os="standalone",
    cpu="ps7_cortexa9_0", domain_name="standalone_ps7_cortexa9_0")
plateforme.build()

# 2. L'application : vide, plus les sources du dépôt.
app = client.create_app_component(
    name="npu_hello", platform=client.find_platform_in_repos("zed_npu"),
    domain="standalone_ps7_cortexa9_0", template="empty_application")
app.import_files(from_loc=os.path.join(sw, "npu_hello", "src"), files=["main.c"])
app.build()

vitis.dispose()
