#ifndef ISRHELPER_H_
#define ISRHELPER_H_

#include <bcc/bcc.h>

/*
 * Register interrupt handler
 *
 * The function in parameter func is registered as the interrupt handler for
 * the given interrupt source. The handler is called with source as argument.
 *
 * Interrupt source is not enabled by this function. bcc_int_unmask() can be
 * used to enable it.
 *
 * source: SPARC interrupt number 1-15 or extended interrupt number 16-31.
 * func: Pointer to software routine to execute when the interrupt triggers.
 */
void catch_interrupt(
        void (*func)(
                int source
        ),
        int source
);

#endif

