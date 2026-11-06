///////////////////////////////////////////////////////////////////////
// sd.h
//
// Written: Jaocb Pease jacob.pease@okstate.edu 7/22/2024
//
// Purpose: Header file for SD card protocol functions. Defines some
//          useful macros.
//
//
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////////////////////////////////

#pragma once

#include <stdint.h>

// Command names
#define SD_CMD_STOP_TRANSMISSION 12
#define SD_CMD_READ_BLOCK_MULTIPLE 18
#define SD_DATA_TOKEN 0xfe

// Response lengths in bytes
#define R1_RESPONSE  1
#define R7_RESPONSE  5
#define R1B_RESPONSE 2

uint8_t crc7(uint8_t prev, uint8_t in);
uint16_t crc16(uint16_t crc, uint8_t data);
uint64_t sd_cmd(uint8_t cmd, uint32_t arg, uint8_t crc);
uint64_t sd_read64(uint16_t * crc);
int init_sd(uint32_t freq, uint32_t sdclk);
