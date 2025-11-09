'''
Author:zhanghx(https://github.com/AdriftXCore)
date:2025-03-01 23:02:10
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

class SataLinkTestBench:

    def __init__(self, dut):
        self.dut = dut

        self.axis_host_source = AxiStreamSource(
            bus=AxiStreamBus.from_prefix(dut, "s_axis"), 
            clock=dut.clk,
            reset=dut.rst_n,
            reset_active_level=False
        )

        self.axis_dev_source = AxiStreamSource(
            bus=AxiStreamBus.from_prefix(dut, "s_dev_axis"),
            clock=dut.clk,
            reset=dut.rst_n,
            reset_active_level=False
        )

        self.axim_dev_sink = AxiStreamSink(
            bus=AxiStreamBus.from_prefix(dut, "m_axis"),
            clock=dut.clk,
            reset=dut.rst_n,
            reset_active_level=False
        )

        self.axim_host_sink = AxiStreamSink(
            bus=AxiStreamBus.from_prefix(dut, "m_host_axis"),
            clock=dut.clk,
            reset=dut.rst_n,
            reset_active_level=False
        )

        self.axis_host_source.log.setLevel(logging.WARNING)
        self.axim_dev_sink.log.setLevel(logging.WARNING)
        self.axis_dev_source.log.setLevel(logging.WARNING)
        self.axim_host_sink.log.setLevel(logging.WARNING)

        self.tx_crc_host_queue = Queue(maxsize=100)
        self.tx_crc_dev_queue = Queue(maxsize=100)
        self.rx_host_frame_queue = Queue()
        self.rx_dev_frame_queue = Queue()
        self.err_event_queue  = Queue()
        self.dev_event_queue = Queue()
        self.err_queue = Queue()

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
        self.dut.s_axis_tdata.value = 0
        self.dut.s_axis_tuser.value = 0
        self.dut.s_axis_tvalid.value = 0
        self.dut.m_axis_tready.value = 0
        self.dut.s_dev_axis_tdata.value = 0
        self.dut.s_dev_axis_tuser.value = 0
        self.dut.s_dev_axis_tvalid.value = 0
        self.dut.m_host_axis_tready.value = 0


        # await RisingEdge(self.dut.rst_n)
        for _ in range(10):
            await RisingEdge(self.dut.clk)
    async def timeout_watchdog(self, timeout: int, mode: int = 0) -> None:
        if(mode == 0):
            await ClockCycles(self.dut.clk, timeout)
            self.dut._log.error(f"---------------------------------timeout:{timeout} CYCLE ---------------------------------")
        else:
            await Timer(timeout, 'us')
            self.dut._log.error(f"---------------------------------timeout:{timeout} us ---------------------------------")
        raise SimTimeoutError
    
    def random_backpressure(self,n: float,seed: int) -> Generator[bool, None, None]:
        random.seed(seed)
        while True:
            yield random.random() < n

    async def apply_dev_backpressure(self,n: float,seek :int = 0):
        try:
            self.axim_dev_sink.set_pause_generator(self.random_backpressure(n,seek))
        except Exception as e:
            self.dut._log.error(f"backpresse failed: {e}")
            raise
    async def apply_host_backpressure(self,n: float,seek :int = 0):
        try:
            self.axim_host_sink.set_pause_generator(self.random_backpressure(n,seek))
        except Exception as e:
            self.dut._log.error(f"backpresse failed: {e}")
            raise

    async def apply_dev_valid_pause(self,n: float,seek :int = 0):
        try:
            self.axis_dev_source.set_pause_generator(self.random_backpressure(n,seek))
        except Exception as e:
            self.dut._log.error(f"backpresse failed: {e}")
            raise
    async def apply_host_valid_pause(self,n: float,seek :int = 0):
        try:
            self.axis_host_source.set_pause_generator(self.random_backpressure(n,seek))
        except Exception as e:
            self.dut._log.error(f"backpresse failed: {e}")
            raise
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
            # 发送
            await self.axis_host_source.send(frame)
        except Exception as e:
            self.dut._log.error(f"Error send: {e},the payload is {payload}")
            raise

    async def generate_test_packet(self, len: int, width: int,id: int) -> None:
        try:
            if(len == 0):
                len = 1
            crc32 = crcmod.Crc(0x104C11DB7, initCrc=0x52325032, rev=False, xorOut=0x00000000)
            id_num = id.to_bytes(4,"little")
            frame = id_num + bytearray(random.getrandbits(8) for _ in range((len-1)*int(width/8)))
            await self.send_packet(frame,int(width/8))
            crc32.update(frame)
            await self.tx_crc_host_queue.put(crc32.crcValue)
            await RisingEdge(self.dut.clk)
        except Exception as e:
            self.dut._log.error(f"packet failed: {e}")
            raise

    async def continuous_host_sender(self,width: int = 32) -> None:
        try:
            i = 0
            while True:
                random_len = random.getrandbits(9) + 1
                await self.generate_test_packet(random_len,width,i)
                i = i + 1
        except Exception as e:
            self.dut._log.error(f"Sender failed: {e}")
            raise

    async def send_dev_packet(self, payload: bytearray,bytewidth :int= 4):
        try:
            n = len(payload)
            tuser = [0] * n
            if n <= bytewidth:
                tuser = [3]*n
            elif (n % bytewidth) == 1:
                tuser[:bytewidth ] = [2] * bytewidth   # 第一字节标记SOP
                tuser[n-1] = 1
            else:
                tuser = [0] * n
                tuser[:bytewidth ] = [2] * bytewidth   # 第一字节标记SOP
                endn = bytewidth if (n % bytewidth == 0) else (n % bytewidth)
                tuser[-endn::] = [1] * endn # 最后字节标记EOP
            frame = AxiStreamFrame(
                tdata=payload,    # tdata
                tuser=tuser       
            )
            # 发送
            await self.axis_dev_source.send(frame)
        except Exception as e:
            self.dut._log.error(f"Error send: {e},the payload is {payload}")
            raise

    async def generate_dev_test_packet(self, len: int, width: int,id: int) -> None:
        try:
            if(len == 0):
                len = 1
            crc32 = crcmod.Crc(0x104C11DB7, initCrc=0x52325032, rev=False, xorOut=0x00000000)
            id_num = id.to_bytes(4,"little")
            frame = id_num + bytearray(random.getrandbits(8) for _ in range((len-1)*int(width/8)))
            await self.send_dev_packet(frame,int(width/8))
            crc32.update(frame)
            await self.tx_crc_dev_queue.put(crc32.crcValue)
            await RisingEdge(self.dut.clk)
        except Exception as e:
            self.dut._log.error(f"packet failed: {e}")
            raise

    async def continuous_dev_sender(self,width: int = 32) -> None:
        try:
            i = 0
            while True:
                random_len = random.getrandbits(9) + 1
                await self.dev_event_queue.get()
                await self.generate_dev_test_packet(random_len,width,i)
                i = i + 1
        except Exception as e:
            self.dut._log.error(f"Sender failed: {e}")
            raise

    async def host_receiver_monitor(self) -> None:
        '''
        host -> device
        '''
        try:
            recv_d = 0
            id = 0
            lens = 0
            cnt = 0
            sop_cnt = 0
            eop_cnt = 0
            while True:
                frame = await self.axim_dev_sink.recv()
                sop = (frame.tuser>>1) & 0x01
                eop = frame.tuser & 0x01
                if sop:
                    recv_d = 1
                    id = int.from_bytes(frame.tdata,"little")
                    frame_buffer = bytearray()
                    crc32 = crcmod.Crc(0x104C11DB7, initCrc=0x52325032, rev=False, xorOut=0x00000000)
                    sop_cnt += 1
                if recv_d:
                    frame_buffer.extend(frame.tdata)
                
                if(eop == 1):
                    recv_d = 0
                    eop_cnt += 1
                    lens = len(frame_buffer)
                    crc32.update(frame_buffer)
                    await self.rx_dev_frame_queue.put([frame.tdata,crc32.crcValue,id,cnt,lens,sop_cnt,eop_cnt])
                    self.dut._log.info(f"------H:QUEUE:{self.tx_crc_host_queue.qsize()},RECIEVE DATA,the CRC:{frame.tdata.hex()} the CCRC:{hex(crc32.crcValue)},the ID:{id},the COUNT:{cnt},the LEN:{lens} ,the SOP:{sop_cnt},the EOP:{eop_cnt}------")
                    cnt += 1
        except Exception as e:
            self.dut._log.error(f"receiver failed: {e}")
            raise

    async def device_receiver_monitor(self) -> None:
        '''
        device -> host
        '''
        try:
            recv_d = 0
            id = 0
            lens = 0
            cnt = 0
            sop_cnt = 0
            eop_cnt = 0
            while True:
                frame = await self.axim_host_sink.recv()
                sop = (frame.tuser>>1) & 0x01
                eop = frame.tuser & 0x01
                if sop:
                    recv_d = 1
                    id = int.from_bytes(frame.tdata,"little")
                    frame_buffer = bytearray()
                    crc32 = crcmod.Crc(0x104C11DB7, initCrc=0x52325032, rev=False, xorOut=0x00000000)
                    sop_cnt += 1
                if recv_d:
                    frame_buffer.extend(frame.tdata)
                
                if(eop == 1):
                    recv_d = 0
                    eop_cnt += 1
                    lens = len(frame_buffer)
                    crc32.update(frame_buffer)
                    await self.rx_host_frame_queue.put([frame.tdata,crc32.crcValue,id,cnt,lens,sop_cnt,eop_cnt])
                    self.dut._log.info(f"------D:QUEUE:{self.tx_crc_dev_queue.qsize()},RECIEVE DATA,the CRC:{frame.tdata.hex()} the CCRC:{hex(crc32.crcValue)},the ID:{id},the COUNT:{cnt},the LEN:{lens} ,the SOP:{sop_cnt},the EOP:{eop_cnt}------")
                    cnt += 1
        except Exception as e:
            self.dut._log.error(f"receiver failed: {e}")
            raise

    async def host_data_valodator(self) -> None:
        rx_frame = []
        while True:
            tx_crc = await self.tx_crc_host_queue.get()
            rx_frame = await self.rx_dev_frame_queue.get()
            rx_crc = int.from_bytes(rx_frame[0], "big")
            if(tx_crc != rx_crc):
                await self.err_queue.put(f"H:the packet id is:{rx_frame[2]},CRC CHECK ERROR, got {hex(tx_crc)},the result is {hex(rx_crc)}")
                self.dut._log.error(f"H:result failed: {rx_frame[2]},the verify result is {hex(tx_crc)},the hardware result is {hex(rx_crc)}")
            if(rx_frame[1] != 0):
                await self.err_queue.put(f"H:the packet id is:{rx_frame[2]},CCRC CHECK ERROR, the ccrc is {hex(rx_frame[1])}")
                self.dut._log.error(f"H:the packet id is:{rx_frame[2]},CCRC CHECK ERROR, the ccrc is {hex(rx_frame[1])}")
            if(rx_frame[5] != rx_frame[6]):
                await self.err_queue.put(f"H:the packet id is:{rx_frame[2]},CNT CHECK ERROR, the sop is {hex(rx_frame[5])},the eop is {hex(rx_frame[6])}")
                self.dut._log.error(f"H:the packet id is:{rx_frame[2]},CNT CHECK ERROR, the sop is {hex(rx_frame[5])},the eop is {hex(rx_frame[6])}")
            await self.err_event_queue.put(1)
            await self.dev_event_queue.put(1)

    async def dev_data_valodator(self) -> None:
        rx_frame = []
        while True:
            tx_crc = await self.tx_crc_dev_queue.get()
            rx_frame = await self.rx_host_frame_queue.get()
            rx_crc = int.from_bytes(rx_frame[0], "big")
            if(tx_crc != rx_crc):
                await self.err_queue.put(f"D:the packet id is:{rx_frame[2]},CRC CHECK ERROR, got {hex(tx_crc)},the result is {hex(rx_crc)}")
                self.dut._log.error(f"D:result failed: {rx_frame[2]},the verify result is {hex(tx_crc)},the hardware result is {hex(rx_crc)}")
            if(rx_frame[1] != 0):
                await self.err_queue.put(f"D:the packet id is:{rx_frame[2]},CCRC CHECK ERROR, the ccrc is {hex(rx_frame[1])}")
                self.dut._log.error(f"D:the packet id is:{rx_frame[2]},CCRC CHECK ERROR, the ccrc is {hex(rx_frame[1])}")
            if(rx_frame[5] != rx_frame[6]):
                await self.err_queue.put(f"D:the packet id is:{rx_frame[2]},CNT CHECK ERROR, the sop is {hex(rx_frame[5])},the eop is {hex(rx_frame[6])}")
                self.dut._log.error(f"D:the packet id is:{rx_frame[2]},CNT CHECK ERROR, the sop is {hex(rx_frame[5])},the eop is {hex(rx_frame[6])}")
            await self.err_event_queue.put(1)

# @cocotb.test()
async def check_sata_link_test(dut: SimHandle,dev_press: float=0.3,host_press:float=0.8,dev_valid:float=0.5,host_valid:float=0.5) -> None:
    try:
        # create TestBench
        tb = SataLinkTestBench(dut)

        # initial clock & reset
        clock = Clock(dut.clk, period=10, units="ns")
        cocotb.start_soon(clock.start()) 

        await tb.reset()

        # initial TestBench
        await tb.init()
        # host -> dev
        dut._log.info("------------------ initial apply_dev_backpressure_task ------------------")
        apply_dev_backpressure_task = cocotb.start_soon(tb.apply_dev_backpressure(dev_press))
        dut._log.info("------------------ initial continuous_host_sender_task ------------------")
        continuous_host_sender_task  = cocotb.start_soon(tb.continuous_host_sender())
        dut._log.info("------------------ initial host_receiver_monitor------------------")
        host_receiver_monitor   = cocotb.start_soon(tb.host_receiver_monitor())
        dut._log.info("------------------ initial host_data_valodator ------------------")
        host_data_valodator     = cocotb.start_soon(tb.host_data_valodator())
        dut._log.info("------------------ initial apply_host_backpressure_task ------------------")
        apply_host_valid_pause_task = cocotb.start_soon(tb.apply_host_valid_pause(host_valid))

        #dev -> host
        dut._log.info("------------------ initial apply_host_backpressure_task ------------------")
        apply_host_backpressure_task = cocotb.start_soon(tb.apply_host_backpressure(host_press))
        dut._log.info("------------------ initial continuous_dev_sender_task ------------------")
        continuous_dev_sender_task = cocotb.start_soon(tb.continuous_dev_sender())
        dut._log.info("------------------ initial device_receiver_monitor_task ------------------")
        device_receiver_monitor_task   = cocotb.start_soon(tb.device_receiver_monitor())
        dut._log.info("------------------ initial dev_data_valodator_task ------------------")
        dev_data_valodator_task = cocotb.start_soon(tb.dev_data_valodator())
        dut._log.info("------------------ initial apply_devs_backpressure_task ------------------")
        apply_dev_valid_pause_task = cocotb.start_soon(tb.apply_dev_valid_pause(dev_valid))

        for _ in range(100):
            err = 0
            await tb.err_event_queue.get()
            if not tb.err_queue.empty():
                err = await tb.err_queue.get()
            await RisingEdge(dut.clk)
            assert err == 0,f"TEST FAIL:{err}"

        await RisingEdge(dut.clk)
        apply_dev_backpressure_task.kill()
        continuous_host_sender_task.kill()
        host_receiver_monitor.kill()
        host_data_valodator.kill()
        apply_host_valid_pause_task.kill()

        apply_host_backpressure_task.kill()
        continuous_dev_sender_task.kill()
        device_receiver_monitor_task.kill()
        dev_data_valodator_task.kill()
        apply_dev_valid_pause_task.kill()

        dut._log.info("--------------------------------Test Completed--------------------------------")
    except Exception as e:
        traceback.print_exc()
        raise

factory = TestFactory(check_sata_link_test)
factory.add_option("dev_press",[0.8,0.3,0])
factory.add_option("host_press",[0.8,0.3,0])
factory.add_option("dev_valid",[0,0.8])
factory.add_option("host_valid",[0,0.8])
factory.generate_tests()

################################################################### RUN TEST ###################################################################

import os
import pytest

def test_run(request):
    parameters = {}

    os.environ["SIM"] = "vcs"
    os.environ["WAVES"] = "0"
    simulator = os.environ.get("SIM", "")
    waves = os.environ.get("WAVES", "")

    adcore_test_run(request,ctb="cocotb_top",tc="tb_top",wave=waves,sim=simulator,parameters=parameters)
