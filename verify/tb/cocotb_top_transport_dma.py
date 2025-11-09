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
from cocotb.queue import Queue, QueueEmpty
from cocotb.result import SimTimeoutError
from cocotb.clock import Clock
from cocotb.result import TestFailure

from enum import IntEnum
import logging
import random
from crcmod.predefined import mkPredefinedCrcFun
import traceback

from cocotb.regression import TestFactory
import pytest

from adcore_cocotb_test_run import adcore_test_run
async def timeout_watchdog(dut: SimHandle, timeout: int, mode: int = 0) -> None:
    if(mode == 0):
        await ClockCycles(dut.clk, timeout)
        dut._log.error(f"---------------------------------timeout:{timeout} CYCLE ---------------------------------")
    else:
        await Timer(timeout, 'us')
        dut._log.error(f"---------------------------------timeout:{timeout} us ---------------------------------")
    raise SimTimeoutError

# fis type define
class FISType(IntEnum):
    REG_H2D   = 0x27
    REG_D2H   = 0x34
    DMA_ACT   = 0x39
    DMA_SETUP = 0x41
    DATA      = 0x46
    BIST      = 0x58
    PIO_SETUP = 0x5F
    DEV_BITS  = 0xA1

# command enum
class ATACommand(IntEnum):
    IDENTIFY_DEVICE = 0xEC
    READ_DMA        = 0xC8
    WRITE_DMA       = 0xCA
    READ_FPDMA      = 0x60
    WRITE_FPDMA     = 0x61
    WRITE_REQ       = 0x35
    READ_REQ        = 0x25

# user signal
class UserBits(IntEnum):
    EOP = 0  # End of Packet
    SOP = 1  # Start of Packet
    KEEP_OFFSET = 2  # 4-bit keep field
    ERR = 6  # Error
    DROP = 7  # Drop


# register FIS parser
class FISParser:
    @staticmethod
    def parse_reg_h2d(data: bytearray):
        """parser H2D register FIS"""
        if data[0] != FISType.REG_H2D:
            raise ValueError("Invalid H2D FIS type")
        return {
            'type': data[0],
            'flags': data[1],
            'command': data[2],
            'features': data[3],
            'lba_low': data[4],
            'lba_mid': data[5],
            'lba_high': data[6],
            'device': data[7],
            'lba_low_exp': data[8],
            'lba_mid_exp': data[9],
            'lba_high_exp': data[10],
            'features_exp': data[11],
            'sector_count': data[12],
            'sector_count_exp': data[13],
            'control': data[15]
        }
    @staticmethod
    def create_reg_d2h(status=0, error=0, **kwargs):
        """create D2H register FIS"""
        fis = bytearray(20)
        fis[0] = FISType.REG_D2H
        fis[1] = 0 
        fis[2] = status
        fis[3] = error
        return fis

# SATA Device Model
class SATADeviceModel:
    def __init__(self):
        self.current_command = None
        self.identity_data = self._generate_identify_data()
        self.write_count = 0
        self.read_count  = 0

        self.read_req_queue = Queue()
    
    def _generate_identify_data(self):
        """生成IDENTIFY DEVICE数据结构"""
        data = bytearray(512)
        data[83*2]  = 0x40
        return data
    
    async def process_command(self, fis: bytearray):
        if fis[0] == FISType.DATA:
            return self._handle_write_dma(1) 
        elif fis[0] == 0xff:
            return self._handle_write_dma(0)
        elif fis[1] == ATACommand.IDENTIFY_DEVICE:
            return self._handle_identify()
        elif fis[1] == ATACommand.WRITE_REQ:
            self.write_count = int.from_bytes(fis[14:16],byteorder="big")
            return self._handle_write_dma(0)
        elif fis[1] == ATACommand.READ_REQ:
            self.read_count  = int.from_bytes(fis[14:16],byteorder="big")
            await self.read_req_queue.put(1)
            return []
        else:
            return []


    def process_cpl(self,rw_cpl : int):
        if(rw_cpl == 1):
            return self._handle_read_dma() 
        else:
            return self._handle_write_dma(1) 
    def parse_reg_h2d(self, data):
        """解析H2D寄存器FIS"""
        if data[0] != FISType.REG_H2D:
            raise ValueError("Invalid H2D FIS type")
        
        return {
            'type': data[0],
            'flags': data[1],
            'command': data[2],
            'features': data[3],
            'lba_low': data[4],
            'lba_mid': data[5],
            'lba_high': data[6],
            'device': data[7],
            'lba_low_exp': data[8],
            'lba_mid_exp': data[9],
            'lba_high_exp': data[10],
            'features_exp': data[11],
            'sector_count': data[12],
            'sector_count_exp': data[13],
            'control': data[15]
        }
    
    def create_pio_setup_fis(self, transfer_count=1):
        fis = bytearray(20) #FIS type
        fis[3] = FISType.PIO_SETUP  # I/D/PM
        fis[2] = 0x20  # I/D/PM
        fis[1] = 0x50  # status,DRQ(0x08) | DSC(0x04) | SERVICE(0x10) | READY(0x40)
        fis[0] = 0x00  #error

        fis[7] = 0x00  # LBA[7:0]
        fis[6] = 0x00  # LBA[15:8]
        fis[5] = 0x00  # LBA[23:16]
        fis[4] = 0x00  # deveice

        fis[11] = 0x00  # LBA[31:24]
        fis[10] = 0x00  # LBA[38:32]
        fis[9]  = 0x00  # LBA[47:40]
        fis[8]  = 0x00  # reserve

        fis[15] = 0x00
        fis[14] = 0x00
        fis[13] = 0x00
        fis[12] = 0x00  #E_Stauts

        fis[16] = 0x00
        fis[17] = 0x00
        fis[18] = (transfer_count>>8) & 0xff
        fis[19] = transfer_count & 0xff
        return fis
    
    def create_dma_active(self):
        fis = bytearray(4)
        fis[0] = 0x00
        fis[1] = 0x00
        fis[2] = 0x00
        fis[3] = 0x39
        return fis
    
    def create_data_fis(self, data):
        """创建DATA FIS"""
        # DATA FIS格式: FIS类型(1字节) + 数据(512字节)
        fis = bytearray(4)
        fis[0] = 0x00
        fis[1] = 0x00
        fis[2] = 0x00
        fis[3] = FISType.DATA
        fis.extend(data)
        return fis
    
    def create_reg_d2h_fis(self, status=0, error=0):
        """创建D2H寄存器FIS"""
        fis = bytearray(20)
        fis[3] = FISType.REG_D2H
        fis[2] = 0x00  
        fis[1] = status
        fis[0] = error
        return fis
    
    def _handle_identify(self):
        """处理IDENTIFY DEVICE命令"""
        responses = []
        
        # send PIO SETUP
        pio_setup = self.create_pio_setup_fis(transfer_count=512)
        responses.append(pio_setup)
        
        # send identify data
        data_fis = self.create_data_fis(self.identity_data)
        responses.append(data_fis)

        return responses
    
    def _handle_write_dma(self, fis: int):
        #write req
        responses = []
        if fis == 0: 
            dma_active = self.create_dma_active()
            responses.append(dma_active)
            return responses
        #write data complete
        elif fis == 1:
            responses.append(self.create_reg_d2h_fis())
            return responses
        else:
            return 0
    

    def _handle_read_dma(self):
        response = []
        response.append(self.create_reg_d2h_fis())
        return response

class SATATestbench:
    def __init__(self, dut):
        self.dut = dut

        self.dut.rst_n.value = 0

        self.host_to_device_sink = AxiStreamSink(
            bus=AxiStreamBus.from_prefix(dut, "m_aixs_link"),
            clock=dut.clk,
            reset=dut.rst_n,
            reset_active_level=False
        )
        
        self.device_to_host_source = AxiStreamSource(
            bus=AxiStreamBus.from_prefix(dut, "s_aixs_link"),
            clock=dut.clk,
            reset=dut.rst_n,
            reset_active_level=False
        )
        
        self.device_to_host_sink = AxiStreamSink(
            bus=AxiStreamBus.from_prefix(dut, "m_aixs_cmd"),
            clock=dut.clk,
            reset=dut.rst_n,
            reset_active_level=False
        )
        
        self.host_to_device_source = AxiStreamSource(
            bus=AxiStreamBus.from_prefix(dut, "s_aixs_cmd"),
            clock=dut.clk,
            reset=dut.rst_n,
            reset_active_level=False
        )
        self.host_to_device_sink.log.setLevel(logging.WARNING)
        self.device_to_host_sink.log.setLevel(logging.WARNING)
        self.device_to_host_source.log.setLevel(logging.WARNING)
        self.host_to_device_source.log.setLevel(logging.WARNING)
        
        # 设备模型
        self.device_model = SATADeviceModel()
        
        # 命令队列
        self.command_queue = Queue()
        self.write_dma_queue = Queue()
        self.read_dma_queue = Queue()
        self.cpl_queue = Queue()
        self.error_queue = Queue()

        self.err_event_queue= Queue()

        self.write_file = "dma_write_frame.txt"
        self.read_file = "dma_read_frame.txt"
        self.err_file  = "dma_err_frame.txt"
    def _random_backpressure(self, n: float,seed: int) -> Generator[bool, None, None]:
        """生成随机反压信号（30%概率触发）"""
        random.seed(seed)  # 设置种子值
        while True:
            yield random.random() < n  # 30%概率拉低tready
    async def reset(self):
        self.dut.rst_n.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst_n.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst_n.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut._log.info("------------------ reset sata host ------------------")
    async def init(self,write_file:str="dma_write_frame.txt",read_file:str="dma_read_frame.txt",err_file:str=""):
        self.write_file = write_file
        self.read_file = read_file
        if os.path.exists(self.write_file):
            os.remove(self.write_file)

        if os.path.exists(self.read_file):
            os.remove(self.read_file)

        if os.path.exists(self.err_file):
            os.remove(self.err_file)

        # 初始化信号
        self.dut.m_aixs_link_tready.value = 1
        self.dut.s_aixs_link_tvalid.value = 0
        self.dut.m_aixs_cmd_tready.value = 1
        self.dut.s_aixs_cmd_tvalid.value = 0
        self.dut.cmd_tdata.value = 0
        self.dut.ctrl.value = 0

        for _ in range(10):
            await RisingEdge(self.dut.clk)
        self.dut._log.info("------------------ initial signal ------------------")

    async def open(self):
        self.dut.ctrl.value = 1
        await RisingEdge(self.dut.clk)
        self.dut._log.info("------------------ open sata host ------------------")
    async def h2d_apply_backpressure(self ,n: float,seed :int):
        try:
            """反压控制协程"""
            self.host_to_device_sink.set_pause_generator(self._random_backpressure(n, seed))
        except Exception as e:
            self.dut._log.error(f"backpresse failed: {e}")
            raise
    async def d2h_apply_backpressure(self ,n: float,seed :int):
        try:
            """反压控制协程"""
            self.device_to_host_sink.set_pause_generator(self._random_backpressure(n, seed))
        except Exception as e:
            self.dut._log.error(f"backpresse failed: {e}")
            raise
    async def h2d_apply_valid_pause(self ,n: float,seed :int):
        try:
            """反压控制协程"""
            self.host_to_device_source.set_pause_generator(self._random_backpressure(n, seed))
        except Exception as e:
            self.dut._log.error(f"backpresse failed: {e}")
            raise
    async def d2h_apply_valid_pause(self ,n: float,seed :int):
        try:
            """反压控制协程"""
            self.device_to_host_source.set_pause_generator(self._random_backpressure(n, seed))
        except Exception as e:
            self.dut._log.error(f"backpresse failed: {e}")
            raise
    async def monitor_host_to_device(self):
        recv_dat_f = 0
        recv_cmd_f = 0
        crc32_func = mkPredefinedCrcFun('crc-32')
        sop_cnt = 0
        eop_cnt = 0
        while True:
            try:
                fis_data = await self.receive_fis_from_host()
                sop = (fis_data.tuser>>1) & 0x01
                eop = (fis_data.tuser>>0) & 0x01

                if sop:
                    fis_type = fis_data.tdata[3]
                    sop_cnt += 1
                    if fis_type == FISType.REG_H2D:
                        fis_cmd = bytearray()
                        recv_cmd_f = 1

                    elif fis_type == FISType.DATA:
                        frame_buffer = bytearray()
                        recv_dat_f = 1

                if recv_dat_f:
                    frame_buffer.extend(fis_data.tdata)
                elif recv_cmd_f:
                    fis_cmd.extend(fis_data.tdata)

                if eop:
                    eop_cnt += 1

                    if fis_type == FISType.REG_H2D:
                        self.dut._log.info(f"D: Received REG_H2D from host ===> SOP:{hex(sop_cnt)},EOP:{hex(eop_cnt)},LEN:{len(fis_cmd)} B,TYPE:{hex(fis_type)},COUNT:{eop_cnt}")
                    elif fis_type == FISType.DATA:
                        self.dut._log.info(f"D: Received DATA from host ===> SOP:{hex(sop_cnt)},EOP:{hex(eop_cnt)},LEN:{len(frame_buffer)} B,TYPE:{hex(fis_type)},COUNT:{eop_cnt}")
                    else:
                        await self.error_queue.put(f"D: Received UNKNOW from host ===> SOP:{hex(sop_cnt)},EOP:{hex(eop_cnt)},TYPE:{hex(fis_type)},COUNT:{eop_cnt}")
                    
                    if sop_cnt != eop_cnt:
                        await self.error_queue.put(f"write dma sop/eop err,the sop is {sop_cnt},the eop is {eop_cnt}")
                        await self.err_event_queue.put(1)

                    if recv_dat_f:
                        recv_dat_f = 0
                        if len(frame_buffer[4::]) % 512 == 0:
                            self.device_model.write_count -= (len(frame_buffer[4::])/512)
                        else:
                            self.device_model.write_count = -1

                        dma_crc = crc32_func(frame_buffer[4::])
                        fis_crc = await self.write_dma_queue.get()

                        if self.device_model.write_count < 0:
                            await self.error_queue.put(f"write dma count err,the fame is {frame_buffer[4::].hex()},the count is {self.device_model.write_count},packet count is{eop_cnt}")
                        elif self.device_model.write_count == 0:
                            await self.cpl_queue.put(0)
                        else:
                            await self.command_queue.put(bytearray((0xff).to_bytes(1,"big")))

                        if(dma_crc!=fis_crc):
                            await self.error_queue.put(f"write dma crc err,receicve crc is {hex(dma_crc)},the calc crc is {hex(fis_crc)},the recieve data is {frame_buffer[4::].hex()}")
                        else:
                            self.dut._log.info(f"====== D: WRITE DMA COMPARE PASS!!! ======")
                        
                        await self.err_event_queue.put(1)

                    if recv_cmd_f:
                        recv_cmd_f = 0
                        await self.command_queue.put(fis_cmd)

            except Exception as e:
                self.dut._log.error(f"Error monitor FIS data: {e}")
                raise 

    async def monitor_device_to_host(self):
        crc32_func = mkPredefinedCrcFun('crc-32')
        sop_cnt = 0
        eop_cnt = 0
        lens = 0
        recv_dat_f = 0
        while True:
            try:
                fis_data = await self.receive_fis_from_device()
                sop = (fis_data.tuser>>1) & 0x01
                eop = (fis_data.tuser>>0) & 0x01

                if sop:
                    sop_cnt += 1
                    recv_dat_f = 1
                    frame_buffer = bytearray()

                if recv_dat_f:
                    frame_buffer.extend(fis_data.tdata)

                if eop:
                    lens = len(frame_buffer)
                    eop_cnt += 1
                    self.dut._log.info(f"H: Received DATA from device ===> SOP:{hex(sop_cnt)},EOP:{hex(eop_cnt)},LEN:{lens} B,COUNT:{eop_cnt}")

                    if sop_cnt != eop_cnt:
                        await self.error_queue.put(f"read dma sop/eop err,the sop is {sop_cnt},the eop is {eop_cnt}")
                        await self.err_event_queue.put(1)

                    if recv_dat_f:
                        recv_dat_f = 0
                        await RisingEdge(self.dut.clk)
                        await ReadOnly()
                        self.device_model.read_count -= self.dut.read_count.value

                        dma_crc = crc32_func(frame_buffer)
                        fis_crc = await self.read_dma_queue.get()

                        if self.device_model.read_count != 0:
                            await self.error_queue.put(f"read dma count err,the fame is {frame_buffer.hex()},the count is {self.device_model.read_count},the packet count is {hex(self.dut.read_count.value)}")
                        elif(dma_crc!=fis_crc):
                            await self.error_queue.put(f"read dma crc err,receicve crc is {hex(dma_crc)},the calc crc is {hex(fis_crc)},the recieve data is {frame_buffer.hex()}")
                        else:
                            await self.cpl_queue.put(1)
                            self.dut._log.info(f"====== H: READ DMA COMPARE PASS !!! ======")

                    await self.err_event_queue.put(1)

            except Exception as e:
                self.dut._log.error(f"Error monitor FIS data: {e}")
                raise 

    async def gen_rw_req(self,n:float=0.5):
        while True:
            rw_sel = (random.random() >= n)
            if rw_sel == True:
                await self.dma_read_test()
            else:
                await self.dma_write_test()

    async def dma_write_test(self):
        await ClockCycles(self.dut.clk,100)
        crc32_func = mkPredefinedCrcFun('crc-32')
        try:
            req_lens = random.getrandbits(23) & 0xffff
            addr = random.getrandbits(48) & ~0b11 & 0xffffffffffff
            self.dut.cmd_tdata.value = (1 << 72) | (0 << 71) | (req_lens << 48) | (addr << 0)
            
            lens = (2**23) if (req_lens==0) else req_lens
            while True:
                await RisingEdge(self.dut.clk)
                await ReadOnly()
                if self.dut.cmd_ack.value:   # ack 拉高了
                    break
            await RisingEdge(self.dut.clk)
            self.dut.cmd_tdata.value = 0

            frame = bytearray(random.getrandbits(8) for _ in range(lens))
            prezero = bytearray([0] * (addr % 512))
            befzero = bytearray([0] * (512 - (512 if(((addr +  (1 if lens == 0 else lens)) % 512) == 0) else ((addr +  (1 if lens == 0 else lens)) % 512))) )
            vframe = prezero + frame + befzero
            for i in range(0,len(vframe),8192):
                with open(self.write_file,"a+") as f:
                    f.write(vframe[i:i+8192].hex() + "\n")
                crc_value = crc32_func(vframe[i:i+8192])
                # self.dut._log.error(f"CRC is {hex(crc_value)} the data is {(vframe[i:i+8192]).hex()}")
                await self.write_dma_queue.put(crc_value)
            await self.send_dat_to_device(frame)
        except Exception as e:
            self.dut._log.error(f"Error dma write test: {e}")
            raise

    async def dma_read_test(self):
        await ClockCycles(self.dut.clk,100)
        crc32_func = mkPredefinedCrcFun('crc-32')
        try:
            req_lens = random.getrandbits(23) & 0xffff
            addr = random.getrandbits(48) & ~0b11 & 0xffffffffffff
            self.dut.cmd_tdata.value = (1 << 72) | (1 << 71) | (req_lens << 48) | (addr << 0)
            
            lens = (2**23) if (req_lens==0) else req_lens
            while True:
                await RisingEdge(self.dut.clk)
                await ReadOnly()
                if self.dut.cmd_ack.value:   # ack 拉高了
                    break
            await RisingEdge(self.dut.clk)
            self.dut.cmd_tdata.value = 0

            start_byte = addr % 512
            end_addr   = (addr +  (1 if lens == 0 else lens) - 0x1)
            end_addr += 3 - (end_addr % 4)
            
            end_byte   = end_addr - addr + 1 + start_byte
            frame_len = lens + (addr % 512) + (512 - (512 if(((addr +  (1 if lens == 0 else lens)) % 512) == 0) else ((addr +  (1 if lens == 0 else lens)) % 512)))
            frame = bytearray(random.getrandbits(8) for _ in range(frame_len))

            await self.device_model.read_req_queue.get()
            for i in range(0,len(frame),8192):
                await self.send_fis_to_host(((0x46000000).to_bytes(4, 'little') + frame[i:i+8192] + (0xffffffff).to_bytes(4, 'little')))
            # self.dut._log.error(f"the start byte is {hex(start_byte)},the end byte is {hex(end_byte)},addr: {hex(addr)},len: {hex(lens)},end_addr: {hex(end_addr)},send data is {frame[start_byte:end_byte].hex()}")
            with open(self.read_file,"a+") as f:
                f.write(frame[start_byte:end_byte].hex() + "\n")
            crc_value = crc32_func(frame[start_byte:end_byte])
            await self.read_dma_queue.put(crc_value)
        except Exception as e:
            self.dut._log.error(f"Error dma read test: {e}")
            raise

    async def process_commands(self):
        """处理从主机接收的命令并响应"""
        while True:
            try:
                # wait commond
                responses = []
                fis_cmd = await self.command_queue.get()
                
                self.dut._log.info(f"D: receive CMD {fis_cmd[0:4].hex()}")
                # handle command by device model
                responses = await self.device_model.process_command(fis_cmd)
                if(responses == [] and fis_cmd[1] != 0x25):
                    self.dut._log.info(f"no return fis command: {fis_cmd.hex()}")
                else:
                    # send response
                    for response in responses:
                        self.dut._log.info(f"D: SEND RESPONSE {response[0:4].hex()}")
                        await self.send_fis_to_host(response)
                        self.dut._log.info(f"D: SEND RESPONSE COMPLETE")
            except Exception as e:
                self.dut._log.error(f"Error process commands: {e}")
                raise

    async def process_datcpl(self):
        while True:
            try:
                responses = []
                rw_cpl = await self.cpl_queue.get()
                responses = self.device_model.process_cpl(rw_cpl)
                if(responses == []):
                    self.dut._log.error(f"recv cpl err: {responses}")
                else:
                    for response in responses:
                        await self.send_fis_to_host(response)

            except Exception as e:
                self.dut._log.error(f"Error process cpl: {e}")
                raise

    async def receive_fis_from_host(self, timeout_us=1000000):
        try:
            frame = await with_timeout(
                self.host_to_device_sink.recv(),
                timeout_time=timeout_us,
                timeout_unit='us'
            )
            return frame
        except SimTimeoutError:
            raise TimeoutError(f"FIS reception timeout after {timeout_us} us")
        except Exception as e:
            self.dut._log.error(f"Error receiving FIS data: {e}")
            raise

    async def receive_fis_from_device(self, timeout_us=1000000):
        try:
            frame = await with_timeout(
                self.device_to_host_sink.recv(),
                timeout_time=timeout_us,
                timeout_unit='us'
            )
            return frame
        except SimTimeoutError:
            raise TimeoutError(f"FIS reception timeout after {timeout_us} us")
        except Exception as e:
            self.dut._log.error(f"Error receiving FIS data: {e}")
            raise

    async def send_fis_to_host(self, payload: bytearray,width = 4):
        try:
            n = len(payload)
            tuser = [0] * n
            if n <= width:
                tuser = [3]*n
            elif (n % width) == 1:
                tuser[:width ] = [2] * width
                tuser[n-1] = 1
            else:
                tuser = [0] * n
                tuser[:width ] = [2] * width
                endn = width if (n % width == 0) else (n % width)
                tuser[-endn::] = [1] * endn
            frame = AxiStreamFrame(
                tdata=payload,    # tdata
                tuser=tuser       
            )

            # 发送
            await self.device_to_host_source.send(frame)
        except Exception as e:
            self.dut._log.error(f"Error send fis to host: {e},the payload is {payload}")
            raise

    async def send_dat_to_device(self, payload: bytearray,width = 4):
        try:
            n = len(payload)
            tuser = [0] * n
            if n <= width:
                tuser = [3]*n
            elif (n % width) == 1:
                tuser[:width ] = [2] * width
                tuser[n-1] = 1
            else:
                tuser = [0] * n
                tuser[:width ] = [2] * width
                endn = width if (n % width == 0) else (n % width)
                tuser[-endn::] = [1] * endn
            frame = AxiStreamFrame(
                tdata=payload,    # tdata
                tuser=tuser       
            )

            #send
            await self.host_to_device_source.send(frame)
        except Exception as e:
            self.dut._log.error(f"Error send data to device: {e},the len is {n},the tuser is {tuser}")
            raise
# @cocotb.test()
async def sata_transport_test(dut, dev_press:float=0.8,host_press:float=0.8,dev_valid:float=0.1,host_valid:float=0.1):
    try:
        # init clock & reset
        clock = Clock(dut.clk, period=10, units="ns")
        cocotb.start_soon(clock.start()) 

        # dut.rst_n.value = 0
        # await ClockCycles(dut.clk,100)

        # create TestBench
        tb = SATATestbench(dut)
        await tb.reset()

        await tb.init(f"dma_write_frame_{dev_press}_{host_press}_{dev_valid}_{host_valid}.txt",f"dma_read_frame_{dev_press}_{host_press}_{dev_valid}_{host_valid}.txt")

        await tb.open()

        # start task
        monitor_h2d_task = cocotb.start_soon(tb.monitor_host_to_device())
        monitor_d2h_task = cocotb.start_soon(tb.monitor_device_to_host())
        responder_task = cocotb.start_soon(tb.process_commands())
        process_datcpl_task = cocotb.start_soon(tb.process_datcpl())
        gen_rw_req_task = cocotb.start_soon(tb.gen_rw_req(0.5))
        write_dma_backpresse = cocotb.start_soon(tb.h2d_apply_backpressure(dev_press, 0))
        read_dma_backpresse = cocotb.start_soon(tb.d2h_apply_backpressure(host_press,1))
        h2d_apply_valid_pause_task = cocotb.start_soon(tb.h2d_apply_valid_pause(host_valid,2))
        d2h_apply_valid_pause_task = cocotb.start_soon(tb.d2h_apply_valid_pause(dev_valid,3))
        dut._log.info("--------------------------------The SATA device has been initialized and is waiting for host commands--------------------------------")
        
        for _ in range(100):
            err = 0
            await tb.err_event_queue.get()
            if not tb.error_queue.empty():
                err = await tb.error_queue.get()
            await RisingEdge(dut.clk)
            assert err == 0,f"TEST FAIL:{err}"
            
        await RisingEdge(dut.clk)

        # cancel task
        monitor_h2d_task.kill()
        monitor_d2h_task.kill()
        responder_task.kill()
        process_datcpl_task.kill()
        gen_rw_req_task.kill()
        write_dma_backpresse.kill()
        read_dma_backpresse.kill()
        h2d_apply_valid_pause_task.kill()
        d2h_apply_valid_pause_task.kill()
        
        dut._log.info("--------------------------------SATA device test completed--------------------------------")
    except Exception as e:
        traceback.print_exc()
        raise

factory = TestFactory(sata_transport_test)
factory.add_option("dev_press",[0.8,0])
factory.add_option("host_press",[0.8,0])
factory.add_option("dev_valid",[0,0.8])
factory.add_option("host_valid",[0,0.8])
factory.generate_tests()
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

    adcore_test_run(request,ctb="cocotb_top_transport_dma",tc="tb_top_transport_dma",wave=waves,sim=simulator,parameters=parameters)
