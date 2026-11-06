/* Embench's support/main.c, printing whether the benchmark's own check passed */
#include "support.h"
extern void act_putchar(int c);
int __attribute__ ((used))
main (int argc __attribute__ ((unused)), char *argv[] __attribute__ ((unused)))
{
  volatile int result;
  int correct;
  const char *s;
  initialise_board ();
  initialise_benchmark ();
  warm_caches (WARMUP_HEAT);
  start_trigger ();
  result = benchmark ();
  stop_trigger ();
  correct = verify_benchmark (result);
  for (s = correct ? "EMBENCH_CORRECT 1\n" : "EMBENCH_CORRECT 0\n"; *s; s++) act_putchar (*s);
  return 0;
}
