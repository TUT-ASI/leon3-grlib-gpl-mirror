
int __bcc_cfg_skip_clear_bss;

main()

{
	report_start();

	base_test5();
/*
	ramfill();
	leon3_test(1, 0x80000200, 0);
	irqtest(0x80000200);
	apbuart_test(0x80000100);
	gptimer_test(0x80000300);

*/

	report_end();
}
