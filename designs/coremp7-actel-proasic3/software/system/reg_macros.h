#ifndef REGISTER_MACROS_HEADER
#define REGISTER_MACROS_HEADER

#define WRITE_REGISTER(ADDR,VAL) (*((unsigned int *)(ADDR)) = VAL)
#define READ_REGISTER(ADDR) (*((unsigned int *)(ADDR)))

#endif
