CoreMP7/GRLIB software
======================

The software in this directory has been written or modified by Fredrik Brunnhede
and Mikael Brunnhede as part of their master thesis work at Gaisler Research.

The system folder in this directory contains all files necessary to initalize a
basic CoreMP7 system wrapped to GRLIB (timers, UART, interrupts). A function 
called "SetupTimerAndUART" is available to perform the complete init in one 
sweep. This function is located in misc.c and does the following:

- Resets the system 'tick' variable (used for measuring time)
- Configures the CoreMP7 wrapper
- Configures the processor for handling interrupts
- Configures the interrupt controller
- Initializes the UART
- Enables fast interrupt handling
- Configures and activates the timer for periodic interrupts (to increment the 
'tick' value)

Please note that the system's memory map is located in the header file platform.h.

Getting up and running using SoftConsole:

Note: Before following the steps below, the system needs to be initialized. 
Using GRMON to connect to the system through the RS232 port named P3 is enough
to accomplish this.

1. Import all files into a SoftConsole project.
2. Add #include "misc.h" to the top of the main program file.
3. Add a call to the SetupTimerAndUART() function at the top of main() in the
   program file.

Note: A version of the Stanford bench that works without changes is supplied in
the same directory as this README file.

After doing this, printing to UART is done using printf() or puts() and the 
system tick value can be read by calling GetTick() or by using a function such 
as the one below.

#include <sys/times.h> (this needs to be included for the function below to work)

int Getclock ()
{
    struct tms rusage;
    times (&rusage);
    return (rusage.tms_utime);
};