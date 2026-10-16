///////////////////////////////////////////////////////////////////////
// boot.h
//
// Written: Jaocb Pease jacob.pease@okstate.edu 7/22/2024
//
// Purpose: Header for boot.c, main bootloader entry point
//
//
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////////////////////////////////

#ifndef WALLYBOOT
#define WALLYBOOT 10000

#include <stdint.h>
#include "system.h"
typedef unsigned int    UINT;   /* int must be 16-bit or 32-bit */
typedef unsigned char   BYTE;   /* char must be 8-bit */
typedef uint16_t        WORD;   /* 16-bit unsigned integer */
typedef uint32_t        DWORD;  /* 32-bit unsigned integer */
typedef uint64_t        QWORD;  /* 64-bit unsigned integer */
typedef WORD            WCHAR;

typedef QWORD LBA_t;

// Define memory locations of boot images =====================
// These locations are copied from the generic configuration
// of OpenSBI. These addresses can be found in:
// buildroot/output/build/opensbi-0.9/platform/generic/config.mk

// FDT_ADDRESS now defined in system.h
//#define FDT_ADDRESS 0xFF000000        // FW_JUMP_FDT_ADDR
#define OPENSBI_ADDRESS EXT_MEM_BASE    // FW_TEXT_START
#define KERNEL_ADDRESS 0x80200000       // FW_JUMP_ADDR

#define BANNER " █▀█        █▀█        █▀█        █▀▀                 █ █\r\n" \
" █          █ █        █▄▀        █▄▄       ▄▄▄       █ █\r\n" \
" █▄█        █▄█        █ █        █▄▄                 ▀▄▀\r\n" \
" ____          ____  ____      ___      ___   ____    ___\r\n"      \
" \\   \\        /   / /    \\    |   |    |   |  \\   \\  /  /\r\n" \
"  \\   \\  __  /   / /      \\   |   |    |   |   \\   \\/  /\r\n" \
"   \\   \\/  \\/   / /   /\\   \\  |   |    |   |    \\     /\r\n" \
"    \\          / /   ____   \\ |   |___ |   |___  |   |\r\n" \
"     \\___/\\___/ /___/    \\___\\|_______||_______| |___|\r\n\r\n"

// Export disk_read
int disk_read(BYTE * buf, LBA_t sector, UINT count);

// Maximum SDC speed is either the system clock divided by 2 (because
// of the SPI peripheral clock division) or the maximum speed an SD
// card can be pushed to.
#define SDCCLOCK (SYSTEMCLOCK/2 > MAXSDCCLOCK ? MAXSDCCLOCK : SYSTEMCLOCK/2)

#endif // WALLYBOOT
