// main.c
// C Runtime entry point
// James Kaden Cassidy
// kacassidy@hmc.edu
// 12/19/2025

#include <stdint.h>

extern void end(void);
extern void example_test(void);
extern int  macro_example_test(void);
extern volatile uint64_t tohost;

void _send_char(char c) {
  uintptr_t base = (uintptr_t) &tohost;

  volatile uint32_t *TO_HOST_PAYLOAD = (volatile uint32_t *)(base + 0);
  volatile uint32_t *TO_HOST_COMMAND = (volatile uint32_t *)(base + 4);

  *TO_HOST_PAYLOAD = c;
  *TO_HOST_COMMAND = 0x01010000;

  return;
}

int sendstring(const char *p){
  int n=0;
  while (*p) {
    _send_char(*p);
    n++;
    p++;
  }

  return n;
}

int main(void) {
    sendstring("Hello World\n");
    return 1;
}
