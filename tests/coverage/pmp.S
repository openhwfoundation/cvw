///////////////////////////////////////////
// /content/sample_data/PMPConfigregs.S
// Kevin Box, kbox@hmc.edu
// Created 2023-04-09 23:20:54.863039
///////////////////////////////////////////




#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

// Checks (rv64gc: 16 entries, G = 4, so NA4 is not selectable and NAPOT/TOR addresses are rounded
// to 64-byte grains): the pmpcfg read after the first configuration (failure index 1), pmpcfg0
// and pmpcfg2 after each configuration, showing that locked entries ignore every later write
// while unlocked ones take it (10-41), and every pmpaddr at the end, showing that locked entries
// kept their address (50-65).  At the end every entry is locked, so the regions bind M-mode too:
// entry 1 is TOR [0x80000100, 0x800001C0) and entries 3-15 are NAPOT [0x80000400, 0x80000500),
// all RW without X.  Stores and loads in both regions work (70-71), fetches inside them raise an
// instruction access fault with mtval = the address, and fetches just outside them run (trap log,
// indices 0x100-0x1FF).

// CHECK_CSR csr, expected, index: fail with index unless the CSR reads expected
.macro CHECK_CSR csr, expected, index
    csrr a1, \csr
    li a2, \expected
    SC_CHECK_EQ a1, a2, \index
.endm

// FETCH adr: call adr; log_trap returns to ra if the fetch faults
.macro FETCH adr
    li a1, \adr
    jalr ra, 0(a1)
.endm

main:
    la t0, log_trap
    csrw mtvec, t0


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN Configuration and Testing Starting at Register: 0
//
// Configuration

  # | Reg   | pmpaddr     | pmpcfg    | L | A    | X | W | R | Comments
  # |0      | 0x20000040  | 0x83      | 1 | 00   | 0 | 1 | 1 | 0
  # |1      | 0x2000007f  | 0x8b      | 1 | 01   | 0 | 1 | 1 | 1
  # |2      | 0x200000be  | 0x93      | 1 | 10   | 0 | 1 | 1 | 2
  # |3      | 0x2000011e  | 0x9b      | 1 | 11   | 0 | 1 | 1 | 3
  # |4      | 0x2000013f  | 0x01      | 0 | 00   | 0 | 0 | 1 | 4
  # |5      | 0x2000017f  | 0x09      | 0 | 01   | 0 | 0 | 1 | 5
  # |6      | 0x200001be  | 0x11      | 0 | 10   | 0 | 0 | 1 | 6
  # |7      | 0x2000021e  | 0x19      | 0 | 11   | 0 | 0 | 1 | 7
  # |8      | 0x2000023f  | 0x04      | 0 | 00   | 1 | 0 | 0 | 8
  # |9      | 0x2000027f  | 0x0c      | 0 | 01   | 1 | 0 | 0 | 9
  # |10     | 0x200002be  | 0x14      | 0 | 10   | 1 | 0 | 0 | 10
  # |11     | 0x2000031e  | 0x1c      | 0 | 11   | 1 | 0 | 0 | 11
  # |12     | 0x2000033f  | 0x00      | 0 | 00   | 0 | 0 | 0 | 12
  # |13     | 0x2000037f  | 0x08      | 0 | 01   | 0 | 0 | 0 | 13
  # |14     | 0x200003be  | 0x10      | 0 | 10   | 0 | 0 | 0 | 14
  # |15     | 0x2000041e  | 0x18      | 0 | 11   | 0 | 0 | 0 | 15
 # configure the pmp address of register 0 in mode 0
 # changed from 2000003F to 20000040 5/22/25 david_harris@hmc.edu
 # to prevent access fault to trap handler when grain size is large
 # may result in lower coverage.
li t5, 0x20000040
csrw pmpaddr0, t5

 # configure the pmp address of register 1 in mode 1
li t5, 536871039
csrw pmpaddr1, t5

 # configure the pmp address of register 2 in mode 2
li t5, 536871102
csrw pmpaddr2, t5

 # configure the pmp address of register 3 in mode 3
li t5, 536871198
csrw pmpaddr3, t5

 # configure the pmp address of register 4 in mode 0
li t5, 536871231
csrw pmpaddr4, t5

 # configure the pmp address of register 5 in mode 1
li t5, 536871295
csrw pmpaddr5, t5

 # configure the pmp address of register 6 in mode 2
li t5, 536871358
csrw pmpaddr6, t5

 # configure the pmp address of register 7 in mode 3
li t5, 536871454
csrw pmpaddr7, t5

 # configure the pmp address of register 8 in mode 0
li t5, 536871487
csrw pmpaddr8, t5

 # configure the pmp address of register 9 in mode 1
li t5, 536871551
csrw pmpaddr9, t5

 # configure the pmp address of register 10 in mode 2
li t5, 536871614
csrw pmpaddr10, t5

 # configure the pmp address of register 11 in mode 3
li t5, 536871710
csrw pmpaddr11, t5

 # configure the pmp address of register 12 in mode 0
li t5, 536871743
csrw pmpaddr12, t5

 # configure the pmp address of register 13 in mode 1
li t5, 536871807
csrw pmpaddr13, t5

 # configure the pmp address of register 14 in mode 2
li t5, 536871870
csrw pmpaddr14, t5

 # configure the pmp address of register 15 in mode 3
li t5, 536871966
csrw pmpaddr15, t5


  # write pmpcfg0, output 0x191109019b938b83
li t4, 1806234828062034819
csrw pmpcfg0, t4
csrr t5, pmpcfg0
li a2, 0x190109019b838b83   # NA4 (0x93, 0x11) is not selectable: the A field stays OFF
SC_CHECK_EQ t5, a2, 1

  # write pmpcfg2, output 0x181008001c140c04
li t4, 1733894653101739012
csrw pmpcfg2, t4


// Testing
CHECK_CSR pmpcfg0, 0x190109019b838b83, 10
CHECK_CSR pmpcfg2, 0x180008001c040c04, 11

// END Configuration and Testing Starting at Register: 0
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN Configuration and Testing Starting at Register: 1
//
// Configuration

  # | Reg   | pmpaddr     | pmpcfg    | L | A    | X | W | R | Comments
  # |1      | 0x2000003f  | 0x83      | 1 | 00   | 0 | 1 | 1 | 0
  # |2      | 0x2000007f  | 0x8b      | 1 | 01   | 0 | 1 | 1 | 1
  # |3      | 0x200000be  | 0x93      | 1 | 10   | 0 | 1 | 1 | 2
  # |4      | 0x2000011e  | 0x9b      | 1 | 11   | 0 | 1 | 1 | 3
  # |5      | 0x2000013f  | 0x01      | 0 | 00   | 0 | 0 | 1 | 4
  # |6      | 0x2000017f  | 0x09      | 0 | 01   | 0 | 0 | 1 | 5
  # |7      | 0x200001be  | 0x11      | 0 | 10   | 0 | 0 | 1 | 6
  # |8      | 0x2000021e  | 0x19      | 0 | 11   | 0 | 0 | 1 | 7
  # |9      | 0x2000023f  | 0x04      | 0 | 00   | 1 | 0 | 0 | 8
  # |10     | 0x2000027f  | 0x0c      | 0 | 01   | 1 | 0 | 0 | 9
  # |11     | 0x200002be  | 0x14      | 0 | 10   | 1 | 0 | 0 | 10
  # |12     | 0x2000031e  | 0x1c      | 0 | 11   | 1 | 0 | 0 | 11
  # |13     | 0x2000033f  | 0x00      | 0 | 00   | 0 | 0 | 0 | 12
  # |14     | 0x2000037f  | 0x08      | 0 | 01   | 0 | 0 | 0 | 13
  # |15     | 0x200003be  | 0x10      | 0 | 10   | 0 | 0 | 0 | 14
  # |0      | 0x2000041e  | 0x18      | 0 | 11   | 0 | 0 | 0 | 15
 # configure the pmp address of register 1 in mode 0
li t5, 536870975
csrw pmpaddr1, t5

 # configure the pmp address of register 2 in mode 1
li t5, 536871039
csrw pmpaddr2, t5

 # configure the pmp address of register 3 in mode 2
li t5, 536871102
csrw pmpaddr3, t5

 # configure the pmp address of register 4 in mode 3
li t5, 536871198
csrw pmpaddr4, t5

 # configure the pmp address of register 5 in mode 0
li t5, 536871231
csrw pmpaddr5, t5

 # configure the pmp address of register 6 in mode 1
li t5, 536871295
csrw pmpaddr6, t5

 # configure the pmp address of register 7 in mode 2
li t5, 536871358
csrw pmpaddr7, t5

 # configure the pmp address of register 8 in mode 3
li t5, 536871454
csrw pmpaddr8, t5

 # configure the pmp address of register 9 in mode 0
li t5, 536871487
csrw pmpaddr9, t5

 # configure the pmp address of register 10 in mode 1
li t5, 536871551
csrw pmpaddr10, t5

 # configure the pmp address of register 11 in mode 2
li t5, 536871614
csrw pmpaddr11, t5

 # configure the pmp address of register 12 in mode 3
li t5, 536871710
csrw pmpaddr12, t5

 # configure the pmp address of register 13 in mode 0
li t5, 536871743
csrw pmpaddr13, t5

 # configure the pmp address of register 14 in mode 1
li t5, 536871807
csrw pmpaddr14, t5

 # configure the pmp address of register 15 in mode 2
li t5, 536871870
csrw pmpaddr15, t5

 # configure the pmp address of register 0 in mode 3
li t5, 536871966
csrw pmpaddr0, t5


  # write pmpcfg0, output 0x1109019b938b8318
li t4, 1227514141142123288
csrw pmpcfg0, t4

  # write pmpcfg2, output 0x1008001c140c0419
li t4, 1155173425015948313
csrw pmpcfg2, t4


// Testing
CHECK_CSR pmpcfg0, 0x1909019b9b838b83, 12
CHECK_CSR pmpcfg2, 0x1808001c1c0c0419, 13

// END Configuration and Testing Starting at Register: 1
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN Configuration and Testing Starting at Register: 2
//
// Configuration

  # | Reg   | pmpaddr     | pmpcfg    | L | A    | X | W | R | Comments
  # |2      | 0x2000003f  | 0x83      | 1 | 00   | 0 | 1 | 1 | 0
  # |3      | 0x2000007f  | 0x8b      | 1 | 01   | 0 | 1 | 1 | 1
  # |4      | 0x200000be  | 0x93      | 1 | 10   | 0 | 1 | 1 | 2
  # |5      | 0x2000011e  | 0x9b      | 1 | 11   | 0 | 1 | 1 | 3
  # |6      | 0x2000013f  | 0x01      | 0 | 00   | 0 | 0 | 1 | 4
  # |7      | 0x2000017f  | 0x09      | 0 | 01   | 0 | 0 | 1 | 5
  # |8      | 0x200001be  | 0x11      | 0 | 10   | 0 | 0 | 1 | 6
  # |9      | 0x2000021e  | 0x19      | 0 | 11   | 0 | 0 | 1 | 7
  # |10     | 0x2000023f  | 0x04      | 0 | 00   | 1 | 0 | 0 | 8
  # |11     | 0x2000027f  | 0x0c      | 0 | 01   | 1 | 0 | 0 | 9
  # |12     | 0x200002be  | 0x14      | 0 | 10   | 1 | 0 | 0 | 10
  # |13     | 0x2000031e  | 0x1c      | 0 | 11   | 1 | 0 | 0 | 11
  # |14     | 0x2000033f  | 0x00      | 0 | 00   | 0 | 0 | 0 | 12
  # |15     | 0x2000037f  | 0x08      | 0 | 01   | 0 | 0 | 0 | 13
  # |0      | 0x200003be  | 0x10      | 0 | 10   | 0 | 0 | 0 | 14
  # |1      | 0x2000041e  | 0x18      | 0 | 11   | 0 | 0 | 0 | 15
 # configure the pmp address of register 2 in mode 0
li t5, 536870975
csrw pmpaddr2, t5

 # configure the pmp address of register 3 in mode 1
li t5, 536871039
csrw pmpaddr3, t5

 # configure the pmp address of register 4 in mode 2
li t5, 536871102
csrw pmpaddr4, t5

 # configure the pmp address of register 5 in mode 3
li t5, 536871198
csrw pmpaddr5, t5

 # configure the pmp address of register 6 in mode 0
li t5, 536871231
csrw pmpaddr6, t5

 # configure the pmp address of register 7 in mode 1
li t5, 536871295
csrw pmpaddr7, t5

 # configure the pmp address of register 8 in mode 2
li t5, 536871358
csrw pmpaddr8, t5

 # configure the pmp address of register 9 in mode 3
li t5, 536871454
csrw pmpaddr9, t5

 # configure the pmp address of register 10 in mode 0
li t5, 536871487
csrw pmpaddr10, t5

 # configure the pmp address of register 11 in mode 1
li t5, 536871551
csrw pmpaddr11, t5

 # configure the pmp address of register 12 in mode 2
li t5, 536871614
csrw pmpaddr12, t5

 # configure the pmp address of register 13 in mode 3
li t5, 536871710
csrw pmpaddr13, t5

 # configure the pmp address of register 14 in mode 0
li t5, 536871743
csrw pmpaddr14, t5

 # configure the pmp address of register 15 in mode 1
li t5, 536871807
csrw pmpaddr15, t5

 # configure the pmp address of register 0 in mode 2
li t5, 536871870
csrw pmpaddr0, t5

 # configure the pmp address of register 1 in mode 3
li t5, 536871966
csrw pmpaddr1, t5


  # write pmpcfg0, output 0x09019b938b831810
li t4, 648970879321184272
csrw pmpcfg0, t4

  # write pmpcfg2, output 0x08001c140c041911
li t4, 576491624729942289
csrw pmpcfg2, t4


// Testing
CHECK_CSR pmpcfg0, 0x09019b9b9b838b83, 14
CHECK_CSR pmpcfg2, 0x08001c1c0c041919, 15

// END Configuration and Testing Starting at Register: 2
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN Configuration and Testing Starting at Register: 3
//
// Configuration

  # | Reg   | pmpaddr     | pmpcfg    | L | A    | X | W | R | Comments
  # |3      | 0x2000003f  | 0x83      | 1 | 00   | 0 | 1 | 1 | 0
  # |4      | 0x2000007f  | 0x8b      | 1 | 01   | 0 | 1 | 1 | 1
  # |5      | 0x200000be  | 0x93      | 1 | 10   | 0 | 1 | 1 | 2
  # |6      | 0x2000011e  | 0x9b      | 1 | 11   | 0 | 1 | 1 | 3
  # |7      | 0x2000013f  | 0x01      | 0 | 00   | 0 | 0 | 1 | 4
  # |8      | 0x2000017f  | 0x09      | 0 | 01   | 0 | 0 | 1 | 5
  # |9      | 0x200001be  | 0x11      | 0 | 10   | 0 | 0 | 1 | 6
  # |10     | 0x2000021e  | 0x19      | 0 | 11   | 0 | 0 | 1 | 7
  # |11     | 0x2000023f  | 0x04      | 0 | 00   | 1 | 0 | 0 | 8
  # |12     | 0x2000027f  | 0x0c      | 0 | 01   | 1 | 0 | 0 | 9
  # |13     | 0x200002be  | 0x14      | 0 | 10   | 1 | 0 | 0 | 10
  # |14     | 0x2000031e  | 0x1c      | 0 | 11   | 1 | 0 | 0 | 11
  # |15     | 0x2000033f  | 0x00      | 0 | 00   | 0 | 0 | 0 | 12
  # |0      | 0x2000037f  | 0x08      | 0 | 01   | 0 | 0 | 0 | 13
  # |1      | 0x200003be  | 0x10      | 0 | 10   | 0 | 0 | 0 | 14
  # |2      | 0x2000041e  | 0x18      | 0 | 11   | 0 | 0 | 0 | 15
 # configure the pmp address of register 3 in mode 0
li t5, 536870975
csrw pmpaddr3, t5

 # configure the pmp address of register 4 in mode 1
li t5, 536871039
csrw pmpaddr4, t5

 # configure the pmp address of register 5 in mode 2
li t5, 536871102
csrw pmpaddr5, t5

 # configure the pmp address of register 6 in mode 3
li t5, 536871198
csrw pmpaddr6, t5

 # configure the pmp address of register 7 in mode 0
li t5, 536871231
csrw pmpaddr7, t5

 # configure the pmp address of register 8 in mode 1
li t5, 536871295
csrw pmpaddr8, t5

 # configure the pmp address of register 9 in mode 2
li t5, 536871358
csrw pmpaddr9, t5

 # configure the pmp address of register 10 in mode 3
li t5, 536871454
csrw pmpaddr10, t5

 # configure the pmp address of register 11 in mode 0
li t5, 536871487
csrw pmpaddr11, t5

 # configure the pmp address of register 12 in mode 1
li t5, 536871551
csrw pmpaddr12, t5

 # configure the pmp address of register 13 in mode 2
li t5, 536871614
csrw pmpaddr13, t5

 # configure the pmp address of register 14 in mode 3
li t5, 536871710
csrw pmpaddr14, t5

 # configure the pmp address of register 15 in mode 0
li t5, 536871743
csrw pmpaddr15, t5

 # configure the pmp address of register 0 in mode 1
li t5, 536871807
csrw pmpaddr0, t5

 # configure the pmp address of register 1 in mode 2
li t5, 536871870
csrw pmpaddr1, t5

 # configure the pmp address of register 2 in mode 3
li t5, 536871966
csrw pmpaddr2, t5


  # write pmpcfg0, output 0x019b938b83181008
li t4, 115848442837209096
csrw pmpcfg0, t4

  # write pmpcfg2, output 0x001c140c04191109
li t4, 7903341188813065
csrw pmpcfg2, t4


// Testing
CHECK_CSR pmpcfg0, 0x019b9b9b9b838b83, 16
CHECK_CSR pmpcfg2, 0x001c1c0c04191909, 17

// END Configuration and Testing Starting at Register: 3
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN Configuration and Testing Starting at Register: 4
//
// Configuration

  # | Reg   | pmpaddr     | pmpcfg    | L | A    | X | W | R | Comments
  # |4      | 0x2000003f  | 0x83      | 1 | 00   | 0 | 1 | 1 | 0
  # |5      | 0x2000007f  | 0x8b      | 1 | 01   | 0 | 1 | 1 | 1
  # |6      | 0x200000be  | 0x93      | 1 | 10   | 0 | 1 | 1 | 2
  # |7      | 0x2000011e  | 0x9b      | 1 | 11   | 0 | 1 | 1 | 3
  # |8      | 0x2000013f  | 0x01      | 0 | 00   | 0 | 0 | 1 | 4
  # |9      | 0x2000017f  | 0x09      | 0 | 01   | 0 | 0 | 1 | 5
  # |10     | 0x200001be  | 0x11      | 0 | 10   | 0 | 0 | 1 | 6
  # |11     | 0x2000021e  | 0x19      | 0 | 11   | 0 | 0 | 1 | 7
  # |12     | 0x2000023f  | 0x04      | 0 | 00   | 1 | 0 | 0 | 8
  # |13     | 0x2000027f  | 0x0c      | 0 | 01   | 1 | 0 | 0 | 9
  # |14     | 0x200002be  | 0x14      | 0 | 10   | 1 | 0 | 0 | 10
  # |15     | 0x2000031e  | 0x1c      | 0 | 11   | 1 | 0 | 0 | 11
  # |0      | 0x2000033f  | 0x00      | 0 | 00   | 0 | 0 | 0 | 12
  # |1      | 0x2000037f  | 0x08      | 0 | 01   | 0 | 0 | 0 | 13
  # |2      | 0x200003be  | 0x10      | 0 | 10   | 0 | 0 | 0 | 14
  # |3      | 0x2000041e  | 0x18      | 0 | 11   | 0 | 0 | 0 | 15
 # configure the pmp address of register 4 in mode 0
li t5, 536870975
csrw pmpaddr4, t5

 # configure the pmp address of register 5 in mode 1
li t5, 536871039
csrw pmpaddr5, t5

 # configure the pmp address of register 6 in mode 2
li t5, 536871102
csrw pmpaddr6, t5

 # configure the pmp address of register 7 in mode 3
li t5, 536871198
csrw pmpaddr7, t5

 # configure the pmp address of register 8 in mode 0
li t5, 536871231
csrw pmpaddr8, t5

 # configure the pmp address of register 9 in mode 1
li t5, 536871295
csrw pmpaddr9, t5

 # configure the pmp address of register 10 in mode 2
li t5, 536871358
csrw pmpaddr10, t5

 # configure the pmp address of register 11 in mode 3
li t5, 536871454
csrw pmpaddr11, t5

 # configure the pmp address of register 12 in mode 0
li t5, 536871487
csrw pmpaddr12, t5

 # configure the pmp address of register 13 in mode 1
li t5, 536871551
csrw pmpaddr13, t5

 # configure the pmp address of register 14 in mode 2
li t5, 536871614
csrw pmpaddr14, t5

 # configure the pmp address of register 15 in mode 3
li t5, 536871710
csrw pmpaddr15, t5

 # configure the pmp address of register 0 in mode 0
li t5, 536871743
csrw pmpaddr0, t5

 # configure the pmp address of register 1 in mode 1
li t5, 536871807
csrw pmpaddr1, t5

 # configure the pmp address of register 2 in mode 2
li t5, 536871870
csrw pmpaddr2, t5

 # configure the pmp address of register 3 in mode 3
li t5, 536871966
csrw pmpaddr3, t5


  # write pmpcfg0, output 0x9b938b8318100800
li t4, 11210457292615976960
csrw pmpcfg0, t4

  # write pmpcfg2, output 0x1c140c0419110901
li t4, 2023255344336144641
csrw pmpcfg2, t4


// Testing
CHECK_CSR pmpcfg0, 0x9b9b9b9b9b838b83, 18
CHECK_CSR pmpcfg2, 0x1c1c0c0419190901, 19

// END Configuration and Testing Starting at Register: 4
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN Configuration and Testing Starting at Register: 5
//
// Configuration

  # | Reg   | pmpaddr     | pmpcfg    | L | A    | X | W | R | Comments
  # |5      | 0x2000003f  | 0x83      | 1 | 00   | 0 | 1 | 1 | 0
  # |6      | 0x2000007f  | 0x8b      | 1 | 01   | 0 | 1 | 1 | 1
  # |7      | 0x200000be  | 0x93      | 1 | 10   | 0 | 1 | 1 | 2
  # |8      | 0x2000011e  | 0x9b      | 1 | 11   | 0 | 1 | 1 | 3
  # |9      | 0x2000013f  | 0x01      | 0 | 00   | 0 | 0 | 1 | 4
  # |10     | 0x2000017f  | 0x09      | 0 | 01   | 0 | 0 | 1 | 5
  # |11     | 0x200001be  | 0x11      | 0 | 10   | 0 | 0 | 1 | 6
  # |12     | 0x2000021e  | 0x19      | 0 | 11   | 0 | 0 | 1 | 7
  # |13     | 0x2000023f  | 0x04      | 0 | 00   | 1 | 0 | 0 | 8
  # |14     | 0x2000027f  | 0x0c      | 0 | 01   | 1 | 0 | 0 | 9
  # |15     | 0x200002be  | 0x14      | 0 | 10   | 1 | 0 | 0 | 10
  # |0      | 0x2000031e  | 0x1c      | 0 | 11   | 1 | 0 | 0 | 11
  # |1      | 0x2000033f  | 0x00      | 0 | 00   | 0 | 0 | 0 | 12
  # |2      | 0x2000037f  | 0x08      | 0 | 01   | 0 | 0 | 0 | 13
  # |3      | 0x200003be  | 0x10      | 0 | 10   | 0 | 0 | 0 | 14
  # |4      | 0x2000041e  | 0x18      | 0 | 11   | 0 | 0 | 0 | 15
 # configure the pmp address of register 5 in mode 0
li t5, 536870975
csrw pmpaddr5, t5

 # configure the pmp address of register 6 in mode 1
li t5, 536871039
csrw pmpaddr6, t5

 # configure the pmp address of register 7 in mode 2
li t5, 536871102
csrw pmpaddr7, t5

 # configure the pmp address of register 8 in mode 3
li t5, 536871198
csrw pmpaddr8, t5

 # configure the pmp address of register 9 in mode 0
li t5, 536871231
csrw pmpaddr9, t5

 # configure the pmp address of register 10 in mode 1
li t5, 536871295
csrw pmpaddr10, t5

 # configure the pmp address of register 11 in mode 2
li t5, 536871358
csrw pmpaddr11, t5

 # configure the pmp address of register 12 in mode 3
li t5, 536871454
csrw pmpaddr12, t5

 # configure the pmp address of register 13 in mode 0
li t5, 536871487
csrw pmpaddr13, t5

 # configure the pmp address of register 14 in mode 1
li t5, 536871551
csrw pmpaddr14, t5

 # configure the pmp address of register 15 in mode 2
li t5, 536871614
csrw pmpaddr15, t5

 # configure the pmp address of register 0 in mode 3
li t5, 536871710
csrw pmpaddr0, t5

 # configure the pmp address of register 1 in mode 0
li t5, 536871743
csrw pmpaddr1, t5

 # configure the pmp address of register 2 in mode 1
li t5, 536871807
csrw pmpaddr2, t5

 # configure the pmp address of register 3 in mode 2
li t5, 536871870
csrw pmpaddr3, t5

 # configure the pmp address of register 4 in mode 3
li t5, 536871966
csrw pmpaddr4, t5


  # write pmpcfg0, output 0x938b83181008001c
li t4, 10631735484709601308
csrw pmpcfg0, t4

  # write pmpcfg2, output 0x140c04191109019b
li t4, 1444534086185583003
csrw pmpcfg2, t4


// Testing
CHECK_CSR pmpcfg0, 0x9b9b9b9b9b838b83, 20
CHECK_CSR pmpcfg2, 0x1c0c04191909019b, 21

// END Configuration and Testing Starting at Register: 5
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN Configuration and Testing Starting at Register: 6
//
// Configuration

  # | Reg   | pmpaddr     | pmpcfg    | L | A    | X | W | R | Comments
  # |6      | 0x2000003f  | 0x83      | 1 | 00   | 0 | 1 | 1 | 0
  # |7      | 0x2000007f  | 0x8b      | 1 | 01   | 0 | 1 | 1 | 1
  # |8      | 0x200000be  | 0x93      | 1 | 10   | 0 | 1 | 1 | 2
  # |9      | 0x2000011e  | 0x9b      | 1 | 11   | 0 | 1 | 1 | 3
  # |10     | 0x2000013f  | 0x01      | 0 | 00   | 0 | 0 | 1 | 4
  # |11     | 0x2000017f  | 0x09      | 0 | 01   | 0 | 0 | 1 | 5
  # |12     | 0x200001be  | 0x11      | 0 | 10   | 0 | 0 | 1 | 6
  # |13     | 0x2000021e  | 0x19      | 0 | 11   | 0 | 0 | 1 | 7
  # |14     | 0x2000023f  | 0x04      | 0 | 00   | 1 | 0 | 0 | 8
  # |15     | 0x2000027f  | 0x0c      | 0 | 01   | 1 | 0 | 0 | 9
  # |0      | 0x200002be  | 0x14      | 0 | 10   | 1 | 0 | 0 | 10
  # |1      | 0x2000031e  | 0x1c      | 0 | 11   | 1 | 0 | 0 | 11
  # |2      | 0x2000033f  | 0x00      | 0 | 00   | 0 | 0 | 0 | 12
  # |3      | 0x2000037f  | 0x08      | 0 | 01   | 0 | 0 | 0 | 13
  # |4      | 0x200003be  | 0x10      | 0 | 10   | 0 | 0 | 0 | 14
  # |5      | 0x2000041e  | 0x18      | 0 | 11   | 0 | 0 | 0 | 15
 # configure the pmp address of register 6 in mode 0
li t5, 536870975
csrw pmpaddr6, t5

 # configure the pmp address of register 7 in mode 1
li t5, 536871039
csrw pmpaddr7, t5

 # configure the pmp address of register 8 in mode 2
li t5, 536871102
csrw pmpaddr8, t5

 # configure the pmp address of register 9 in mode 3
li t5, 536871198
csrw pmpaddr9, t5

 # configure the pmp address of register 10 in mode 0
li t5, 536871231
csrw pmpaddr10, t5

 # configure the pmp address of register 11 in mode 1
li t5, 536871295
csrw pmpaddr11, t5

 # configure the pmp address of register 12 in mode 2
li t5, 536871358
csrw pmpaddr12, t5

 # configure the pmp address of register 13 in mode 3
li t5, 536871454
csrw pmpaddr13, t5

 # configure the pmp address of register 14 in mode 0
li t5, 536871487
csrw pmpaddr14, t5

 # configure the pmp address of register 15 in mode 1
li t5, 536871551
csrw pmpaddr15, t5

 # configure the pmp address of register 0 in mode 2
li t5, 536871614
csrw pmpaddr0, t5

 # configure the pmp address of register 1 in mode 3
li t5, 536871710
csrw pmpaddr1, t5

 # configure the pmp address of register 2 in mode 0
li t5, 536871743
csrw pmpaddr2, t5

 # configure the pmp address of register 3 in mode 1
li t5, 536871807
csrw pmpaddr3, t5

 # configure the pmp address of register 4 in mode 2
li t5, 536871870
csrw pmpaddr4, t5

 # configure the pmp address of register 5 in mode 3
li t5, 536871966
csrw pmpaddr5, t5


  # write pmpcfg0, output 0x8b83181008001c14
li t4, 10052905250353847316
csrw pmpcfg0, t4

  # write pmpcfg2, output 0x0c04191109019b93
li t4, 865844589318216595
csrw pmpcfg2, t4


// Testing
CHECK_CSR pmpcfg0, 0x9b9b9b9b9b838b83, 22
CHECK_CSR pmpcfg2, 0x0c04191909019b9b, 23

// END Configuration and Testing Starting at Register: 6
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN Configuration and Testing Starting at Register: 7
//
// Configuration

  # | Reg   | pmpaddr     | pmpcfg    | L | A    | X | W | R | Comments
  # |7      | 0x2000003f  | 0x83      | 1 | 00   | 0 | 1 | 1 | 0
  # |8      | 0x2000007f  | 0x8b      | 1 | 01   | 0 | 1 | 1 | 1
  # |9      | 0x200000be  | 0x93      | 1 | 10   | 0 | 1 | 1 | 2
  # |10     | 0x2000011e  | 0x9b      | 1 | 11   | 0 | 1 | 1 | 3
  # |11     | 0x2000013f  | 0x01      | 0 | 00   | 0 | 0 | 1 | 4
  # |12     | 0x2000017f  | 0x09      | 0 | 01   | 0 | 0 | 1 | 5
  # |13     | 0x200001be  | 0x11      | 0 | 10   | 0 | 0 | 1 | 6
  # |14     | 0x2000021e  | 0x19      | 0 | 11   | 0 | 0 | 1 | 7
  # |15     | 0x2000023f  | 0x04      | 0 | 00   | 1 | 0 | 0 | 8
  # |0      | 0x2000027f  | 0x0c      | 0 | 01   | 1 | 0 | 0 | 9
  # |1      | 0x200002be  | 0x14      | 0 | 10   | 1 | 0 | 0 | 10
  # |2      | 0x2000031e  | 0x1c      | 0 | 11   | 1 | 0 | 0 | 11
  # |3      | 0x2000033f  | 0x00      | 0 | 00   | 0 | 0 | 0 | 12
  # |4      | 0x2000037f  | 0x08      | 0 | 01   | 0 | 0 | 0 | 13
  # |5      | 0x200003be  | 0x10      | 0 | 10   | 0 | 0 | 0 | 14
  # |6      | 0x2000041e  | 0x18      | 0 | 11   | 0 | 0 | 0 | 15
 # configure the pmp address of register 7 in mode 0
li t5, 536870975
csrw pmpaddr7, t5

 # configure the pmp address of register 8 in mode 1
li t5, 536871039
csrw pmpaddr8, t5

 # configure the pmp address of register 9 in mode 2
li t5, 536871102
csrw pmpaddr9, t5

 # configure the pmp address of register 10 in mode 3
li t5, 536871198
csrw pmpaddr10, t5

 # configure the pmp address of register 11 in mode 0
li t5, 536871231
csrw pmpaddr11, t5

 # configure the pmp address of register 12 in mode 1
li t5, 536871295
csrw pmpaddr12, t5

 # configure the pmp address of register 13 in mode 2
li t5, 536871358
csrw pmpaddr13, t5

 # configure the pmp address of register 14 in mode 3
li t5, 536871454
csrw pmpaddr14, t5

 # configure the pmp address of register 15 in mode 0
li t5, 536871487
csrw pmpaddr15, t5

 # configure the pmp address of register 0 in mode 1
li t5, 536871551
csrw pmpaddr0, t5

 # configure the pmp address of register 1 in mode 2
li t5, 536871614
csrw pmpaddr1, t5

 # configure the pmp address of register 2 in mode 3
li t5, 536871710
csrw pmpaddr2, t5

 # configure the pmp address of register 3 in mode 0
li t5, 536871743
csrw pmpaddr3, t5

 # configure the pmp address of register 4 in mode 1
li t5, 536871807
csrw pmpaddr4, t5

 # configure the pmp address of register 5 in mode 2
li t5, 536871870
csrw pmpaddr5, t5

 # configure the pmp address of register 6 in mode 3
li t5, 536871966
csrw pmpaddr6, t5


  # write pmpcfg0, output 0x83181008001c140c
li t4, 9446317844957238284
csrw pmpcfg0, t4

  # write pmpcfg2, output 0x04191109019b938b
li t4, 295285980948829067
csrw pmpcfg2, t4


// Testing
CHECK_CSR pmpcfg0, 0x9b9b9b9b9b838b83, 24
CHECK_CSR pmpcfg2, 0x04191909019b9b9b, 25

// END Configuration and Testing Starting at Register: 7
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN Configuration and Testing Starting at Register: 8
//
// Configuration

  # | Reg   | pmpaddr     | pmpcfg    | L | A    | X | W | R | Comments
  # |8      | 0x2000003f  | 0x83      | 1 | 00   | 0 | 1 | 1 | 0
  # |9      | 0x2000007f  | 0x8b      | 1 | 01   | 0 | 1 | 1 | 1
  # |10     | 0x200000be  | 0x93      | 1 | 10   | 0 | 1 | 1 | 2
  # |11     | 0x2000011e  | 0x9b      | 1 | 11   | 0 | 1 | 1 | 3
  # |12     | 0x2000013f  | 0x01      | 0 | 00   | 0 | 0 | 1 | 4
  # |13     | 0x2000017f  | 0x09      | 0 | 01   | 0 | 0 | 1 | 5
  # |14     | 0x200001be  | 0x11      | 0 | 10   | 0 | 0 | 1 | 6
  # |15     | 0x2000021e  | 0x19      | 0 | 11   | 0 | 0 | 1 | 7
  # |0      | 0x2000023f  | 0x04      | 0 | 00   | 1 | 0 | 0 | 8
  # |1      | 0x2000027f  | 0x0c      | 0 | 01   | 1 | 0 | 0 | 9
  # |2      | 0x200002be  | 0x14      | 0 | 10   | 1 | 0 | 0 | 10
  # |3      | 0x2000031e  | 0x1c      | 0 | 11   | 1 | 0 | 0 | 11
  # |4      | 0x2000033f  | 0x00      | 0 | 00   | 0 | 0 | 0 | 12
  # |5      | 0x2000037f  | 0x08      | 0 | 01   | 0 | 0 | 0 | 13
  # |6      | 0x200003be  | 0x10      | 0 | 10   | 0 | 0 | 0 | 14
  # |7      | 0x2000041e  | 0x18      | 0 | 11   | 0 | 0 | 0 | 15
 # configure the pmp address of register 8 in mode 0
li t5, 536870975
csrw pmpaddr8, t5

 # configure the pmp address of register 9 in mode 1
li t5, 536871039
csrw pmpaddr9, t5

 # configure the pmp address of register 10 in mode 2
li t5, 536871102
csrw pmpaddr10, t5

 # configure the pmp address of register 11 in mode 3
li t5, 536871198
csrw pmpaddr11, t5

 # configure the pmp address of register 12 in mode 0
li t5, 536871231
csrw pmpaddr12, t5

 # configure the pmp address of register 13 in mode 1
li t5, 536871295
csrw pmpaddr13, t5

 # configure the pmp address of register 14 in mode 2
li t5, 536871358
csrw pmpaddr14, t5

 # configure the pmp address of register 15 in mode 3
li t5, 536871454
csrw pmpaddr15, t5

 # configure the pmp address of register 0 in mode 0
li t5, 536871487
csrw pmpaddr0, t5

 # configure the pmp address of register 1 in mode 1
li t5, 536871551
csrw pmpaddr1, t5

 # configure the pmp address of register 2 in mode 2
li t5, 536871614
csrw pmpaddr2, t5

 # configure the pmp address of register 3 in mode 3
li t5, 536871710
csrw pmpaddr3, t5

 # configure the pmp address of register 4 in mode 0
li t5, 536871743
csrw pmpaddr4, t5

 # configure the pmp address of register 5 in mode 1
li t5, 536871807
csrw pmpaddr5, t5

 # configure the pmp address of register 6 in mode 2
li t5, 536871870
csrw pmpaddr6, t5

 # configure the pmp address of register 7 in mode 3
li t5, 536871966
csrw pmpaddr7, t5


  # write pmpcfg0, output 0x181008001c140c04
li t4, 1733894653101739012
csrw pmpcfg0, t4

  # write pmpcfg2, output 0x191109019b938b83
li t4, 1806234828062034819
csrw pmpcfg2, t4



// Testing
CHECK_CSR pmpcfg0, 0x9b9b9b9b9b838b83, 26
CHECK_CSR pmpcfg2, 0x191909019b9b9b9b, 27

// END Configuration and Testing Starting at Register: 8
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN Configuration and Testing Starting at Register: 9
//
// Configuration

  # | Reg   | pmpaddr     | pmpcfg    | L | A    | X | W | R | Comments
  # |9      | 0x2000003f  | 0x83      | 1 | 00   | 0 | 1 | 1 | 0
  # |10     | 0x2000007f  | 0x8b      | 1 | 01   | 0 | 1 | 1 | 1
  # |11     | 0x200000be  | 0x93      | 1 | 10   | 0 | 1 | 1 | 2
  # |12     | 0x2000011e  | 0x9b      | 1 | 11   | 0 | 1 | 1 | 3
  # |13     | 0x2000013f  | 0x01      | 0 | 00   | 0 | 0 | 1 | 4
  # |14     | 0x2000017f  | 0x09      | 0 | 01   | 0 | 0 | 1 | 5
  # |15     | 0x200001be  | 0x11      | 0 | 10   | 0 | 0 | 1 | 6
  # |0      | 0x2000021e  | 0x19      | 0 | 11   | 0 | 0 | 1 | 7
  # |1      | 0x2000023f  | 0x04      | 0 | 00   | 1 | 0 | 0 | 8
  # |2      | 0x2000027f  | 0x0c      | 0 | 01   | 1 | 0 | 0 | 9
  # |3      | 0x200002be  | 0x14      | 0 | 10   | 1 | 0 | 0 | 10
  # |4      | 0x2000031e  | 0x1c      | 0 | 11   | 1 | 0 | 0 | 11
  # |5      | 0x2000033f  | 0x00      | 0 | 00   | 0 | 0 | 0 | 12
  # |6      | 0x2000037f  | 0x08      | 0 | 01   | 0 | 0 | 0 | 13
  # |7      | 0x200003be  | 0x10      | 0 | 10   | 0 | 0 | 0 | 14
  # |8      | 0x2000041e  | 0x18      | 0 | 11   | 0 | 0 | 0 | 15
 # configure the pmp address of register 9 in mode 0
li t5, 536870975
csrw pmpaddr9, t5

 # configure the pmp address of register 10 in mode 1
li t5, 536871039
csrw pmpaddr10, t5

 # configure the pmp address of register 11 in mode 2
li t5, 536871102
csrw pmpaddr11, t5

 # configure the pmp address of register 12 in mode 3
li t5, 536871198
csrw pmpaddr12, t5

 # configure the pmp address of register 13 in mode 0
li t5, 536871231
csrw pmpaddr13, t5

 # configure the pmp address of register 14 in mode 1
li t5, 536871295
csrw pmpaddr14, t5

 # configure the pmp address of register 15 in mode 2
li t5, 536871358
csrw pmpaddr15, t5

 # configure the pmp address of register 0 in mode 3
li t5, 536871454
csrw pmpaddr0, t5

 # configure the pmp address of register 1 in mode 0
li t5, 536871487
csrw pmpaddr1, t5

 # configure the pmp address of register 2 in mode 1
li t5, 536871551
csrw pmpaddr2, t5

 # configure the pmp address of register 3 in mode 2
li t5, 536871614
csrw pmpaddr3, t5

 # configure the pmp address of register 4 in mode 3
li t5, 536871710
csrw pmpaddr4, t5

 # configure the pmp address of register 5 in mode 0
li t5, 536871743
csrw pmpaddr5, t5

 # configure the pmp address of register 6 in mode 1
li t5, 536871807
csrw pmpaddr6, t5

 # configure the pmp address of register 7 in mode 2
li t5, 536871870
csrw pmpaddr7, t5

 # configure the pmp address of register 8 in mode 3
li t5, 536871966
csrw pmpaddr8, t5


  # write pmpcfg0, output 0x1008001c140c0419
li t4, 1155173425015948313
csrw pmpcfg0, t4

  # write pmpcfg2, output 0x1109019b938b8318
li t4, 1227514141142123288
csrw pmpcfg2, t4


// Testing
CHECK_CSR pmpcfg0, 0x9b9b9b9b9b838b83, 28
CHECK_CSR pmpcfg2, 0x1909019b9b9b9b9b, 29

// END Configuration and Testing Starting at Register: 9
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN Configuration and Testing Starting at Register: 10
//
// Configuration

  # | Reg   | pmpaddr     | pmpcfg    | L | A    | X | W | R | Comments
  # |10     | 0x2000003f  | 0x83      | 1 | 00   | 0 | 1 | 1 | 0
  # |11     | 0x2000007f  | 0x8b      | 1 | 01   | 0 | 1 | 1 | 1
  # |12     | 0x200000be  | 0x93      | 1 | 10   | 0 | 1 | 1 | 2
  # |13     | 0x2000011e  | 0x9b      | 1 | 11   | 0 | 1 | 1 | 3
  # |14     | 0x2000013f  | 0x01      | 0 | 00   | 0 | 0 | 1 | 4
  # |15     | 0x2000017f  | 0x09      | 0 | 01   | 0 | 0 | 1 | 5
  # |0      | 0x200001be  | 0x11      | 0 | 10   | 0 | 0 | 1 | 6
  # |1      | 0x2000021e  | 0x19      | 0 | 11   | 0 | 0 | 1 | 7
  # |2      | 0x2000023f  | 0x04      | 0 | 00   | 1 | 0 | 0 | 8
  # |3      | 0x2000027f  | 0x0c      | 0 | 01   | 1 | 0 | 0 | 9
  # |4      | 0x200002be  | 0x14      | 0 | 10   | 1 | 0 | 0 | 10
  # |5      | 0x2000031e  | 0x1c      | 0 | 11   | 1 | 0 | 0 | 11
  # |6      | 0x2000033f  | 0x00      | 0 | 00   | 0 | 0 | 0 | 12
  # |7      | 0x2000037f  | 0x08      | 0 | 01   | 0 | 0 | 0 | 13
  # |8      | 0x200003be  | 0x10      | 0 | 10   | 0 | 0 | 0 | 14
  # |9      | 0x2000041e  | 0x18      | 0 | 11   | 0 | 0 | 0 | 15
 # configure the pmp address of register 10 in mode 0
li t5, 536870975
csrw pmpaddr10, t5

 # configure the pmp address of register 11 in mode 1
li t5, 536871039
csrw pmpaddr11, t5

 # configure the pmp address of register 12 in mode 2
li t5, 536871102
csrw pmpaddr12, t5

 # configure the pmp address of register 13 in mode 3
li t5, 536871198
csrw pmpaddr13, t5

 # configure the pmp address of register 14 in mode 0
li t5, 536871231
csrw pmpaddr14, t5

 # configure the pmp address of register 15 in mode 1
li t5, 536871295
csrw pmpaddr15, t5

 # configure the pmp address of register 0 in mode 2
li t5, 536871358
csrw pmpaddr0, t5

 # configure the pmp address of register 1 in mode 3
li t5, 536871454
csrw pmpaddr1, t5

 # configure the pmp address of register 2 in mode 0
li t5, 536871487
csrw pmpaddr2, t5

 # configure the pmp address of register 3 in mode 1
li t5, 536871551
csrw pmpaddr3, t5

 # configure the pmp address of register 4 in mode 2
li t5, 536871614
csrw pmpaddr4, t5

 # configure the pmp address of register 5 in mode 3
li t5, 536871710
csrw pmpaddr5, t5

 # configure the pmp address of register 6 in mode 0
li t5, 536871743
csrw pmpaddr6, t5

 # configure the pmp address of register 7 in mode 1
li t5, 536871807
csrw pmpaddr7, t5

 # configure the pmp address of register 8 in mode 2
li t5, 536871870
csrw pmpaddr8, t5

 # configure the pmp address of register 9 in mode 3
li t5, 536871966
csrw pmpaddr9, t5


  # write pmpcfg0, output 0x08001c140c041911
li t4, 576491624729942289
csrw pmpcfg0, t4

  # write pmpcfg2, output 0x09019b938b831810
li t4, 648970879321184272
csrw pmpcfg2, t4


// Testing
CHECK_CSR pmpcfg0, 0x9b9b9b9b9b838b83, 30
CHECK_CSR pmpcfg2, 0x09019b9b9b9b9b9b, 31

// END Configuration and Testing Starting at Register: 10
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN Configuration and Testing Starting at Register: 11
//
// Configuration

  # | Reg   | pmpaddr     | pmpcfg    | L | A    | X | W | R | Comments
  # |11     | 0x2000003f  | 0x83      | 1 | 00   | 0 | 1 | 1 | 0
  # |12     | 0x2000007f  | 0x8b      | 1 | 01   | 0 | 1 | 1 | 1
  # |13     | 0x200000be  | 0x93      | 1 | 10   | 0 | 1 | 1 | 2
  # |14     | 0x2000011e  | 0x9b      | 1 | 11   | 0 | 1 | 1 | 3
  # |15     | 0x2000013f  | 0x01      | 0 | 00   | 0 | 0 | 1 | 4
  # |0      | 0x2000017f  | 0x09      | 0 | 01   | 0 | 0 | 1 | 5
  # |1      | 0x200001be  | 0x11      | 0 | 10   | 0 | 0 | 1 | 6
  # |2      | 0x2000021e  | 0x19      | 0 | 11   | 0 | 0 | 1 | 7
  # |3      | 0x2000023f  | 0x04      | 0 | 00   | 1 | 0 | 0 | 8
  # |4      | 0x2000027f  | 0x0c      | 0 | 01   | 1 | 0 | 0 | 9
  # |5      | 0x200002be  | 0x14      | 0 | 10   | 1 | 0 | 0 | 10
  # |6      | 0x2000031e  | 0x1c      | 0 | 11   | 1 | 0 | 0 | 11
  # |7      | 0x2000033f  | 0x00      | 0 | 00   | 0 | 0 | 0 | 12
  # |8      | 0x2000037f  | 0x08      | 0 | 01   | 0 | 0 | 0 | 13
  # |9      | 0x200003be  | 0x10      | 0 | 10   | 0 | 0 | 0 | 14
  # |10     | 0x2000041e  | 0x18      | 0 | 11   | 0 | 0 | 0 | 15
 # configure the pmp address of register 11 in mode 0
li t5, 536870975
csrw pmpaddr11, t5

 # configure the pmp address of register 12 in mode 1
li t5, 536871039
csrw pmpaddr12, t5

 # configure the pmp address of register 13 in mode 2
li t5, 536871102
csrw pmpaddr13, t5

 # configure the pmp address of register 14 in mode 3
li t5, 536871198
csrw pmpaddr14, t5

 # configure the pmp address of register 15 in mode 0
li t5, 536871231
csrw pmpaddr15, t5

 # configure the pmp address of register 0 in mode 1
li t5, 536871295
csrw pmpaddr0, t5

 # configure the pmp address of register 1 in mode 2
li t5, 536871358
csrw pmpaddr1, t5

 # configure the pmp address of register 2 in mode 3
li t5, 536871454
csrw pmpaddr2, t5

 # configure the pmp address of register 3 in mode 0
li t5, 536871487
csrw pmpaddr3, t5

 # configure the pmp address of register 4 in mode 1
li t5, 536871551
csrw pmpaddr4, t5

 # configure the pmp address of register 5 in mode 2
li t5, 536871614
csrw pmpaddr5, t5

 # configure the pmp address of register 6 in mode 3
li t5, 536871710
csrw pmpaddr6, t5

 # configure the pmp address of register 7 in mode 0
li t5, 536871743
csrw pmpaddr7, t5

 # configure the pmp address of register 8 in mode 1
li t5, 536871807
csrw pmpaddr8, t5

 # configure the pmp address of register 9 in mode 2
li t5, 536871870
csrw pmpaddr9, t5

 # configure the pmp address of register 10 in mode 3
li t5, 536871966
csrw pmpaddr10, t5


  # write pmpcfg0, output 0x001c140c04191109
li t4, 7903341188813065
csrw pmpcfg0, t4

  # write pmpcfg2, output 0x019b938b83181008
li t4, 115848442837209096
csrw pmpcfg2, t4


// Testing
CHECK_CSR pmpcfg0, 0x9b9b9b9b9b838b83, 32
CHECK_CSR pmpcfg2, 0x019b9b9b9b9b9b9b, 33

// END Configuration and Testing Starting at Register: 11
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN Configuration and Testing Starting at Register: 12
//
// Configuration

  # | Reg   | pmpaddr     | pmpcfg    | L | A    | X | W | R | Comments
  # |12     | 0x2000003f  | 0x83      | 1 | 00   | 0 | 1 | 1 | 0
  # |13     | 0x2000007f  | 0x8b      | 1 | 01   | 0 | 1 | 1 | 1
  # |14     | 0x200000be  | 0x93      | 1 | 10   | 0 | 1 | 1 | 2
  # |15     | 0x2000011e  | 0x9b      | 1 | 11   | 0 | 1 | 1 | 3
  # |0      | 0x2000013f  | 0x01      | 0 | 00   | 0 | 0 | 1 | 4
  # |1      | 0x2000017f  | 0x09      | 0 | 01   | 0 | 0 | 1 | 5
  # |2      | 0x200001be  | 0x11      | 0 | 10   | 0 | 0 | 1 | 6
  # |3      | 0x2000021e  | 0x19      | 0 | 11   | 0 | 0 | 1 | 7
  # |4      | 0x2000023f  | 0x04      | 0 | 00   | 1 | 0 | 0 | 8
  # |5      | 0x2000027f  | 0x0c      | 0 | 01   | 1 | 0 | 0 | 9
  # |6      | 0x200002be  | 0x14      | 0 | 10   | 1 | 0 | 0 | 10
  # |7      | 0x2000031e  | 0x1c      | 0 | 11   | 1 | 0 | 0 | 11
  # |8      | 0x2000033f  | 0x00      | 0 | 00   | 0 | 0 | 0 | 12
  # |9      | 0x2000037f  | 0x08      | 0 | 01   | 0 | 0 | 0 | 13
  # |10     | 0x200003be  | 0x10      | 0 | 10   | 0 | 0 | 0 | 14
  # |11     | 0x2000041e  | 0x18      | 0 | 11   | 0 | 0 | 0 | 15
 # configure the pmp address of register 12 in mode 0
li t5, 536870975
csrw pmpaddr12, t5

 # configure the pmp address of register 13 in mode 1
li t5, 536871039
csrw pmpaddr13, t5

 # configure the pmp address of register 14 in mode 2
li t5, 536871102
csrw pmpaddr14, t5

 # configure the pmp address of register 15 in mode 3
li t5, 536871198
csrw pmpaddr15, t5

 # configure the pmp address of register 0 in mode 0
li t5, 536871231
csrw pmpaddr0, t5

 # configure the pmp address of register 1 in mode 1
li t5, 536871295
csrw pmpaddr1, t5

 # configure the pmp address of register 2 in mode 2
li t5, 536871358
csrw pmpaddr2, t5

 # configure the pmp address of register 3 in mode 3
li t5, 536871454
csrw pmpaddr3, t5

 # configure the pmp address of register 4 in mode 0
li t5, 536871487
csrw pmpaddr4, t5

 # configure the pmp address of register 5 in mode 1
li t5, 536871551
csrw pmpaddr5, t5

 # configure the pmp address of register 6 in mode 2
li t5, 536871614
csrw pmpaddr6, t5

 # configure the pmp address of register 7 in mode 3
li t5, 536871710
csrw pmpaddr7, t5

 # configure the pmp address of register 8 in mode 0
li t5, 536871743
csrw pmpaddr8, t5

 # configure the pmp address of register 9 in mode 1
li t5, 536871807
csrw pmpaddr9, t5

 # configure the pmp address of register 10 in mode 2
li t5, 536871870
csrw pmpaddr10, t5

 # configure the pmp address of register 11 in mode 3
li t5, 536871966
csrw pmpaddr11, t5


  # write pmpcfg0, output 0x1c140c0419110901
li t4, 2023255344336144641
csrw pmpcfg0, t4

  # write pmpcfg2, output 0x9b938b8318100800
li t4, 11210457292615976960
csrw pmpcfg2, t4


// Testing
CHECK_CSR pmpcfg0, 0x9b9b9b9b9b838b83, 34
CHECK_CSR pmpcfg2, 0x9b9b9b9b9b9b9b9b, 35

// END Configuration and Testing Starting at Register: 12
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN Configuration and Testing Starting at Register: 13
//
// Configuration

  # | Reg   | pmpaddr     | pmpcfg    | L | A    | X | W | R | Comments
  # |13     | 0x2000003f  | 0x83      | 1 | 00   | 0 | 1 | 1 | 0
  # |14     | 0x2000007f  | 0x8b      | 1 | 01   | 0 | 1 | 1 | 1
  # |15     | 0x200000be  | 0x93      | 1 | 10   | 0 | 1 | 1 | 2
  # |0      | 0x2000011e  | 0x9b      | 1 | 11   | 0 | 1 | 1 | 3
  # |1      | 0x2000013f  | 0x01      | 0 | 00   | 0 | 0 | 1 | 4
  # |2      | 0x2000017f  | 0x09      | 0 | 01   | 0 | 0 | 1 | 5
  # |3      | 0x200001be  | 0x11      | 0 | 10   | 0 | 0 | 1 | 6
  # |4      | 0x2000021e  | 0x19      | 0 | 11   | 0 | 0 | 1 | 7
  # |5      | 0x2000023f  | 0x04      | 0 | 00   | 1 | 0 | 0 | 8
  # |6      | 0x2000027f  | 0x0c      | 0 | 01   | 1 | 0 | 0 | 9
  # |7      | 0x200002be  | 0x14      | 0 | 10   | 1 | 0 | 0 | 10
  # |8      | 0x2000031e  | 0x1c      | 0 | 11   | 1 | 0 | 0 | 11
  # |9      | 0x2000033f  | 0x00      | 0 | 00   | 0 | 0 | 0 | 12
  # |10     | 0x2000037f  | 0x08      | 0 | 01   | 0 | 0 | 0 | 13
  # |11     | 0x200003be  | 0x10      | 0 | 10   | 0 | 0 | 0 | 14
  # |12     | 0x2000041e  | 0x18      | 0 | 11   | 0 | 0 | 0 | 15
 # configure the pmp address of register 13 in mode 0
li t5, 536870975
csrw pmpaddr13, t5

 # configure the pmp address of register 14 in mode 1
li t5, 536871039
csrw pmpaddr14, t5

 # configure the pmp address of register 15 in mode 2
li t5, 536871102
csrw pmpaddr15, t5

 # configure the pmp address of register 0 in mode 3
li t5, 536871198
csrw pmpaddr0, t5

 # configure the pmp address of register 1 in mode 0
li t5, 536871231
csrw pmpaddr1, t5

 # configure the pmp address of register 2 in mode 1
li t5, 536871295
csrw pmpaddr2, t5

 # configure the pmp address of register 3 in mode 2
li t5, 536871358
csrw pmpaddr3, t5

 # configure the pmp address of register 4 in mode 3
li t5, 536871454
csrw pmpaddr4, t5

 # configure the pmp address of register 5 in mode 0
li t5, 536871487
csrw pmpaddr5, t5

 # configure the pmp address of register 6 in mode 1
li t5, 536871551
csrw pmpaddr6, t5

 # configure the pmp address of register 7 in mode 2
li t5, 536871614
csrw pmpaddr7, t5

 # configure the pmp address of register 8 in mode 3
li t5, 536871710
csrw pmpaddr8, t5

 # configure the pmp address of register 9 in mode 0
li t5, 536871743
csrw pmpaddr9, t5

 # configure the pmp address of register 10 in mode 1
li t5, 536871807
csrw pmpaddr10, t5

 # configure the pmp address of register 11 in mode 2
li t5, 536871870
csrw pmpaddr11, t5

 # configure the pmp address of register 12 in mode 3
li t5, 536871966
csrw pmpaddr12, t5


  # write pmpcfg0, output 0x140c04191109019b
li t4, 1444534086185583003
csrw pmpcfg0, t4

  # write pmpcfg2, output 0x938b83181008001c
li t4, 10631735484709601308
csrw pmpcfg2, t4


// Testing
CHECK_CSR pmpcfg0, 0x9b9b9b9b9b838b83, 36
CHECK_CSR pmpcfg2, 0x9b9b9b9b9b9b9b9b, 37

// END Configuration and Testing Starting at Register: 13
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN Configuration and Testing Starting at Register: 14
//
// Configuration

  # | Reg   | pmpaddr     | pmpcfg    | L | A    | X | W | R | Comments
  # |14     | 0x2000003f  | 0x83      | 1 | 00   | 0 | 1 | 1 | 0
  # |15     | 0x2000007f  | 0x8b      | 1 | 01   | 0 | 1 | 1 | 1
  # |0      | 0x200000be  | 0x93      | 1 | 10   | 0 | 1 | 1 | 2
  # |1      | 0x2000011e  | 0x9b      | 1 | 11   | 0 | 1 | 1 | 3
  # |2      | 0x2000013f  | 0x01      | 0 | 00   | 0 | 0 | 1 | 4
  # |3      | 0x2000017f  | 0x09      | 0 | 01   | 0 | 0 | 1 | 5
  # |4      | 0x200001be  | 0x11      | 0 | 10   | 0 | 0 | 1 | 6
  # |5      | 0x2000021e  | 0x19      | 0 | 11   | 0 | 0 | 1 | 7
  # |6      | 0x2000023f  | 0x04      | 0 | 00   | 1 | 0 | 0 | 8
  # |7      | 0x2000027f  | 0x0c      | 0 | 01   | 1 | 0 | 0 | 9
  # |8      | 0x200002be  | 0x14      | 0 | 10   | 1 | 0 | 0 | 10
  # |9      | 0x2000031e  | 0x1c      | 0 | 11   | 1 | 0 | 0 | 11
  # |10     | 0x2000033f  | 0x00      | 0 | 00   | 0 | 0 | 0 | 12
  # |11     | 0x2000037f  | 0x08      | 0 | 01   | 0 | 0 | 0 | 13
  # |12     | 0x200003be  | 0x10      | 0 | 10   | 0 | 0 | 0 | 14
  # |13     | 0x2000041e  | 0x18      | 0 | 11   | 0 | 0 | 0 | 15
 # configure the pmp address of register 14 in mode 0
li t5, 536870975
csrw pmpaddr14, t5

 # configure the pmp address of register 15 in mode 1
li t5, 536871039
csrw pmpaddr15, t5

 # configure the pmp address of register 0 in mode 2
li t5, 536871102
csrw pmpaddr0, t5

 # configure the pmp address of register 1 in mode 3
li t5, 536871198
csrw pmpaddr1, t5

 # configure the pmp address of register 2 in mode 0
li t5, 536871231
csrw pmpaddr2, t5

 # configure the pmp address of register 3 in mode 1
li t5, 536871295
csrw pmpaddr3, t5

 # configure the pmp address of register 4 in mode 2
li t5, 536871358
csrw pmpaddr4, t5

 # configure the pmp address of register 5 in mode 3
li t5, 536871454
csrw pmpaddr5, t5

 # configure the pmp address of register 6 in mode 0
li t5, 536871487
csrw pmpaddr6, t5

 # configure the pmp address of register 7 in mode 1
li t5, 536871551
csrw pmpaddr7, t5

 # configure the pmp address of register 8 in mode 2
li t5, 536871614
csrw pmpaddr8, t5

 # configure the pmp address of register 9 in mode 3
li t5, 536871710
csrw pmpaddr9, t5

 # configure the pmp address of register 10 in mode 0
li t5, 536871743
csrw pmpaddr10, t5

 # configure the pmp address of register 11 in mode 1
li t5, 536871807
csrw pmpaddr11, t5

 # configure the pmp address of register 12 in mode 2
li t5, 536871870
csrw pmpaddr12, t5

 # configure the pmp address of register 13 in mode 3
li t5, 536871966
csrw pmpaddr13, t5


  # write pmpcfg0, output 0x0c04191109019b93
li t4, 865844589318216595
csrw pmpcfg0, t4

  # write pmpcfg2, output 0x8b83181008001c14
li t4, 10052905250353847316
csrw pmpcfg2, t4


// Testing
CHECK_CSR pmpcfg0, 0x9b9b9b9b9b838b83, 38
CHECK_CSR pmpcfg2, 0x9b9b9b9b9b9b9b9b, 39

// END Configuration and Testing Starting at Register: 14
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN Configuration and Testing Starting at Register: 15
//
// Configuration

  # | Reg   | pmpaddr     | pmpcfg    | L | A    | X | W | R | Comments
  # |15     | 0x2000003f  | 0x83      | 1 | 00   | 0 | 1 | 1 | 0
  # |0      | 0x2000007f  | 0x8b      | 1 | 01   | 0 | 1 | 1 | 1
  # |1      | 0x200000be  | 0x93      | 1 | 10   | 0 | 1 | 1 | 2
  # |2      | 0x2000011e  | 0x9b      | 1 | 11   | 0 | 1 | 1 | 3
  # |3      | 0x2000013f  | 0x01      | 0 | 00   | 0 | 0 | 1 | 4
  # |4      | 0x2000017f  | 0x09      | 0 | 01   | 0 | 0 | 1 | 5
  # |5      | 0x200001be  | 0x11      | 0 | 10   | 0 | 0 | 1 | 6
  # |6      | 0x2000021e  | 0x19      | 0 | 11   | 0 | 0 | 1 | 7
  # |7      | 0x2000023f  | 0x04      | 0 | 00   | 1 | 0 | 0 | 8
  # |8      | 0x2000027f  | 0x0c      | 0 | 01   | 1 | 0 | 0 | 9
  # |9      | 0x200002be  | 0x14      | 0 | 10   | 1 | 0 | 0 | 10
  # |10     | 0x2000031e  | 0x1c      | 0 | 11   | 1 | 0 | 0 | 11
  # |11     | 0x2000033f  | 0x00      | 0 | 00   | 0 | 0 | 0 | 12
  # |12     | 0x2000037f  | 0x08      | 0 | 01   | 0 | 0 | 0 | 13
  # |13     | 0x200003be  | 0x10      | 0 | 10   | 0 | 0 | 0 | 14
  # |14     | 0x2000041e  | 0x18      | 0 | 11   | 0 | 0 | 0 | 15
 # configure the pmp address of register 15 in mode 0
li t5, 536870975
csrw pmpaddr15, t5

 # configure the pmp address of register 0 in mode 1
li t5, 536871039
csrw pmpaddr0, t5

 # configure the pmp address of register 1 in mode 2
li t5, 536871102
csrw pmpaddr1, t5

 # configure the pmp address of register 2 in mode 3
li t5, 536871198
csrw pmpaddr2, t5

 # configure the pmp address of register 3 in mode 0
li t5, 536871231
csrw pmpaddr3, t5

 # configure the pmp address of register 4 in mode 1
li t5, 536871295
csrw pmpaddr4, t5

 # configure the pmp address of register 5 in mode 2
li t5, 536871358
csrw pmpaddr5, t5

 # configure the pmp address of register 6 in mode 3
li t5, 536871454
csrw pmpaddr6, t5

 # configure the pmp address of register 7 in mode 0
li t5, 536871487
csrw pmpaddr7, t5

 # configure the pmp address of register 8 in mode 1
li t5, 536871551
csrw pmpaddr8, t5

 # configure the pmp address of register 9 in mode 2
li t5, 536871614
csrw pmpaddr9, t5

 # configure the pmp address of register 10 in mode 3
li t5, 536871710
csrw pmpaddr10, t5

 # configure the pmp address of register 11 in mode 0
li t5, 536871743
csrw pmpaddr11, t5

 # configure the pmp address of register 12 in mode 1
li t5, 536871807
csrw pmpaddr12, t5

 # configure the pmp address of register 13 in mode 2
li t5, 536871870
csrw pmpaddr13, t5

 # configure the pmp address of register 14 in mode 3
li t5, 536871966
csrw pmpaddr14, t5


  # write pmpcfg0, output 0x04191109019b938b
li t4, 295285980948829067
csrw pmpcfg0, t4

  # write pmpcfg2, output 0x83181008001c140c
li t4, 9446317844957238284
csrw pmpcfg2, t4


// Testing
CHECK_CSR pmpcfg0, 0x9b9b9b9b9b838b83, 40
CHECK_CSR pmpcfg2, 0x9b9b9b9b9b9b9b9b, 41

// END Configuration and Testing Starting at Register: 15
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    # Every entry is locked now, so no address changed after its entry (or the next TOR entry) locked
    CHECK_CSR pmpaddr0, 0x20000040, 50
    CHECK_CSR pmpaddr1, 0x20000070, 51
    CHECK_CSR pmpaddr2, 0x200000b0, 52
    CHECK_CSR pmpaddr3, 0x2000011f, 53
    CHECK_CSR pmpaddr4, 0x2000011f, 54
    CHECK_CSR pmpaddr5, 0x2000011f, 55
    CHECK_CSR pmpaddr6, 0x2000011f, 56
    CHECK_CSR pmpaddr7, 0x2000011f, 57
    CHECK_CSR pmpaddr8, 0x2000011f, 58
    CHECK_CSR pmpaddr9, 0x2000011f, 59
    CHECK_CSR pmpaddr10, 0x2000011f, 60
    CHECK_CSR pmpaddr11, 0x2000011f, 61
    CHECK_CSR pmpaddr12, 0x2000011f, 62
    CHECK_CSR pmpaddr13, 0x2000011f, 63
    CHECK_CSR pmpaddr14, 0x2000011f, 64
    CHECK_CSR pmpaddr15, 0x2000011f, 65

    # The locked regions are RW for M-mode: stores and loads work
    li a1, 0x80000140               # entry 1, TOR
    li a2, 0x13579BDF
    sw a2, 0(a1)
    lw a3, 0(a1)
    SC_CHECK_EQ a3, a2, 70
    li a1, 0x80000480               # entries 3-15, NAPOT
    li a2, 0x2468ACE0
    sw a2, 0(a1)
    lw a3, 0(a1)
    SC_CHECK_EQ a3, a2, 71

    # They have no X: put a ret at each address to fetch, then fetch inside and just outside them
    li a2, 0x00008067               # ret
    .irp adr, 0x800001BC, 0x800001C0, 0x800003FC, 0x80000400, 0x800004FC, 0x80000500
    li a1, \adr
    sw a2, 0(a1)
    .endr
    fence.i
    FETCH 0x800001BC                # last word of the TOR region: fault
    FETCH 0x800001C0                # TOR top is exclusive: runs
    FETCH 0x800003FC                # below the NAPOT region: runs
    FETCH 0x80000400                # first word of the NAPOT region: fault
    FETCH 0x800004FC                # last word of the NAPOT region: fault
    FETCH 0x80000500                # above the NAPOT region: runs

    jal check_traps
    SC_PASS
    j done

// Trap log: log_trap records mcause, mepc and mtval of every trap.  An instruction access fault
// (from FETCH) returns to ra; anything else continues in the WALLY-init-lib.h handler.
// check_traps compares the log with expected_traps, failing with index 0x100 + 3n + k for field k
// (0 = mcause, 1 = mepc, 2 = mtval) of trap n, or 0x1FF if the number of traps differs.
.equ TRAPLOG_MAX, 16
.align 4
log_trap:
    csrrw t0, mscratch, t0          # t0 = trap stack pointer, mscratch = saved t0
    sd t1, -16(t0)
    sd t2, -24(t0)
    sd t3, -32(t0)
    la t1, traplog
    ld t2, 0(t1)
    addi t2, t2, 1                  # count the trap
    sd t2, 0(t1)
    li t1, TRAPLOG_MAX
    bgtu t2, t1, 1f                 # log full: count only
    slli t3, t2, 4
    slli t2, t2, 3
    add t2, t2, t3
    la t1, traplog - 16
    add t1, t1, t2                  # trap n (from 1) goes at traplog + 24n - 16
    csrr t2, mcause
    sd t2, 0(t1)
    csrr t2, mepc
    sd t2, 8(t1)
    csrr t2, mtval
    sd t2, 16(t1)
1:  csrr t2, mcause
    li t1, 1                        # instruction access fault?
    bne t2, t1, 2f
    csrw mepc, ra                   # return from the FETCH
    ld t3, -32(t0)
    ld t2, -24(t0)
    ld t1, -16(t0)
    csrrw t0, mscratch, t0
    mret
2:  ld t3, -32(t0)
    ld t2, -24(t0)
    ld t1, -16(t0)
    csrrw t0, mscratch, t0          # restore t0 and the trap stack pointer
    j trap_handler

check_traps:
    la a1, traplog + 8
    la a2, expected_traps
    ld a3, 0(a2)
    addi a2, a2, 8
    slli a4, a3, 1
    add a3, a3, a4                  # fields to compare
    li a4, 0x100
1:  beqz a3, 2f
    ld a5, 0(a1)                    # actual
    ld a6, 0(a2)                    # expected
    bne a5, a6, 3f
    addi a1, a1, 8
    addi a2, a2, 8
    addi a3, a3, -1
    addi a4, a4, 1
    j 1b
2:  la a1, traplog                  # and no extra traps
    ld a5, 0(a1)
    la a2, expected_traps
    ld a6, 0(a2)
    li a4, 0x1FF
    bne a5, a6, 3f
    ret
3:  la t0, selfcheck_record         # record the mismatch as SC_CHECK_EQ does
    li t1, 2
    sd t1, 0(t0)
    sd a4, 8(t0)
    sd zero, 16(t0)
    sd a6, 24(t0)
    sd a5, 32(t0)
    SC_REPORT_FAIL
    j done

.section .data
.align 3
traplog:                            # number of traps, then mcause, mepc and mtval of each
    .fill 1 + 3*TRAPLOG_MAX, 8, 0
expected_traps:                     # number of traps, then mcause, mepc and mtval of each
    .dword (2f - 1f) / 24
1:  .dword 1, 0x800001BC, 0x800001BC        # instruction access fault: TOR region without X
    .dword 1, 0x80000400, 0x80000400        # instruction access fault: NAPOT region without X
    .dword 1, 0x800004FC, 0x800004FC
2:
