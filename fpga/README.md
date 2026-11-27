Wally supports the following boards

1. ArtyA7
2. vcu108
3. vcu118 (Do not recommend.)

# Quick Start

## Build FPGA

```bash
cd generator
make <board name>
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

This following script requires root.

```bash
./flash-sd.sh -b <path to buildroot> -d <path to compiled device tree file> <flash card device>
```

Example with vcu108, buildroot installed to `/opt/riscv/buildroot`, and the flash card is device `/dev/sdc`

```bash
./flash-sd.sh -b /opt/riscv/buildroot -d /opt/riscv/buildroot/output/images/wally-vcu108.dtb /dev/sdc
```

Wait until the the script completes then remove the card.

## FPGA setup

For the Arty A7 insert the PMOD daughter board into the right most slot and insert the sd card.

For the VCU108 and VCU118 boards insert the PMOD daughter board into the only PMOD slot on the right side of the boards.

Power on the boards. For Arty A7 just plug in the USB connector. For the VCU boards make sure the power supply is connected and the two usb cables are connected. Flip on the switch.
The VCU118's on board UART converter does not work. Use a spark fun FTDI usb to UART adapter and plug into the mail PMOD on the right side of the board.  Also the level sifters on the
VCU118 do not work correctly with the digilent sd PMOD board.  We have a custom board which works instead.

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

Swap out the `USB1` for `USB0` or `USB1` as needed.
