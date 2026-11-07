Wally supports the following FPGA boards.

| Board | `make` target | Memory for Linux | Device tree | SD card | UART |
| ----- | ------------- | ---------------- | ----------- | ------- | ---- |
| Digilent Arty A7-100T | `ArtyA7` (default) | 256 MB DDR3 | `wally-artya7.dtb` | Digilent microSD PMOD | onboard USB-UART |
| Digilent Genesys 2 | `genesys2` | 1 GB DDR3 | `wally-genesys2.dtb` | onboard microSD | onboard USB-UART |
| Digilent Nexys A7-100T | `nexysa7` | 128 MB DDR2 | `wally-nexysa7.dtb` | onboard microSD | onboard USB-UART |
| QMTech Kintex-7 | `qmtechk7` | 256 MB DDR3 | `wally-qmtechk7.dtb` | Digilent microSD PMOD on J13 | USB-UART adapter on JP5 (pin 7 TX, pin 8 RX) |
| Xilinx VCU108 | `vcu108` | 2 GB DDR4 | `wally-vcu108.dtb` | Digilent microSD PMOD | onboard USB-UART |
| Xilinx VCU118 (not recommended) | `vcu118` | 256 MB DDR4 | `wally-vcu118.dtb` | custom PMOD board (see below) | USB-UART adapter on the PMOD |

Each board's pins are in `constraints/constraints-<board>.xdc`, and its configuration is the `fpga<board>` derivative configuration in `config/derivlist.txt`.

# Quick Start

## Vivado board files

The Digilent boards (Arty A7, Genesys 2, Nexys A7) need Digilent's Vivado board files, which are in the `addins/vivado-boards` submodule. Tell Vivado where they are by adding this line to `~/.Xilinx/Vivado/Vivado_init.tcl` (create the file if it doesn't exist):

```tcl
set_param board.repoPaths [list $::env(WALLY)/addins/vivado-boards/new/board_files]
```

See Section 3 of Digilent's [Installing Vivado, Vitis, and Digilent Board Files](https://digilent.com/reference/programmable-logic/guides/installing-vivado-and-vitis#install_digilent_s_board_files) guide for other ways to install them.  The Xilinx VCU108 and VCU118 board files come with Vivado, and the QMTech board needs none.

## Build FPGA

```bash
cd $WALLY/fpga/generator
make <make target>
```

Example:
```bash
make vcu108
```

## Make flash card image
`ls /dev/sd*` or `ls /dev/mmc*` to see which flash card devices you have.
Insert the flash card into the reader and `ls /dev/sd*` or `/dev/mmc*` again.  The new device is the one you want to use.  Make sure you select the root device (i.e. `/dev/sdb`) not the partition (i.e. `/dev/sdb1`).

```bash
cd $WALLY/linux/sdcard
```

This following script requires root.  `-d` takes the path to the board's device tree from the table above; building Linux (see [the Linux README](../linux/README.md)) puts the device trees in `<path to buildroot>/output/images`.

```bash
./flash-sd.sh -b <path to buildroot> -d <path to compiled device tree file> <flash card device>
```

Example with vcu108, buildroot installed to `/opt/riscv/buildroot`, and the flash card is device `/dev/sdc`

```bash
./flash-sd.sh -b /opt/riscv/buildroot -d /opt/riscv/buildroot/output/images/wally-vcu108.dtb /dev/sdc
```

Wait until the script completes then remove the card.

## FPGA setup

For the Arty A7 insert the PMOD daughter board into the right most slot and insert the sd card.

For the Genesys 2 and Nexys A7 insert the sd card into the board's microSD slot.

For the QMTech Kintex-7 connect the microSD PMOD to J13 and a 3.3 V USB-UART adapter to JP5 (pin 7 is Wally's TX, pin 8 its RX).

For the VCU108 and VCU118 boards insert the PMOD daughter board into the only PMOD slot on the right side of the boards.

Power on the boards. For the Digilent boards just plug in the USB connector. For the VCU boards make sure the power supply is connected and the two usb cables are connected. Flip on the switch.
The VCU118's on board UART converter does not work. Use a SparkFun FTDI USB to UART adapter and plug into the main PMOD on the right side of the board.  Also the level shifters on the
VCU118 do not work correctly with the Digilent sd PMOD board.  We have a custom board which works instead.

```bash
cd $WALLY/fpga/generator
vivado &
```

Open the design in the current directory `WallyFPGA.xpr`.

Then click "Open Target" under "PROGRAM AND DEBUG".  Then Program the device.

## Connect to UART

In another terminal `ls /dev/ttyUSB*`. One of these devices will be the UART connected to Wally. You may have to experiment by the running the following command multiple times.

```bash
screen /dev/ttyUSB1 115200
```

Swap out the `USB1` for `USB0`, `USB2`, etc. as needed.
