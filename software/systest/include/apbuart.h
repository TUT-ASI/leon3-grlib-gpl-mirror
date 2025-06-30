#ifndef APUART_H_
#define APUART_H_

#include <stdint.h>

/* 
 * uart[0] = data
 * uart[1] = status
 * uart[2] = control
 * uart[3] = scaler
 */

int apbuart_test(uintptr_t addr);


#endif // end APUART_H_
