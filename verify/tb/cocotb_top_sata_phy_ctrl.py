'''
Author:zhanghx(https://github.com/AdriftXCore)
date:2025-03-01 23:02:10
'''
import cocotb
from cocotb.handle import SimHandle
from cocotb.triggers import *
from cocotb.result import SimTimeoutError
from cocotb.clock import Clock


async def timeout_watchdog(dut: SimHandle, timeout: int, mode: int = 0) -> None:
    if(mode == 0):
        await ClockCycles(dut.clk, timeout)
        dut._log.error(f"---------------------------------timeout:{timeout} CYCLE ---------------------------------")
    else:
        await Timer(timeout, 'us')
        await RisingEdge(dut.clk)
        dut._log.error(f"---------------------------------timeout:{timeout} us ---------------------------------")
    raise SimTimeoutError

async def send_phy(dut: SimHandle):
    try:
        await ClockCycles(dut.clk,300)
        while True:
            await RisingEdge(dut.clk)
            await ReadOnly()
            if(dut.tx_cominit.value == 0):
                break
        await RisingEdge(dut.clk)
        await Timer(100, units="ns")
        dut.rx_cominit.value = 1
        await Timer(100, units="ns")
        dut.rx_cominit.value = 0
        await RisingEdge(dut.clk)

        #SEND comwake
        while True:
            await RisingEdge(dut.clk)
            await ReadOnly()
            if(dut.tx_comwake.value):
                break
        await Timer(105, units="ns")
        dut.rx_comwake.value = 1
        await Timer(100, units="ns")
        dut.rx_comwake.value = 0
        await RisingEdge(dut.clk)

        #SEND ALIHNP
        i = 0
        while True:
            await Timer(20, units="ns")
            if dut.tx_data.value == 0x4a4a4a4a:
                i = i + 1
            if(i == 6):
                break
        await RisingEdge(dut.clk)
        await Timer(100, units="ns")
        for i in range(300):
            dut.rx_data.value = 0xbc4a4a7b
            dut.rx_charisk.value = 0b1000
            await RisingEdge(dut.clk)
        dut.rx_data.value = 0x7c95b5b5
        dut.rx_charisk.value = 0b1000
        await Timer(1000, units="ns")
        await RisingEdge(dut.clk)


    except Exception as e:
        dut._log.error(f"Check failed: {e}")
        raise



@cocotb.test()
async def sata_phy_test(dut: SimHandle):
    try:
        clock = Clock(dut.clk, period=20, units="ns")
        cocotb.start_soon(clock.start()) 
        watchdog_task = cocotb.start_soon(timeout_watchdog(dut, 100000))
        send_task     = cocotb.start_soon(send_phy(dut))

        await ClockCycles(dut.clk,5000)

        watchdog_task.kill()
        send_task.kill()
    except Exception as e:
        dut._log.error(f"Check failed: {e}")
        raise
