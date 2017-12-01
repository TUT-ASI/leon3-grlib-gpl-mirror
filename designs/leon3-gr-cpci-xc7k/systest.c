
static int gr1553buf[1024];

main()

{

  /* variables and pointers to test RGMII interface */
  int i;
  volatile unsigned long rgmiistatus;
  volatile unsigned long rgmiibuf[256];
  volatile unsigned long* rgmiistatusp = (unsigned long*) 0x80001000;
  volatile unsigned long* rgmiiop = (unsigned long*) 0x80001400;
  volatile unsigned long* rgmiiip = (unsigned long*) 0x80001800;

  report_start();
  
  
  
  if (!get_pid()) mem_test();
  leon3_test(1, 0x80002000, 0);
  irqtest(0x80002000);
  gptimer_test(0x80003000, 8);
  apbuart_test(0x80001000);
  
  //greth_test(0x80000e00);

  //spw_test(0x80100000);
  //spw_test(0x80100100);
  //spw_test(0x80100200);
  //spw_test(0x80100300);
  //spw_test(0x80100400);
  // SPW test disabled, since SPW is disabled by default
  //spw_test(0x80105000);

  gr1553b_test_bcbm(0x8010c000, (unsigned long)gr1553buf);

  report_end();
}
