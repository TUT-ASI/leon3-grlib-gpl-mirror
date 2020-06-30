#define IRQMPADR 0x80000200  //Address to irq controller
#define IRQ 11 //Interrupt line used by the status module 

extern int *lreg;
//integer power of 2
extern int pow2(int exp);

//returns (32,7) BCH checksum 
extern int encode(int data);

/*modifies a checksum cbits so that it will
generate a single error in bit nr "bit" if mode=0
with mode=1 different multiple errors are generated*/
extern int scramble(int cbits, int bit, int mode);

//disables the caches in the Leon3. Returns the
//previous cache controller conf register value
extern int cache_disable(void);


//Sets the cache controller conf reg to cctrl
extern void cache_reset(int cctrl);

extern void enable_irq (int irq);

extern void disable_irq (int irq); 

extern void clear_irq (int irq); 

extern void force_irq (int irq); 
  
