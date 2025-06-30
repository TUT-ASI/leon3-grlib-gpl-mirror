#include <report.h>

/*
 * Define a global variable named __bcc_cfg_skip_clear_bss to prevent
 * initialize .bss section at BCC run-time initialization. The value of the
 * variable does not matter.
 */
int __bcc_cfg_skip_clear_bss;

int main(void)
{
	report_start();

	base_test();
/*
	ramfill();
	leon3_test(1, 0x80000200, 0);
	irqtest(0x80000200);
	apbuart_test(0x80000100);
	gptimer_test(0x80000300);

*/

	report_end();

	return 0;
}

