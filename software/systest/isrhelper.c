#include "isrhelper.h"

#define NNODES 32
static struct bcc_isr_node nodes[NNODES];

static void defhandler(
        void *arg,
        int source
)
{
        void (*func)(int source) = arg;

        func(source);
}

void catch_interrupt(
        void (*func)(
                int source
        ),
        int source
)
{
        struct bcc_isr_node *node = &nodes[source];

        if (source <= 0) { return; }
        if (NNODES <= source) { return; }

        if (node->handler) {
                bcc_isr_unregister_node(node);
        }

        node->source = source;
        node->handler = defhandler;
        node->arg = func;

        bcc_isr_register_node(node);
}

