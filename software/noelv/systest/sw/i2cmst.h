#ifndef I2CMST_H_
#define I2CMST_H_

/*
 * Test application for I2CMST
 *
 * Copyright (c) 2008 Gaisler Research AB
 * Copyright (c) 2011 Aeroflex Gaisler AB
 *
 * This test requires that the I2C bus is pulled HIGH and
 * that a memory model with address 0x50 is attached to the
 * bus. The prescale register is by default set to 0x0003
 * which means that correct I2C timing will likely not be
 * attained.
 *
 * The dynamic filter register is not used.
 *
 */

#include "testmod.h"

/*
 * i2cmst_test(int addr)
 *
 * Checks register reset values
 * Writes one byte and then reads it back.
 *
 */
int i2cmst_test(addr_t addr);


#endif // end I2CMST_H_