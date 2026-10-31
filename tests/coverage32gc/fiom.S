///////////////////////////////////////////
// fiom.S
//
// Written: David_Harris@hmc.edu 27 October 2026
//
// Purpose: Run in S mode with menvcfg.FIOM = 1, then in U mode with senvcfg.FIOM = 0 and 1, so the
//          csr's ENVCFG_FIOM selection sees every value of the FIOM bit it forwards in S and U mode.
//          The ACT tests write menvcfg and senvcfg but never run S or U code with FIOM set.
//          Self-checking: menvcfg.FIOM and senvcfg.FIOM read back as written.
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////

#include "WALLY-init-lib.h"
#include "WALLY-selfcheck.h"

main:
    csrsi menvcfg, 1            # menvcfg.FIOM = 1
    csrwi senvcfg, 0            # senvcfg.FIOM = 0

    li a0, 1                    # S mode with menvcfg.FIOM = 1
    ecall
    csrr t3, senvcfg
    nop
    nop
    li a0, 0                    # U mode with senvcfg.FIOM = 0
    ecall
    nop
    nop
    nop
    li a0, 3
    ecall
    li t2, 0
    SC_CHECK_EQ t3, t2, 1       # senvcfg.FIOM read 0 in S mode

    csrsi senvcfg, 1            # senvcfg.FIOM = 1
    li a0, 0                    # U mode with senvcfg.FIOM = 1
    ecall
    nop
    nop
    nop
    li a0, 3
    ecall

    csrr t3, menvcfg
    andi t3, t3, 1
    li t2, 1
    SC_CHECK_EQ t3, t2, 2       # menvcfg.FIOM = 1
    csrr t3, senvcfg
    andi t3, t3, 1
    SC_CHECK_EQ t3, t2, 3       # senvcfg.FIOM = 1

    SC_PASS
    j done
