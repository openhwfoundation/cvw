/* Embench board for running on a core through its riscv-arch-test (ACT) configuration.
   start_trigger and stop_trigger read the cycle counter; stop_trigger prints the cycles in the
   timed region through the ACT console (act_putchar, in crt.S). Score = baseline_ms / (cycles / 1000)
   at CPU_MHZ = 1, as benchmark_speed.py computes it. */
#include <support.h>

extern void act_putchar(int c);
static unsigned long start_cycles;

static unsigned long cycles(void) {
#if defined(MTIME_ADDR)
  return *(volatile unsigned int *)MTIME_ADDR;   /* SERV: servant_timer counts cycles */
#elif defined(USE_RDCYCLE)
  unsigned long t; __asm__ volatile("rdcycle %0" : "=r"(t)); return t;   /* PicoRV32 */
#else
  unsigned long t; __asm__ volatile("csrr %0, mcycle" : "=r"(t)); return t;
#endif
}

static void print_str(const char *s) { while (*s) act_putchar(*s++); }
static void print_dec(unsigned long v) {
  char buf[24]; int n = 0;
  do { buf[n++] = '0' + v % 10; v /= 10; } while (v);
  while (n) act_putchar(buf[--n]);
}

void initialise_board(void) {}
void __attribute__((noinline)) start_trigger(void) { start_cycles = cycles(); }
void __attribute__((noinline)) stop_trigger(void) {
  unsigned long c = cycles() - start_cycles;
  print_str("EMBENCH_CYCLES "); print_dec(c); print_str("\n");
}
