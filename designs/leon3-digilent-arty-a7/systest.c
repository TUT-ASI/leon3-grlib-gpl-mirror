#include <report.h>
#include <gpio.h>
#include <spictrl.h>

int __bcc_cfg_skip_clear_bss;

static const uintptr_t GPIO1_REGS = 0x80000a00u;
static const uintptr_t GPIO1_PIRQ = 6;

static const uintptr_t SPICTRL0_REGS = 0x80000600u;
static const uintptr_t SPICTRL0_PIRQ = 5;

int main(void)
{
	report_start();

	gpio_test(GPIO1_REGS);
	gpio_test_irq(GPIO1_REGS, GPIO1_PIRQ);

	spictrl_test(SPICTRL0_REGS, 0);
	spictrl_test(SPICTRL0_REGS, 1);
	spictrl_irqtest(SPICTRL0_REGS, SPICTRL0_PIRQ);

	base_test();

	report_end();

	return 0;
}

