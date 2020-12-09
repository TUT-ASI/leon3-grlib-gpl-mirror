#ifndef REPORT_H_
#define REPORT_H_

#define get_pid() ({ unsigned long __tmp; \
  asm volatile ("csrr %0, 0xf14" : "=r"(__tmp)); \
  __tmp; })

int report_start(void);

int report_end(void);

/*
 * return: 0 iff device shall be tested, only used by APBUART test.
 */
int report_device(unsigned int dev);

int report_subtest(int subtest);

void report_mem_test(void);

int fail(int id);

#endif

