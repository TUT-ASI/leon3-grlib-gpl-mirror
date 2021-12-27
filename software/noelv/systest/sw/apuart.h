#ifndef APUART_H_
#define APUART_H_

/* 
 * uart[0] = data
 * uart[1] = status
 * uart[2] = control
 * uart[3] = scaler
 */

static inline int loadmem(uint64_t addr);
int apbuart_test(uint64_t addr);


#endif // end APUART_H_