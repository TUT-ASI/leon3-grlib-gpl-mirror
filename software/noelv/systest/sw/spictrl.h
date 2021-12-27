#ifndef SPICTRL_H_
#define SPICTRL_H_

/*
 * spictrl_test(addr_t addr, int testsel)
 *
 * Writes fifo depth + 1 words. Writes one more word and
 * checks LT and OV status.
 *
 * Tests automated transfers if the core has support
 * for them.
 *
 * Calls spictrl_extdev_test if testsel = 2.
 *
 */
int spictrl_test(addr_t addr, int testsel);
int spictrl_irqtest(addr_t addr, int irq);
int spictrl_extdev_test(addr_t addr);

#endif // end SPICTRL_H_