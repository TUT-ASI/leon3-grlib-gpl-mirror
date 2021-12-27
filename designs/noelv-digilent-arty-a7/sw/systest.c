#include "report.h"
#include <stdio.h>

void __bcc_init70(void){
  unsigned int * apbuart_ctrl = (unsigned int*)0xfc001008;

  // enable UART
  *apbuart_ctrl = 0x3;
}

int main() {
	report_start();

  //apbuart_test(0xfc001000LL);

	report_end();
}
