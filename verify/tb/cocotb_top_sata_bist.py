'''
Author:zhanghx(https://github.com/AdriftXCore)
date:2025-11-06 22:02:10
'''
import random
import cocotb
from cocotb.handle import SimHandle
from typing import Generator
from cocotb.triggers import *
from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame
from cocotb.queue import Queue
from cocotb.result import SimTimeoutError

from cocotb.clock import Clock
from cocotb.regression import TestFactory

import crcmod

from adcore_cocotb_test_run import adcore_test_run
import traceback
import logging

class SataBistTestBench:
    def __init__(self,dut):
        self.dut = dut

        self.dut.rst_n.value = 0
        self.axis_source = AxiStreamSource(
            bus=AxiStreamBus.from_prefix(dut, "s_axis_usr"),
            clock=dut.clk,
            reset=dut.rst_n,
            reset_active_level=False
        )

        self.axim_sink = AxiStreamSink(
            bus=AxiStreamBus.from_prefix(dut, "m_axis_usr"),
            clock=dut.clk,
            reset=dut.rst_n,
            reset_active_level=False
        )

        self.axis_source.log.setLevel(logging.WARNING)
        self.axim_sink.log.setLevel(logging.WARNING)

        self.stream_queue = Queue()
        self.event_queue  = Queue()
    async def reset(self):
        self.dut.rst_n.setimmediatevalue(1)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst_n.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst_n.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)

    async def init(self):
        self.dut.mode.value = 0
        self.dut.tirg.value = 0
        self.dut.cycle.value = 0
        self.dut.num.value = 0
        self.dut.addr.value = 0
        self.dut.enable.value = 0
        self.dut.cmd_ack.value = 0
        self.dut.s_axis_usr_tdata.value = 0
        self.dut.s_axis_usr_tuser.value = 0
        self.dut.s_axis_usr_tvalid.value = 0
        self.dut.m_axis_usr_tready.value = 0

        for _ in range(10):
            await RisingEdge(self.dut.clk)

    async def open(self):
        self.dut.mode.value = 0
        self.dut.tirg.value = 0
        self.dut.cycle.value = 0
        self.dut.num.value = 0
        self.dut.addr.value = 0
        self.dut.enable.value = 0
        self.dut.cmd_ack.value = 0
        self.dut.speed_test.value = 0
        for _ in range(10):
            await RisingEdge(self.dut.clk)
        self.dut.mode.value = 0
        self.dut.cycle.value = 4
        self.dut.num.value = 0x4000
        self.dut.addr.value = 0
        self.dut.enable.value = 1
        self.dut.speed_test.value = 1

        for _ in range(10):
            await RisingEdge(self.dut.clk)

    def random_backpressure(self,n: float,seed: int) -> Generator[bool, None, None]:
        random.seed(seed)
        while True:
            yield random.random() < n

    async def apply_backpressure(self,n: float,seek :int = 0) -> None:
        try:
            self.axim_sink.set_pause_generator(self.random_backpressure(n,seek))
        except Exception as e:
            self.dut._log.error(f"backpresse failed: {e}")
            raise

    async def apply_valid_pause(self,n: float,seek :int = 0) -> None:
        try:
            self.axis_source.set_pause_generator(self.random_backpressure(n,seek))
        except Exception as e:
            self.dut._log.error(f"backpresse failed: {e}")
            raise
    async def receiver_monitor(self) -> None:
        while True:
            frame = await self.axim_sink.recv()
            sop = (frame.tuser>>1) & 0x01
            eop = frame.tuser & 0x01
            if sop:
                recv_d = 1
                frame_buffer = bytearray()
            if recv_d:
                frame_buffer.extend(frame.tdata)
            
            if eop:
                recv_d = 0
                await self.stream_queue.put(frame_buffer)
    async def sender_test(self) -> None:
        while True:
            tx_frame = await self.stream_queue.get()
            await self.send_packet(tx_frame)
            await self.event_queue.put(1)
    async def send_packet(self, payload: bytearray,bytewidth :int= 4):
        try:
            n = len(payload)
            tuser = [0] * n
            if n <= bytewidth:
                tuser = [3]*n
            elif (n % bytewidth) == 1:
                tuser[:bytewidth ] = [2] * bytewidth
                tuser[n-1] = 1
            else:
                tuser = [0] * n
                tuser[:bytewidth ] = [2] * bytewidth
                endn = bytewidth if (n % bytewidth == 0) else (n % bytewidth)
                tuser[-endn::] = [1] * endn
            frame = AxiStreamFrame(
                tdata=payload,    # tdata
                tuser=tuser       
            )
            await self.axis_source.send(frame)
        except Exception as e:
            self.dut._log.error(f"Error send: {e},the payload is {payload}")
            raise
    async def packet_ack(self):
        while True:
            while True:
                await RisingEdge(self.dut.clk)
                await ReadOnly()
                if self.dut.cmd_req.value:
                    break
            await RisingEdge(self.dut.clk)
            self.dut.cmd_ack.value = 1
            await RisingEdge(self.dut.clk)
            self.dut.cmd_ack.value = 0
@cocotb.test()
async def check_sata_bist_test(dut:SimHandle):
    try:
        # create TestBench
        tb = SataBistTestBench(dut)

        # initial clock & reset
        clock = Clock(dut.clk, period=10, units="ns")
        cocotb.start_soon(clock.start()) 
        await tb.reset()

        await tb.init()

        await tb.open()

        receiver_task = cocotb.start_soon(tb.receiver_monitor())
        sender_task = cocotb.start_soon(tb.sender_test())
        packet_ack_task = cocotb.start_soon(tb.packet_ack())
        apply_backpressure_task = cocotb.start_soon(tb.apply_backpressure(0.5))

        i = 0
        for _ in range(100):
            await tb.event_queue.get()
            i = i + 1
            dut._log.info(f"====== SEND {i} PACKET ======")
            await RisingEdge(dut.clk)

        await RisingEdge(dut.clk)

        receiver_task.kill()
        sender_task.kill()
        packet_ack_task.kill()
        apply_backpressure_task.kill()

    except Exception as e:
        traceback.print_exc()
        raise


################################################################### RUN TEST ###################################################################
import os
import pytest
import os,shutil
from pathlib import Path

tests_dir = '../sim/'
@pytest.fixture(scope="session", autouse=True)
def clean_sim_build():
    sim_build_path = Path(f'{tests_dir}/sim_build').resolve()
    if os.path.exists(sim_build_path):
        shutil.rmtree(sim_build_path)
def test_run(request):
    parameters = {}

    os.environ["SIM"] = "vcs"
    os.environ["WAVES"] = "0"
    simulator = os.environ.get("SIM", "")
    waves = os.environ.get("WAVES", "")

    adcore_test_run(request,ctb="cocotb_top_sata_bist",tc="tb_top_sata_bist",wave=waves,sim=simulator,parameters=parameters)
