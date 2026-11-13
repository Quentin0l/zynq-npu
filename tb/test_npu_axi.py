# test_npu_axi.py : banc cocotb de l'IP npu_axi, l'enveloppe AXI du NPU (leçon 2).
# Provenance : leçon 2 du parcours « NPU sur ZedBoard » (fourni).
#
# Le même contrôle que hw/sim/tb_npu_axi.sv (xsim, sur le PC Linux), mais dans la
# chaîne cocotb + Verilator du dépôt, pour le Mac et, plus tard, la CI.
# Les maîtres AXI viennent de cocotbext-axi (pip install cocotbext-axi).
#
# Lancer, depuis tb/ :
#   make TOP=npu_axi TESTS=test_npu_axi SRCS="../rtl/axi/npu_regs.sv ../rtl/axi/npu_axi.v"

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotbext.axi import (AxiLiteBus, AxiLiteMaster, AxiStreamBus,
                           AxiStreamFrame, AxiStreamSink, AxiStreamSource)

VERSION, SCRATCH, CYCLES = 0x00, 0x04, 0x08


async def demarrer(dut):
    """Horloge, reset, et un maître AXI4-Lite branché sur S_AXI."""
    Clock(dut.axi_aclk, 10, "ns").start()
    dut.axi_aresetn.value = 0
    await ClockCycles(dut.axi_aclk, 3)
    dut.axi_aresetn.value = 1
    await ClockCycles(dut.axi_aclk, 2)
    return AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axi"), dut.axi_aclk,
                         dut.axi_aresetn, reset_active_level=False)


@cocotb.test
async def test_version(dut):
    """R1 : VERSION vaut « NPU » + 0x01, et ne s'écrit pas."""
    axil = await demarrer(dut)
    assert await axil.read_dword(VERSION) == 0x4E50_5501
    await axil.write_dword(VERSION, 0xFFFF_FFFF)
    assert await axil.read_dword(VERSION) == 0x4E50_5501


@cocotb.test
async def test_scratch(dut):
    """R2 : SCRATCH relit ce qu'on y écrit, octet par octet (WSTRB)."""
    axil = await demarrer(dut)
    assert await axil.read_dword(SCRATCH) == 0
    await axil.write_dword(SCRATCH, 0xDEAD_BEEF)
    assert await axil.read_dword(SCRATCH) == 0xDEAD_BEEF
    # Un seul octet, le n° 2 : le maître pose WSTRB = 0b0100.
    await axil.write(SCRATCH + 2, b"\x22")
    assert await axil.read_dword(SCRATCH) == 0xDE22_BEEF


@cocotb.test
async def test_cycles(dut):
    """R3 : CYCLES avance d'un pas par front."""
    axil = await demarrer(dut)
    c1 = await axil.read_dword(CYCLES)
    await ClockCycles(dut.axi_aclk, 100)
    c2 = await axil.read_dword(CYCLES)
    assert 100 <= c2 - c1 <= 130, f"CYCLES a avancé de {c2 - c1} en un peu plus de 100 fronts"


@cocotb.test
async def test_boucle(dut):
    """S_AXIS → M_AXIS : un paquet de 20 octets ressort intact, TLAST et TKEEP compris."""
    await demarrer(dut)
    source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.axi_aclk,
                             dut.axi_aresetn, reset_active_level=False)
    puits = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.axi_aclk,
                          dut.axi_aresetn, reset_active_level=False)
    paquet = bytes(range(20))   # 2 mots pleins et un mot de 4 octets (TKEEP = 0x0F)
    await source.send(AxiStreamFrame(paquet))
    recu = await puits.recv()
    assert bytes(recu.tdata) == paquet
