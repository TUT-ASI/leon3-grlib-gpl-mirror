#ifndef CMP7WRAPPER_HEADER
#define CMP7WRAPPER_HEADER

/*
 *  CoreMP7 wrapper register offsets
 */
#define CMP7WRAPPER_FIQMASK_REG_OFFSET            0x00
#define CMP7WRAPPER_IRL_REG_OFFSET                0x04
#define CMP7WRAPPER_INTACK_REG_OFFSET             0x08

/*
 * CoreMP7 wrapper register addresses
 */
#define CMP7WRAPPER_FIQMASK_REG                 (CMP7WRAPPER_BASE_ADDR + CMP7WRAPPER_FIQMASK_REG_OFFSET)
#define CMP7WRAPPER_IRL_REG                     (CMP7WRAPPER_BASE_ADDR + CMP7WRAPPER_IRL_REG_OFFSET)
#define CMP7WRAPPER_INTACK_REG                  (CMP7WRAPPER_BASE_ADDR + CMP7WRAPPER_INTACK_REG_OFFSET)

#endif
