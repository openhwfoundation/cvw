///////////////////////////////////////////////////////////////////////
// gpt.c
//
// Written: Jaocb Pease jacob.pease@okstate.edu 7/22/2024
//
// Purpose: Code to read GPT Partitions off of an SD card.
//
//
//
// A component of the Wally configurable RISC-V project.
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
///////////////////////////////////////////////////////////////////////

#include "gpt.h"
#include "boot.h"
#include "uart.h"
#include <stddef.h>

int gpt_load_partitions() {
  // size_t block_size = 512/8;
  // long int lba1_buf[block_size];

  BYTE lba1_buf[512];

  int ret = 0;
  //ret = disk_read(/* BYTE * buf, LBA_t sector, UINT count, BYTE card_type */);
  print_time();
  println("Getting GPT information.");
  ret = disk_read(lba1_buf, 1, 1);

  gpt_pth_t *lba1 = (gpt_pth_t *)lba1_buf;

  print_time();
  println("Getting partition entries.");
  BYTE lba2_buf[512];
  ret = disk_read(lba2_buf, (LBA_t)lba1->partition_entries_lba, 1);

  // Load partition entries for the relevant boot partitions.
  partition_entries_t *fdt = (partition_entries_t *)(lba2_buf);
  partition_entries_t *opensbi = (partition_entries_t *)(lba2_buf + 128);
  partition_entries_t *kernel = (partition_entries_t *)(lba2_buf + 256);

  // Load device tree
  print_time();
  println_with_int("Loading device tree at: 0x", FDT_ADDRESS);
  ret = disk_read((BYTE *)FDT_ADDRESS, fdt->first_lba, fdt->last_lba - fdt->first_lba + 1);
  if (ret < 0) {
    print_uart("Failed to load device tree!\r\n");
    return -1;
  }

  // Load OpenSBI
  print_time();
  println_with_int("Loading OpenSBI at: 0x", OPENSBI_ADDRESS);
  ret = disk_read((BYTE *)OPENSBI_ADDRESS, opensbi->first_lba, opensbi->last_lba - opensbi->first_lba + 1);
  if (ret < 0) {
    print_uart("Failed to load OpenSBI!\r\n");
    return -1;
  }

  // Load Linux
  print_time();
  println_with_int("Loading Linux Kernel at: 0x", KERNEL_ADDRESS);
  ret = disk_read((BYTE *)KERNEL_ADDRESS, kernel->first_lba,kernel->last_lba - kernel->first_lba + 1);
  if (ret < 0) {
    print_uart("Failed to load Linux!\r\n");
    return -1;
  }

  print_time();
  println("Done! Flashing LEDs and jumping to OpenSBI...");

  return 0;
}
