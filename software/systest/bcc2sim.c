/*
 * BCC2 link-time configuration
 *
 * See bcc/bcc_param.h for more information.
 */

#include <bcc/bcc_param.h>

#if 0
int __bcc_con_init(void) {
        __bcc_con_handle = 0;
        return 0;
}
#endif

int __bcc_timer_init(void) {
        __bcc_timer_handle = 0;
        return 0;
}

#if 0
int __bcc_int_init(void) {
        __bcc_int_handle = 0;
        __bcc_int_irqmp_eirq = 0;
        return 0;
}
#endif

