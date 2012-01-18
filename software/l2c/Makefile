all : l2ctest.c l2capi.c l2cextra.c
	sparc-elf-gcc -DRAMSTART=0x00000000 -O2 -g  l2ctest.c l2capi.c l2cextra.c -Wl,-msparcleon0 -o l2ctest.exe
