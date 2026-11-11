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
#include "coremark.h"
#include "core_portme.h"

#if VALIDATION_RUN
volatile ee_s32 seed1_volatile = 0x3415;
volatile ee_s32 seed2_volatile = 0x3415;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PERFORMANCE_RUN
volatile ee_s32 seed1_volatile = 0x0;
volatile ee_s32 seed2_volatile = 0x0;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PROFILE_RUN
volatile ee_s32 seed1_volatile = 0x8;
volatile ee_s32 seed2_volatile = 0x8;
volatile ee_s32 seed3_volatile = 0x8;
#endif
volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;
/* Porting : Timing functions
        How to capture time and convert to seconds must be ported to whatever is
   supported by the platform. e.g. Read value from on board RTC, read value from
   cpu clock cycles performance counter etc. Sample implementation for standard
   time.h and windows.h definitions included.
*/
/* ACT port: ticks are mcycle cycles at one tick per "second", so CoreMark's 10-second minimum
   is always met; CoreMark/MHz = iterations * 1e6 / Total ticks. Cores without mcycle build with
   -DNO_MCYCLE and are timed from the simulator's cycle count instead. */
#define CLOCKS_PER_SEC 1
CORETIMETYPE
barebones_clock()
{
#ifdef NO_MCYCLE
    return 0;
#elif defined(MTIME_ADDR)
    return *(volatile ee_u32 *)MTIME_ADDR;   // SERV: servant_timer counts cycles; SERV has no mcycle
#elif defined(USE_RDCYCLE)
    unsigned long t;
    __asm__ volatile("rdcycle %0" : "=r"(t));   // PicoRV32 has no mcycle CSR
    return (CORETIMETYPE)t;
#else
    unsigned long t;
    __asm__ volatile("csrr %0, mcycle" : "=r"(t));
    return (CORETIMETYPE)t;
#endif
}
/* Define : TIMER_RES_DIVIDER
        Divider to trade off timer resolution and total time that can be
   measured.

        Use lower values to increase resolution, but make sure that overflow
   does not occur. If there are issues with the return value overflowing,
   increase this value.
        */
#define GETMYTIME(_t)              (*_t = barebones_clock())
#define MYTIMEDIFF(fin, ini)       ((fin) - (ini))
#define TIMER_RES_DIVIDER          1
#define SAMPLE_TIME_IMPLEMENTATION 1
#define EE_TICKS_PER_SEC           (CLOCKS_PER_SEC / TIMER_RES_DIVIDER)

/** Define Host specific (POSIX), or target specific global time variables. */
static CORETIMETYPE start_time_val, stop_time_val;

/* Function : start_time
        This function will be called right before starting the timed portion of
   the benchmark.

        Implementation may be capturing a system timer (as implemented in the
   example code) or zeroing some system parameters - e.g. setting the cpu clocks
   cycles to 0.
*/
/* Retired instructions in the timed region, printed by portable_fini when built with -DCOUNT_INSTRET */
#if defined(WALLY_HPM) && !defined(COUNT_INSTRET)
#define COUNT_INSTRET
#endif
static unsigned long instret_start, instret_stop;
static inline unsigned long read_instret(void)
{
    unsigned long t = 0;
#if defined(COUNT_INSTRET) && defined(USE_RDCYCLE)
    __asm__ volatile("rdinstret %0" : "=r"(t));
#elif defined(COUNT_INSTRET)
    __asm__ volatile("csrr %0, minstret" : "=r"(t));
#endif
    return t;
}
#ifdef WALLY_HPM
/* CORE-V-Wally's performance counters mhpmcounter3-17 over the timed region, printed by portable_fini.
   Read outside the mcycle window so that they do not change the score. */
#define HPM_FIRST 3
#define HPM_LAST  17
#define READ_HPM(n, v) __asm__ volatile("csrr %0, mhpmcounter" #n : "=r"(v[n]))
#define READ_HPMS(v) do { READ_HPM(3, v); READ_HPM(4, v); READ_HPM(5, v); READ_HPM(6, v); READ_HPM(7, v); \
    READ_HPM(8, v); READ_HPM(9, v); READ_HPM(10, v); READ_HPM(11, v); READ_HPM(12, v); READ_HPM(13, v); \
    READ_HPM(14, v); READ_HPM(15, v); READ_HPM(16, v); READ_HPM(17, v); } while (0)
static unsigned long hpm_start[HPM_LAST + 1], hpm_stop[HPM_LAST + 1];
#endif
void
start_time(void)
{
#ifdef WALLY_HPM
    READ_HPMS(hpm_start);
#endif
    instret_start = read_instret();
    GETMYTIME(&start_time_val);
}
/* Function : stop_time
        This function will be called right after ending the timed portion of the
   benchmark.

        Implementation may be capturing a system timer (as implemented in the
   example code) or other system parameters - e.g. reading the current value of
   cpu cycles counter.
*/
void
stop_time(void)
{
    GETMYTIME(&stop_time_val);
    instret_stop = read_instret();
#ifdef WALLY_HPM
    READ_HPMS(hpm_stop);
#endif
}
/* Function : get_time
        Return an abstract "ticks" number that signifies time on the system.

        Actual value returned may be cpu cycles, milliseconds or any other
   value, as long as it can be converted to seconds by <time_in_secs>. This
   methodology is taken to accommodate any hardware or simulated platform. The
   sample implementation returns millisecs by default, and the resolution is
   controlled by <TIMER_RES_DIVIDER>
*/
CORE_TICKS
get_time(void)
{
    CORE_TICKS elapsed
        = (CORE_TICKS)(MYTIMEDIFF(stop_time_val, start_time_val));
    return elapsed;
}
/* Function : time_in_secs
        Convert the value returned by get_time to seconds.

        The <secs_ret> type is used to accommodate systems with no support for
   floating point. Default implementation implemented by the EE_TICKS_PER_SEC
   macro above.
*/
secs_ret
time_in_secs(CORE_TICKS ticks)
{
    secs_ret retval = ((secs_ret)ticks) / (secs_ret)EE_TICKS_PER_SEC;
    return retval;
}

ee_u32 default_num_contexts = 1;

/* Function : portable_init
        Target specific initialization code
        Test for some common mistakes.
*/
void
portable_init(core_portable *p, int *argc, char *argv[])
{

    (void)argc; // prevent unused warning
    (void)argv; // prevent unused warning

    if (sizeof(ee_ptr_int) != sizeof(ee_u8 *))
    {
        ee_printf(
            "ERROR! Please define ee_ptr_int to a type that holds a "
            "pointer!\n");
    }
    if (sizeof(ee_u32) != 4)
    {
        ee_printf("ERROR! Please define ee_u32 to a 32b unsigned type!\n");
    }
#ifdef WALLY_HPM
    /* mhpmcounter3-17 count only while their mhpmevent is nonzero */
    __asm__ volatile("csrw mhpmevent3, 1; csrw mhpmevent4, 1; csrw mhpmevent5, 1; csrw mhpmevent6, 1;"
                     "csrw mhpmevent7, 1; csrw mhpmevent8, 1; csrw mhpmevent9, 1; csrw mhpmevent10, 1;"
                     "csrw mhpmevent11, 1; csrw mhpmevent12, 1; csrw mhpmevent13, 1; csrw mhpmevent14, 1;"
                     "csrw mhpmevent15, 1; csrw mhpmevent16, 1; csrw mhpmevent17, 1");
#endif
    p->portable_id = 1;
}
/* Function : portable_fini
        Target specific final code
*/
void
portable_fini(core_portable *p)
{
#ifdef COUNT_INSTRET
    ee_printf("Total instret    : %d\n", (int)(instret_stop - instret_start));
#endif
#ifdef WALLY_HPM
    {
        unsigned long cycles = (unsigned long)get_time();
        unsigned long instrs = instret_stop - instret_start;
        unsigned long c[HPM_LAST + 1];
        unsigned long cm100 = 1000000000UL / cycles;   /* CoreMark/MHz * 100 at 10 iterations */
        unsigned long cpi100 = cycles * 100 / instrs;
        for (int i = HPM_FIRST; i <= HPM_LAST; i++)
            c[i] = hpm_stop[i] - hpm_start[i];
        ee_printf("WALLY CoreMark Results\n");
        ee_printf("Elapsed MCYCLE: %lu\n", cycles);
        ee_printf("Elapsed MINSTRET: %lu\n", instrs);
        ee_printf("COREMARK/MHz Score: 10,000,000 / %lu = %lu.%02lu\n", cycles, cm100 / 100, cm100 % 100);
        ee_printf("CPI: %lu / %lu = %lu.%02lu\n", cycles, instrs, cpi100 / 100, cpi100 % 100);
        ee_printf("Load Stalls %lu\n", c[11]);
        ee_printf("Store Stalls %lu\n", c[12]);
        ee_printf("D-Cache Accesses %lu\n", c[13]);
        ee_printf("D-Cache Misses %lu\n", c[14]);
        ee_printf("I-Cache Accesses %lu\n", c[16]);
        ee_printf("I-Cache Misses %lu\n", c[17]);
        ee_printf("Branches %lu\n", c[3]);
        ee_printf("Branches Miss Predictions %lu\n", c[7]);
        ee_printf("BTB Misses %lu\n", c[8]);
        ee_printf("Jump and JR %lu\n", c[4]);
        ee_printf("RAS Wrong %lu\n", c[9]);
        ee_printf("Returns %lu\n", c[5]);
        ee_printf("BP Class Wrong %lu\n", c[10]);
    }
#endif
    p->portable_id = 0;
}
