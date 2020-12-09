/*
 * BCC2 link-time configuration for hardware target
 *
 * See bcc/bcc_param.h for more information
 */

#include <bcc/bcc_param.h>

/* Do not probe for timer */
int __bcc_timer_init(void) {
        __bcc_timer_handle = 0;
        return 0;
}

/* Do not probe for interrupt controller*/
int __bcc_int_init(void) {
        __bcc_int_handle = 0;
        __bcc_int_irqmp_eirq = 0;
        return 0;
}

