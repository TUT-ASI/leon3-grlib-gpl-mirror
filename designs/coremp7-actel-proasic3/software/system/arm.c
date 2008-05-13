#define IRQ_VECTOR_ADDR     0x18
#define FIQ_VECTOR_ADDR     0x1C
#define IRQ_VECTOR (unsigned int *)   IRQ_VECTOR_ADDR 
#define FIQ_VECTOR (unsigned int *)   FIQ_VECTOR_ADDR

#define BRANCH_OP_CODE      0xEA000000
#define PIPE_OFFSET               0x08
#define WORD_OFFSET               0x02


/*******************************************************************************
 * SetIRQHandler()
 *
 * This function is used to install a handler for the IRQ interrupt in the ARM
 * core vector table.
 *
 * Note: 
 *  The vector generated is only valid if the address of the interrupt hanldler
 *  is less than 24 bits.
 */
void SetIRQHandler(unsigned int routine) 
{
    unsigned int newVectorValue = 0;
    newVectorValue = ((routine - IRQ_VECTOR_ADDR - PIPE_OFFSET) >> WORD_OFFSET);
    newVectorValue = BRANCH_OP_CODE | newVectorValue;
    *IRQ_VECTOR = newVectorValue;
} 

/*******************************************************************************
 * SetFIQHandler()
 *
 * This function is used to install a handler for the FIQ interrupt in the ARM
 * core vector table.
 *
 * Note: 
 *  The vector generated is only valid if the address of the interrupt hanldler
 *  is less than 24 bits.
 */
void SetFIQHandler(unsigned int routine) 
{
    unsigned int newVectorValue = 0;
    newVectorValue = ((routine - FIQ_VECTOR_ADDR - PIPE_OFFSET) >> WORD_OFFSET);
    newVectorValue = BRANCH_OP_CODE | newVectorValue;
    *FIQ_VECTOR = newVectorValue;
}
