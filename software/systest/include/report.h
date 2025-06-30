#ifndef REPORT_H_
#define REPORT_H_

int report_start(void);

int report_end(void);

/*
 * return: 0 iff device shall be tested, only used by APBUART test.
 */
int report_device(unsigned int dev);

int report_subtest(int subtest);

void report_mem_test(void);

int fail(int id);


/* private */
struct report_ops {
  int (*report_start)(void);
  int (*report_end)(void);
  int (*report_device)(unsigned int dev);
  int (*report_subtest)(int subtest);
  int (*fail)(int dev);
  void (*chkp)(int n);
  void (*report_mem_test)(void);
};

extern const struct report_ops report_ops_grtestmod;
extern const struct report_ops report_ops_stdio;

#endif

