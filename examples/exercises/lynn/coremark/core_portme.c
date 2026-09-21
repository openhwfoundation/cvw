/*
Copyright 2018 Embedded Microprocessor Benchmark Consortium (EEMBC)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Original Author: Shay Gal-on
*/

#include <stdio.h>
#include <stdlib.h>
#include "coremark.h"

/* MEM_STATIC: no malloc needed */
void *portable_malloc(size_t size) { return NULL; }
void portable_free(void *p) { p = NULL; }

/* Seeds for PERFORMANCE_RUN */
volatile ee_s32 seed1_volatile = 0x0;
volatile ee_s32 seed2_volatile = 0x0;
volatile ee_s32 seed3_volatile = 0x66;
volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;

/* Read a 64-bit CSR on RV32 using the high/low loop pattern */
#define read_csr64(reg) ({ \
    unsigned long __hi, __lo, __tmp; \
    do { \
        asm volatile ("csrr %0, " #reg "h" : "=r"(__hi)); \
        asm volatile ("csrr %0, " #reg   : "=r"(__lo)); \
        asm volatile ("csrr %0, " #reg "h" : "=r"(__tmp)); \
    } while (__hi != __tmp); \
    ((unsigned long long)__hi << 32) | __lo; })

/* Read memory-mapped mtime (64-bit) from CLINT at 0x0200BFF8 */
static unsigned long long read_mtime(void) {
    volatile unsigned long *lo = (volatile unsigned long *)0x0200BFF8;
    volatile unsigned long *hi = (volatile unsigned long *)0x0200BFFC;
    unsigned long h1, h2, l;
    do {
        h1 = *hi;
        l  = *lo;
        h2 = *hi;
    } while (h1 != h2);
    return ((unsigned long long)h1 << 32) | l;
}

#define NSECS_PER_SEC       1000000000
#define EE_TIMER_TICKER_RATE 1000
#define TIMER_RES_DIVIDER   10000
#define EE_TICKS_PER_SEC    (NSECS_PER_SEC / TIMER_RES_DIVIDER)

static unsigned long long start_time_val, stop_time_val;
static unsigned long long start_instr_val, stop_instr_val;

void start_time(void) {
    start_instr_val = read_csr64(instret);
    start_time_val  = read_mtime();
}

void stop_time(void) {
    stop_time_val  = read_mtime();
    stop_instr_val = read_csr64(instret);
}

CORE_TICKS get_time(void) {
    unsigned long long elapsed      = stop_time_val  - start_time_val;
    unsigned long long instructions = stop_instr_val - start_instr_val;
    unsigned long long cm100  = 1000000000ULL / elapsed;
    unsigned long long cpi100 = elapsed * 100 / instructions;
    ee_printf("   WALLY CoreMark Results (from get_time)\n");
    ee_printf("    Elapsed MTIME: %llu\n", elapsed);
    ee_printf("    Elapsed MINSTRET: %llu\n", instructions);
    ee_printf("    COREMARK/MHz Score: 10,000,000 / %llu = %llu.%02llu \n",
              elapsed, cm100 / 100, cm100 % 100);
    ee_printf("    CPI: %llu / %llu = %llu.%02llu\n",
              elapsed, instructions, cpi100 / 100, cpi100 % 100);
    return (CORE_TICKS)elapsed;
}

secs_ret time_in_secs(CORE_TICKS ticks) {
    return ((secs_ret)ticks) / (secs_ret)EE_TICKS_PER_SEC;
}

ee_u32 default_num_contexts = MULTITHREAD;

void portable_init(core_portable *p, int *argc, char *argv[]) {
    if (sizeof(ee_ptr_int) != sizeof(ee_u8 *))
        ee_printf("ERROR! Please define ee_ptr_int to a type that holds a pointer!\n");
    if (sizeof(ee_u32) != 4)
        ee_printf("ERROR! Please define ee_u32 to a 32b unsigned type!\n");
    p->portable_id = 1;
}

void portable_fini(core_portable *p) {
    p->portable_id = 0;
}
