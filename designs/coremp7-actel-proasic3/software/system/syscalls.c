/*----------------SYSCALL FUNCTIONS---------------*/
#include <stdarg.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/times.h>
#include <reent.h>
#include <sys/stat.h>
#include <errno.h>
#undef errno
extern int errno;
#include "misc.h"

extern volatile unsigned long int tick;

_ssize_t _write (struct _reent *r, int file, const void *ptr, size_t len) {
	
	int i;
	const unsigned char *p;
	p = ptr;
	
	for (i=0; i<len; i++) {
		if (*p == '\n') uart0_putc('\r');
		uart0_putc(*p++);		
	}
	
	return len;
	
}

_ssize_t _read (struct _reent *r, int file, void *ptr, size_t len) {
	
	return len;
	
}

clock_t times(struct tms *buf) {
	
	//struct tms *buffer;
	
	//buffer = buf;
	
	buf->tms_utime = tick;
	buf->tms_stime = 0;
	buf->tms_cutime = 0;
	buf->tms_cstime = 0;
	return(0);
}

int _close_r(
    struct _reent *r, 
    int file)
{
	return 0;
}


_off_t _lseek_r(
    struct _reent *r, 
    int file, 
    _off_t ptr, 
    int dir)
{
	return (_off_t)0;	/*  Always indicate we are at file beginning.  */
}

int _fstat_r(
    struct _reent *r, 
    int file, 
    struct stat *st)
{	
	/*  Always set as character device.				*/
	st->st_mode = S_IFCHR;
	/* assigned to strong type with implicit 	*/
	/* signed/unsigned conversion.  Required by 	*/
	/* newlib.					*/

	return 0;
}

int isatty(int file); /* avoid warning */

int isatty(int file)
{
	return 1;
}

#if 0
static void _exit (int n) {
label:  goto label; /* endless loop */
}
#endif

void *
_sbrk (incr)
     int incr;
{ 
   extern char   end; /* Set by linker.  */
   static char * heap_end; 
   char *        prev_heap_end; 

   if (heap_end == 0)
     heap_end = & end; 

   prev_heap_end = heap_end; 
   heap_end += incr; 

   return (void *) prev_heap_end; 
}

_VOID
_DEFUN (_exit, (rc),
	int rc)
{
  /* Default stub just causes a divide by 0 exception.  */
  int x = rc / INT_MAX;
  x = 4 / x;

  /* Convince GCC that this function never returns.  */
  for (;;)
    ;
}

int
_DEFUN (_kill, (pid, sig),
        int pid  _AND
        int sig)
{
  errno = ENOSYS;
  return -1;
}

int
_DEFUN (_getpid, (),
        _NOARGS)
{
  errno = ENOSYS;
  return -1;
}
