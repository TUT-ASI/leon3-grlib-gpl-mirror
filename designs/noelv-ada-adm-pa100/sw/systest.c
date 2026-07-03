#include <stdio.h>
#include <stdlib.h>

#include "report.h"


/*
void __bcc_init70(void){
  unsigned int * apbuart_ctrl = (unsigned int*)0xfc001008;

  // enable UART
  *apbuart_ctrl = 0x3;
}
*/

int main() {

  printf ("-----------------------\n");
  printf ("INF : Systest start.\n");
  printf ("-----------------------\n");

  report_start();

  //greth_test(0xfc084000LL);
  //apbuart_test(0xfc001000LL);

  report_end();

  printf ("-----------------------\n");
  printf ("INF : Systest finished.\n");
  printf ("-----------------------\n");

  exit (0);
}
