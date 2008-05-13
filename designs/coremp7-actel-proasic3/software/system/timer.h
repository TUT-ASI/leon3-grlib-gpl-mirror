#ifndef TIMER_HEADER
#define TIMER_HEADER

/*
 *  Timer register offsets
 */
#define TIMER_SCALER_VAL_OFFSET                 0x00
#define TIMER_SCALER_RELOAD_VAL_OFFSET          0x04
#define TIMER_CONFIG_REG_OFFSET                 0x08
#define TIMER_PRESCALE_REG_OFFSET               0x0C
#define TIMER_T1_COUNTER_VAL_REG_OFFSET         0x10
#define TIMER_T1_RELOAD_VAL_REG_OFFSET          0x14
#define TIMER_T1_CONTROL_REG_OFFSET             0x18

/*
 *  Timer register addresses
 */
#define TIMER_SCALER_VAL                        (TIMER_BASE_ADDR + TIMER_SCALER_VAL_OFFSET)
#define TIMER_SCALER_RELOAD_VAL                 (TIMER_BASE_ADDR + TIMER_SCALER_RELOAD_VAL_OFFSET)
#define TIMER_CONFIG_REG                        (TIMER_BASE_ADDR + TIMER_CONFIG_REG_OFFSET)
#define TIMER_PRESCALE_REG                      (TIMER_BASE_ADDR + TIMER_PRESCALE_REG_OFFSET)
#define TIMER_T1_COUNTER_VAL_REG                (TIMER_BASE_ADDR + TIMER_T1_COUNTER_VAL_REG_OFFSET)
#define TIMER_T1_RELOAD_VAL_REG                 (TIMER_BASE_ADDR + TIMER_T1_RELOAD_VAL_REG_OFFSET)
#define TIMER_T1_CONTROL_REG                    (TIMER_BASE_ADDR + TIMER_T1_CONTROL_REG_OFFSET)

#endif
