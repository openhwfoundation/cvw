///////////////////////////////////////////
// rvvi daemon
//
// Written: Rose Thomposn rose@rosethompson.net
// Created: 31 May 2024
// Modified: 31 May 2024
//
// Purpose: Converts raw socket into rvvi interface to connect into ImperasDV
//
// Documentation:
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwfoundation/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////


#include <arpa/inet.h>
#include <linux/if_packet.h>
#include <linux/ip.h>
#include <linux/udp.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <net/if.h>
#include <netinet/ether.h>
#include "rvviApi.h" // *** bug fix me when this file gets included into the correct directory.
#include "idv/idv.h"


#define DEST_MAC0 0x43
#define DEST_MAC1 0x68
#define DEST_MAC2 0x11
#define DEST_MAC3 0x11
#define DEST_MAC4 0x02
#define DEST_MAC5 0x45

#define SRC_MAC0  0x54
#define SRC_MAC1  0x16
#define SRC_MAC2  0x00
#define SRC_MAC3  0x00
#define SRC_MAC4  0x54
#define SRC_MAC5  0x8F

#define BUF_SIZ   1024

//#define ETHER_TYPE   0x0801  // The type defined in packetizer.sv
#define ETHER_TYPE   0x5c00  // The type defined in packetizer.sv
//#define ETHER_TYPE   0x0000  // The type defined in packetizer.sv
#define DEFAULT_IF   "eno1"

struct sockaddr_ll socket_address;
uint8_t sendbuf[BUF_SIZ];
struct ether_header *sendeh = (struct ether_header *) sendbuf;
int tx_len = 0;
int sockfd;

typedef struct {
  uint64_t PC;
  uint32_t insn;
  uint64_t Mcycle;
  uint64_t Minstret;
  uint8_t Trap : 1;
  uint8_t PrivilegeMode : 2;
  uint8_t GPREn : 1;
  uint8_t FPREn : 1;
  uint16_t CSRCount : 12;
  uint8_t GPRReg : 5;
  uint64_t GPRValue;
  uint8_t FPRReg : 5;
  uint64_t FPRValue;
  uint8_t CSRWen[3];
  uint16_t CSRReg[3];
  uint64_t CSRValue[3];

} RequiredRVVI_t; // total size is 241 bits or 30.125 bytes

typedef struct __attribute__((packed)) {
  uint64_t PC;
  uint32_t insn;
  uint64_t Mcycle;
  uint64_t Minstret;
  uint8_t Trap : 1;
  uint8_t PrivilegeMode : 2;
  uint8_t GPREn : 1;
  uint8_t FPREn : 1;
  uint8_t Pad3: 3;
  uint16_t CSRCount : 12;
  uint16_t Pad4 : 4;
  uint8_t GPRReg : 5;
  uint8_t PadG3 : 3;
  uint64_t GPRValue;
  uint8_t FPRReg : 5;
  uint8_t PadF3 : 3;
  uint64_t FPRValue;
  uint16_t CSR0Wen : 12;
  uint16_t PadC04 : 4;
  uint64_t CSR0Value;
  uint16_t CSR1Wen : 12;
  uint16_t PadC14 : 4;
  uint64_t CSR1Value;
  uint16_t CSR2Wen : 12;
  uint16_t PadC24 : 4;
  uint64_t CSR2Value;
  uint16_t CSR3Wen : 12;
  uint16_t PadC34 : 4;
  uint64_t CSR3Value;
  uint16_t CSR4Wen : 12;
  uint16_t PadC44 : 4;
  uint64_t CSR4Value;
} FixedRequiredRVVI_t; // 904 bits

typedef struct {
  uint8_t RegAddress : 5;
  uint64_t RegValue;
} Reg_t;

void DecodeRVVI(uint8_t *payload, ssize_t payloadsize, RequiredRVVI_t *InstructionData);
void PrintInstructionData(RequiredRVVI_t *InstructionData);
int ProcessRvviAll(RequiredRVVI_t *InstructionData);
void set_gpr(int hart, int reg, uint64_t value);
void set_fpr(int hart, int reg, uint64_t value);
int state_compare(int hart, uint64_t Minstret);

int main(int argc, char **argv){

  if(argc != 2){
    printf("Wrong number of arguments.\n");
    printf("rvvidaemon <ethernet device>\n");
    return -1;
  }

  uint8_t buf[BUF_SIZ];
  int sockopt;
  struct ifreq ifopts;   /* set promiscuous mode */
  struct ether_header *eh = (struct ether_header *) buf;
  ssize_t headerbytes, numbytes, payloadbytes;

  /* Open RAW socket to receive frames */
  if ((sockfd = socket(AF_PACKET, SOCK_RAW, htons(ETHER_TYPE))) == -1) {
    perror("socket");
  }
  printf("Here 0\n");

  /* Set interface to promiscuous mode - do we need to do this every time? */
  strncpy(ifopts.ifr_name, argv[1], IFNAMSIZ-1);
  ioctl(sockfd, SIOCGIFFLAGS, &ifopts);
  printf("Here 1\n");
  ifopts.ifr_flags |= IFF_PROMISC;
  ioctl(sockfd, SIOCSIFFLAGS, &ifopts);
  printf("Here 2\n");
  if (ioctl(sockfd, SIOCGIFINDEX, &ifopts) < 0)
    perror("SIOCGIFINDEX");

  /* Allow the socket to be reused - in case connection is closed prematurely */
  if (setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &sockopt, sizeof sockopt) == -1) {
    perror("setsockopt");
    close(sockfd);
    exit(EXIT_FAILURE);
  }
  printf("Here 3\n");

  /* Bind to device */
  if (setsockopt(sockfd, SOL_SOCKET, SO_BINDTODEVICE, argv[1], IFNAMSIZ-1) == -1)   {
    perror("SO_BINDTODEVICE");
    close(sockfd);
    exit(EXIT_FAILURE);
  }
  printf("Here 4\n");

  if(!rvviVersionCheck(RVVI_API_VERSION)){
    printf("Bad RVVI_API_VERSION\n");
  }

  /* Construct the Ethernet header */
  memset(sendbuf, 0, BUF_SIZ);
  sendbuf[0] = DEST_MAC0;
  sendbuf[1] = DEST_MAC1;
  sendbuf[2] = DEST_MAC2;
  sendbuf[3] = DEST_MAC3;
  sendbuf[4] = DEST_MAC4;
  sendbuf[5] = DEST_MAC5;
  sendbuf[6] = SRC_MAC0;
  sendbuf[7] = SRC_MAC1;
  sendbuf[8] = SRC_MAC2;
  sendbuf[9] = SRC_MAC3;
  sendbuf[10] = SRC_MAC4;
  sendbuf[11] = SRC_MAC5;

  sendeh->ether_type = htons(ETHER_TYPE);
  tx_len += sizeof(struct ether_header);
  /* Packet data */
  sendbuf[tx_len++] = 't';
  sendbuf[tx_len++] = 'r';
  sendbuf[tx_len++] = 'i';
  sendbuf[tx_len++] = 'g';
  sendbuf[tx_len++] = 'i';
  sendbuf[tx_len++] = 'n';

  rvviRefConfigSetString(IDV_CONFIG_MODEL_VENDOR, "riscv.ovpworld.org");
  rvviRefConfigSetString(IDV_CONFIG_MODEL_NAME,"riscv");
  rvviRefConfigSetString(IDV_CONFIG_MODEL_VARIANT, "RV64GC");
  rvviRefConfigSetInt(IDV_CONFIG_MODEL_ADDRESS_BUS_WIDTH, 56);
  rvviRefConfigSetInt(IDV_CONFIG_MAX_NET_LATENCY_RETIREMENTS, 6);

  /* Index of the network device */
  socket_address.sll_ifindex = ifopts.ifr_ifindex;
  /* Address length*/
  socket_address.sll_halen = ETH_ALEN;
  /* Destination MAC */
  socket_address.sll_addr[0] = DEST_MAC0;
  socket_address.sll_addr[1] = DEST_MAC1;
  socket_address.sll_addr[2] = DEST_MAC2;
  socket_address.sll_addr[3] = DEST_MAC3;
  socket_address.sll_addr[4] = DEST_MAC4;
  socket_address.sll_addr[5] = DEST_MAC5;

  int i;
  printf("buffer: ");
  for(i=0;i<tx_len;i++){
    printf("%02hhx ", sendbuf[i]);
  }
  printf("\n");
  printf("sockfd %x\n", sockfd);

  // eventually we want to put the elffiles here
  rvviRefInit(NULL);
  rvviRefPcSet(0, 0x1000);

  // Volatile CSRs
  rvviRefCsrSetVolatile(0, 0xC00);   // CYCLE
  rvviRefCsrSetVolatile(0, 0xB00);   // MCYCLE
  rvviRefCsrSetVolatile(0, 0xC02);   // INSTRET
  rvviRefCsrSetVolatile(0, 0xB02);   // MINSTRET
  rvviRefCsrSetVolatile(0, 0xC01);   // TIME

  int iter;
  for (iter = 0xC03; iter <= 0xC1F; iter++) {
    rvviRefCsrSetVolatile(0, iter);   // HPMCOUNTERx
  }
  // Machine MHPMCOUNTER3 - MHPMCOUNTER31
  for (iter = 0xB03; iter <= 0xB1F; iter++) {
    rvviRefCsrSetVolatile(0, iter);   // MHPMCOUNTERx
  }
  // cannot predict this register due to latency between
  // pending and taken
  rvviRefCsrSetVolatile(0, 0x344);   // MIP
  rvviRefCsrSetVolatile(0, 0x144);   // SIP

  // set bootrom and bootram as volatile memory
  rvviRefMemorySetVolatile(0x1000, 0x1FFF);
  rvviRefMemorySetVolatile(0x2000, 0x2FFF);

  // Privileges for PMA are set in the imperas.ic
  // volatile (IO) regions are defined here
  // only real ROM/RAM areas are BOOTROM and UNCORE_RAM
  rvviRefMemorySetVolatile(0x2000000, 0x2000000 + 0xFFFF);
  rvviRefMemorySetVolatile(0x10060000, 0x10060000 + 0xFF);
  rvviRefMemorySetVolatile(0x10000000, 0x10000000 + 0x7);
  rvviRefMemorySetVolatile(0x0C000000, 0x0C000000 + 0x03FFFFFF);
  rvviRefMemorySetVolatile(0x00013000, 0x00013000 + 0x7F);
  rvviRefMemorySetVolatile(0x10040000, 0x10040000 + 0xFFF);

  while(1) {
    //printf("listener: Waiting to recvfrom...\n");
    numbytes = recvfrom(sockfd, buf, BUF_SIZ, 0, NULL, NULL);
    headerbytes = (sizeof(struct ether_header));
    payloadbytes = numbytes - headerbytes;
    int result;
    //printf("listener: got frame %lu bytes\n", numbytes);
    //printf("payload size: %lu bytes\n", payloadbytes);
    if (eh->ether_dhost[0] == DEST_MAC0 &&
        eh->ether_dhost[1] == DEST_MAC1 &&
        eh->ether_dhost[2] == DEST_MAC2 &&
        eh->ether_dhost[3] == DEST_MAC3 &&
        eh->ether_dhost[4] == DEST_MAC4 &&
        eh->ether_dhost[5] == DEST_MAC5) {
      //printf("Correct destination MAC address\n");
      uint64_t PC;
      uint32_t insn;
      RequiredRVVI_t InstructionData;
      DecodeRVVI(buf + headerbytes, payloadbytes, &InstructionData);
      // now let's drive IDV
      // start simple just drive and compare PC.
      PrintInstructionData(&InstructionData);
      result = ProcessRvviAll(&InstructionData);
      if(result == -1) break;
    }
  }

  printf("Simulation halted due to mismatch\n");

  close(sockfd);



  return 0;
}

int ProcessRvviAll(RequiredRVVI_t *InstructionData){
  long int found;
  uint64_t time = InstructionData->Mcycle;
  uint8_t trap = InstructionData->Trap;
  uint64_t order = InstructionData->Minstret;
  int result;

  result = 0;
  if(InstructionData->GPREn) set_gpr(0, InstructionData->GPRReg, InstructionData->GPRValue);
  if(InstructionData->FPREn) set_fpr(0, InstructionData->FPRReg, InstructionData->FPRValue);

  if (trap) {
    rvviDutTrap(0, InstructionData->PC, InstructionData->insn);
  } else {
    rvviDutRetire(0, InstructionData->PC, InstructionData->insn, 0);
  }

  if(!trap) result = state_compare(0, InstructionData->Minstret);
  // *** set is for nets like interrupts  come back to this.
  //found = rvviRefNetIndexGet("pc_rdata");
  //rvviRefNetSet(found, InstructionData->PC, time);
  return result;

}

int state_compare(int hart, uint64_t Minstret){
  uint8_t result = 1;
  uint8_t stepOk = 0;
  char buf[80];
  rvviDutCycleCountSet(Minstret);
  if(rvviRefEventStep(hart) != 0) {
    stepOk = 1;
    result &= rvviRefPcCompare(hart);
    result &= rvviRefInsBinCompare(hart);
    result &= rvviRefGprsCompare(hart);
    result &= rvviRefFprsCompare(hart);
    result &= rvviRefCsrsCompare(hart);
  } else {
    result = 0;
  }

  if (result == 0) {
    /* Send packet */
    if (sendto(sockfd, sendbuf, tx_len, 0, (struct sockaddr*)&socket_address, sizeof(struct sockaddr_ll)) < 0){
      printf("Send failed\n");
    }else {
      printf("send success!\n");
    }

    sprintf(buf, "MISMATCH @ instruction # %ld\n", Minstret);
    idvMsgError(buf);
    return -1;
  }

}

void set_gpr(int hart, int reg, uint64_t value){
  rvviDutGprSet(hart, reg, value);
}

void set_fpr(int hart, int reg, uint64_t value){
  rvviDutFprSet(hart, reg, value);
}

void DecodeRVVI(uint8_t *payload, ssize_t payloadsize, RequiredRVVI_t *InstructionData){

  FixedRequiredRVVI_t *FixedInstructionData = (FixedRequiredRVVI_t *) payload;
  InstructionData->PC = FixedInstructionData->PC;
  InstructionData->insn = FixedInstructionData->insn;
  InstructionData->Mcycle = FixedInstructionData->Mcycle;
  InstructionData->Minstret = FixedInstructionData->Minstret;
  InstructionData->Trap = FixedInstructionData->Trap;
  InstructionData->PrivilegeMode = FixedInstructionData->PrivilegeMode;
  InstructionData->GPREn = FixedInstructionData->GPREn;
  InstructionData->FPREn = FixedInstructionData->FPREn;
  InstructionData->CSRCount = FixedInstructionData->CSRCount;
  InstructionData->GPRReg = FixedInstructionData->GPRReg;
  InstructionData->GPRValue = FixedInstructionData->GPRValue;
  InstructionData->FPRReg = FixedInstructionData->FPRReg;
  InstructionData->FPRValue = FixedInstructionData->FPRValue;


  InstructionData->CSRReg[0] = FixedInstructionData->CSR0Wen;
  if(InstructionData->CSRReg[0] != 0) InstructionData->CSRWen[0] = 1;
  else InstructionData->CSRWen[0] = 0;
  InstructionData->CSRValue[0] = FixedInstructionData->CSR0Value;

  InstructionData->CSRReg[1] = FixedInstructionData->CSR1Wen;
  if(InstructionData->CSRReg[1] != 0) InstructionData->CSRWen[1] = 1;
  else InstructionData->CSRWen[1] = 0;
  InstructionData->CSRValue[1] = FixedInstructionData->CSR1Value;

  InstructionData->CSRReg[2] = FixedInstructionData->CSR2Wen;
  if(InstructionData->CSRReg[2] != 0) InstructionData->CSRWen[2] = 1;
  else InstructionData->CSRWen[2] = 0;
  InstructionData->CSRValue[2] = FixedInstructionData->CSR2Value;

  //InstructionData->CSRReg[3] = FixedInstructionData->CSR3Wen;
  InstructionData->CSRReg[3] = 0;
  if(InstructionData->CSRReg[3] != 0) InstructionData->CSRWen[3] = 1;
  else InstructionData->CSRWen[3] = 0;
  InstructionData->CSRValue[3] = FixedInstructionData->CSR3Value;

  //InstructionData->CSRReg[4] = FixedInstructionData->CSR4Wen;
  InstructionData->CSRReg[4] = 0;
  if(InstructionData->CSRReg[4] != 0) InstructionData->CSRWen[4] = 1;
  else InstructionData->CSRWen[4] = 0;
  InstructionData->CSRValue[4] = FixedInstructionData->CSR4Value;
}

void PrintInstructionData(RequiredRVVI_t *InstructionData){
  int CSRIndex;
  printf("PC = %lx, insn = %x, Mcycle = %lx, Minstret = %lx, Trap = %hhx, PrivilegeMode = %hhx",
    InstructionData->PC, InstructionData->insn, InstructionData->Mcycle, InstructionData->Minstret, InstructionData->Trap, InstructionData->PrivilegeMode);
  if(InstructionData->GPREn){
    printf(", GPR[%d] = %lx", InstructionData->GPRReg, InstructionData->GPRValue);
  }
  if(InstructionData->FPREn){
    printf(", FPR[%d] = %lx", InstructionData->FPRReg, InstructionData->FPRValue);
  }
  for(CSRIndex = 0; CSRIndex < 3; CSRIndex++){
    if(InstructionData->CSRWen[CSRIndex]){
      printf(", CSR[%x] = %lx", InstructionData->CSRReg[CSRIndex], InstructionData->CSRValue[CSRIndex]);
    }
  }
  printf("\n");
}
