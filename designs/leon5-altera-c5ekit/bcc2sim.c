/*
 * BCC2 link-time configuration to speed up simulation:
 * - Disable all AMBA Plug&Play scanning
 *
 * See bcc/bcc_param.h for more information
 */

#include <bcc/bcc_param.h>

#if 1
/*
 * Define a global variable named __bcc_cfg_skip_clear_bss to prevent
 * initialize .bss section at BCC run-time initialization. The value of the
 * variable does not matter.
 */
int __bcc_cfg_skip_clear_bss;
#endif

int __bcc_con_init(void) {
        __bcc_con_handle = 0;
        return 0;
}

int __bcc_timer_init(void) {
        __bcc_timer_handle = 0;
        return 0;
}

int __bcc_int_init(void) {
        __bcc_int_handle = 0;
        __bcc_int_irqmp_eirq = 0;
        return 0;
}

