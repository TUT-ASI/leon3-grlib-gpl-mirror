#ifndef L2C_H_
#define L2C_H_

/*
 * l2c_test(..)
 *
 * memaddr - Memory address
 * regaddr - L2C register base address
 *
 * Returns number of failures during test.
 */
int l2c_test(char *memaddr, struct l2cregs *regaddr);

#endif // end L2C_H_