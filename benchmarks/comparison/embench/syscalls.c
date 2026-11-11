/* Minimal newlib stubs: Embench allocates with its own heap (beebsc.c) and prints nothing */
#include <sys/stat.h>
#include <errno.h>
#undef errno
extern int errno;
void *_sbrk(int incr) { (void)incr; errno = ENOMEM; return (void *)-1; }
int _write(int f, const void *b, int n) { (void)f; (void)b; return n; }
int _read(int f, void *b, int n) { (void)f; (void)b; (void)n; return 0; }
int _close(int f) { (void)f; return -1; }
int _fstat(int f, struct stat *st) { (void)f; st->st_mode = S_IFCHR; return 0; }
int _isatty(int f) { (void)f; return 1; }
int _lseek(int f, int o, int w) { (void)f; (void)o; (void)w; return 0; }
void _exit(int c) { (void)c; for (;;) ; }
int _kill(int p, int s) { (void)p; (void)s; errno = EINVAL; return -1; }
int _getpid(void) { return 1; }
