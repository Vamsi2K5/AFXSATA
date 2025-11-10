# AFXSATA — FPGA-based SATA-DMA Host Controller

[![zh](https://img.shields.io/badge/lang-中文-red.svg)](./README.md)
[![en](https://img.shields.io/badge/lang-English-blue.svg)](./README_en.md)

## Introduction

**AFXSATA** is an **FPGA-based SATA-DMA Host Controller** that supports **SATA 3.0 (6 Gbps)** and up to **256 TB** of storage capacity. It enables **up to 8 MB of continuous burst DMA read/write operations**.

The project implements the **SATA PHY layer** using **Xilinx GTX (7-Series)** and **UltraScale GTH transceivers**, **without relying on vendor SATA IP cores**. It provides a fully functional, simplified SATA-DMA protocol stack from the physical layer up to the command layer.

The design adopts a **minimalist three-interface architecture**, efficiently bridging the user command interface and **AXI-Stream** data path, making it easy for system-level integration and verification.
Users can either build a complete SATA protocol stack based on the provided PHY and command layers or directly use the command layer to perform **DMA read/write operations** to SATA drives.

Additional materials and detailed **SATA protocol analyses** are available in the WeChat public account **“AdriftCoreFPGA芯研社”**, which helps readers understand SATA internals more deeply.

**Verified FPGA platforms and boards:**

* **STLV-Kintex-7 XC7K325T**
* **Kintex UltraScale XCKU040**

---

## Description

### Modules

#### `sata_wrapper`

Top-level wrapper integrating the PHY, link, transport, and command layers, providing a complete SATA controller interface for user applications.

#### `sata_gt_wrapper`

Transceiver wrapper for different GTX/GTH types, providing a unified interface for clocking, reset, and PHY data path management.

#### `sata_phy_ctrl`

SATA physical layer control module handling link initialization, speed negotiation, out-of-band (OOB) signaling, and data TX/RX control.

#### `sata_link_ctrl`

Link layer controller managing data encoding/decoding, flow control, and link-layer state machines between PHY and transport layers.

#### `sata_link_arbt`

Link layer arbiter for coordinating read/write access between transport and link layers, ensuring proper sequencing and flow regulation.

#### `sata_link_wrmod`

Write module managing the full write path state machine (frame start, data, CRC, frame end, idle) and synchronization with the arbiter and PHY.

#### `sata_link_rdmod`

Read module managing the read path state machine, CRC validation, and buffering data between PHY and transport layers.

#### `sata_link_ingress`

Ingress module handling write data flow from the transport layer into the link layer, including buffering and flow control.

#### `sata_link_egress`

Egress module handling outgoing data flow from the internal logic to the SATA interface, serving as a buffering and flow-control bridge.

#### `sata_link_crc`

CRC module implementing the SATA standard 32-bit polynomial (init = 0x52325032) to ensure data integrity.

#### `sata_link_lfsr`

16-bit LFSR scrambler module using the primitive polynomial
G(X) = X¹⁶ + X¹⁵ + X¹³ + X⁴ + 1, initialized with 0xF0F6 to generate compliant SATA pseudo-random sequences.

#### `sata_link_encode`

Encoding module converting transport data and primitives into physical-layer symbols, performing scrambling and alignment insertion.

#### `sata_link_decode`

Decoding module parsing received SATA primitives and data, identifying symbol types, descrambling, and forwarding decoded data.

#### `sata_transport`

Implements the SATA transport layer — handles command FIS processing, data routing, and interface management between the link layer and user logic.

#### `sata_transport_pio`

Handles PIO setup detection and control signal generation by monitoring inbound FIS packets and identifying PIO setup commands.

#### `sata_transport_packet`

Packet handler managing buffering, packet assembly, and flow control for DMA operations between transport and link layers.

#### `sata_transport_dma`

DMA transport module detecting DMA activation requests and generating control signals for DMA-based transfers.

#### `sata_transport_command`

Command module handling H2D (Host-to-Device) command framing and D2H (Device-to-Host) response parsing.

#### `sata_command_dma_ctrl`

Command and DMA controller managing SATA command execution, data buffering, and user-side DMA interface coordination.

#### `sata_bist` / `sata_bist_lfsr`

Built-In Self-Test (BIST) modules generating test patterns and verifying data integrity and throughput.

---

## Interfaces

### System Clock

| Signal  | Direction | Description                        |
| ------- | --------- | ---------------------------------- |
| clk     | input     | System clock input (100 MHz)       |
| refclkp | input     | Reference clock positive (150 MHz) |
| refclkn | input     | Reference clock negative (150 MHz) |

### GTX / GTH Interface

| Signal | Direction | Description                     |
| ------ | --------- | ------------------------------- |
| gtxrxp | input     | GTX receiver positive input     |
| gtxrxn | input     | GTX receiver negative input     |
| gtxtxp | output    | GTX transmitter positive output |
| gtxtxn | output    | GTX transmitter negative output |

### System Control

| Signal     | Direction | Description                  |
| ---------- | --------- | ---------------------------- |
| soft_reset | input     | Software reset (active high) |

### User Control

| Signal      | Direction    | Description                                                                                                          |
| ----------- | ------------ | -------------------------------------------------------------------------------------------------------------------- |
| usr_clk     | output       | User clock (150 MHz)                                                                                                 |
| usr_rst     | output       | User reset (active low)                                                                                              |
| usr_ctrl    | input [1:0]  | User control: bit0 = command enable, bit1 = command reset (active high)                                              |
| usr_cmd     | input [71:0] | **User command input:** `{RW, len[22:0], addr[47:0]}` — `addr` must be **DW-aligned**, `RW`: `1` = read, `0` = write |
| usr_cmd_req | input        | User command request                                                                                                 |
| usr_cmd_ack | output       | User command acknowledge                                                                                             |

### AXI-Stream Data Interface

| Signal            | Direction     | Description                                                       |
| ----------------- | ------------- | ----------------------------------------------------------------- |
| s_aixs_usr_tdata  | input [31:0]  | Slave AXI-Stream data input                                       |
| s_aixs_usr_tuser  | input [7:0]   | Slave AXI-Stream user signals `{drop, err, keep[3:0], sop, eop}`  |
| s_aixs_usr_tvalid | input         | Slave AXI-Stream valid                                            |
| s_aixs_usr_tready | output        | Slave AXI-Stream ready                                            |
| m_aixs_usr_tdata  | output [31:0] | Master AXI-Stream data output                                     |
| m_aixs_usr_tuser  | output [7:0]  | Master AXI-Stream user signals `{drop, err, keep[3:0], sop, eop}` |
| m_aixs_usr_tvalid | output        | Master AXI-Stream valid                                           |
| m_aixs_usr_tready | input         | Master AXI-Stream ready                                           |

---

## Timing and Behavior

![wavedrom](assets/wavedrom-20251109210403-ubtcfzd.svg)

Due to SATA’s physical requirements, all read/write operations must be **sector-based** (512 bytes).
AFXSATA controller behaves as follows:

* **Block Size:** Data block length **must** be a multiple of 512 bytes.
* **Address Alignment:** It is **strongly recommended** that start addresses are 512B-aligned. Non-aligned operations will be zero-padded, possibly overwriting unintended regions.
* **Zero Length:** A command with `len = 0` indicates the **maximum burst length of 8 MB**.

---

## Source Files

```shell
gt_sata_common.sv
sata_link_ingress.sv
sata_link_arbt.sv
sata_gt_wrapper.sv
sata_transport_packet.sv
sata_transport_pio.sv
sata_link_arbt_dev.sv
sata_wrapper.sv
sata_link_rdmod.sv
sata_link_crc.sv
gt_sata_common_reset.sv
sata_link_decode.sv
sata_bist.sv
sata_reset_gen.sv
sata_transport_dma.sv
afx_fifo_wrapper.sv
afx_skid_buffer_axis.sv
afx_skid_buffer.sv
sata_transport_command.sv
sata_phy_ctrl.sv
sata_link_wrmod.sv
sata_link_encode.sv
sata_link_egress.sv
sata_transport.sv
sata_bist_lfsr.sv
sata_link_lfsr.sv
sata_link_wrmod_dev.sv
sata_link_ctrl_dev.sv
sata_link_ctrl.sv
sata_command_dma_ctrl.sv
```

---

## Testing

### Simulation

Simulation environment requires **cocotb**, **cocotbext-axi**, **Vivado**, **VCS**, and **Verdi**.
Two run methods are supported — via **pytest (cocotb-test)** or **cocotb makefiles**.

```shell
adcore_cocotb_test_run.py
cocotb_top_sata_phy_ctrl.py
cocotb_top.py
cocotb_top_transport_dma.py
cocotb_top_sata_bist.py
tb_top_sata_phy_ctrl.sv     # PHY layer test
tb_top.sv                   # Link layer test
tb_top_transport_dma.sv     # Transport & Command layer test
tb_top_sata_bist.sv         # BIST test
```

![image](assets/image-20251109215513-w3ni8mi.png)
![image](assets/image-20251109220216-zhkd8lh.png)

---

### On-board Validation

A **VIO example design** (`sata_example`) is provided for **functional and performance testing**.

#### Functional Test

* Set `mode = 0`
* Configure `cycle` and the number of read/write per round (e.g., `cycle = 4` → 4 writes + 4 reads)
* Set `num` (packet length in DW, up to 0x20_0000 DW = 8 MB)
* Set starting address `addr`
* Configure `level` (default `0x7fff_ffff`): 50% valid pause for write, 50% backpressure for read; smaller = less pause
* Disable speed mode: `speed_test = 0`
* Enable module: `enable = 1`
* Monitor `wr_cnt_eop` and `rd_cnt_eop` for write/read count
  `err_cnt = 0` → correct transfer; `err_cnt = 1` → data mismatch

#### Performance Test

* Configure `num` (packet length, DW)
* Set `speed_test = 1` for write or `2` for read
* Enable: `enable = 1`
* Observe `timer` (seconds), `wr_cnt_eop`, `rd_cnt_eop` to compute throughput
  Typical write speed: **~500 MB/s**, read speed: **~300 MB/s**

#### Compatibility Notes

Some SATA SSDs may show different physical characteristics or fail to link.
If this occurs, adjust TX equalization or swing settings.
For SSDs that cannot handle 8 MB bursts, reduce `num` to match device capability.

**Verified Drives:**

* Samsung SSD 830 Series (64GB)
* JinyJaier (1TB)

---

## Citation

If you use **AFXSATA** in your work, please cite the repository:

> AdriftXCore. *AFXSATA: FPGA-based SATA-DMA Host Controller*.
> GitHub: [https://github.com/AdriftXCore](https://github.com/AdriftXCore)
> Gitee: [https://gitee.com/adriftxcore](https://gitee.com/adriftxcore)

