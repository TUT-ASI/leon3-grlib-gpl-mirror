// Marcel's code to deal with CAPI:
#ifndef CAPI_BASE_ADDR
  #define CAPI_BASE_ADDR 0x20000000
#endif //ifndef CAPI_BASE_ADDR
enum capi_registers {
  CAPI_REG_DUT_DEVID    = 0x00 + CAPI_BASE_ADDR,
  CAPI_REG_ERROR        = 0x04 + CAPI_BASE_ADDR,
  CAPI_REG_SUBTEST      = 0x08 + CAPI_BASE_ADDR,
  CAPI_REG_CONFIG       = 0x0C + CAPI_BASE_ADDR,
  CAPI_REG_START_MSG    = 0x10 + CAPI_BASE_ADDR,
  CAPI_REG_END_SIM      = 0x14 + CAPI_BASE_ADDR,
  CAPI_REG_TRIGGER      = 0x18 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_CONTROL = 0x1C + CAPI_BASE_ADDR,
  CAPI_REG_MB32_0       = 0x20 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_1       = 0x24 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_2       = 0x28 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_3       = 0x2C + CAPI_BASE_ADDR,
  CAPI_REG_MB32_4       = 0x30 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_5       = 0x34 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_6       = 0x38 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_7       = 0x3C + CAPI_BASE_ADDR,
  CAPI_REG_MB32_8       = 0x40 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_9       = 0x44 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_10      = 0x48 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_11      = 0x4C + CAPI_BASE_ADDR,
  CAPI_REG_MB32_12      = 0x50 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_13      = 0x54 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_14      = 0x58 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_15      = 0x5C + CAPI_BASE_ADDR,
  CAPI_REG_MB32_16      = 0x60 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_17      = 0x64 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_18      = 0x68 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_19      = 0x6C + CAPI_BASE_ADDR,
  CAPI_REG_MB32_20      = 0x70 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_21      = 0x74 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_22      = 0x78 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_23      = 0x7C + CAPI_BASE_ADDR,
  CAPI_REG_MB32_24      = 0x80 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_25      = 0x84 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_26      = 0x88 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_27      = 0x8C + CAPI_BASE_ADDR,
  CAPI_REG_MB32_28      = 0x90 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_29      = 0x94 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_30      = 0x98 + CAPI_BASE_ADDR,
  CAPI_REG_MB32_31      = 0x9C + CAPI_BASE_ADDR
};

void W32(uintptr_t addr, uint32_t wdata) {
  *((volatile uint32_t *)addr) = wdata;
  printf("W32: ADDR=0x%x; WDATA=0x%x;\n", addr, wdata);
}

void ERROR(uint32_t code) {
  W32(CAPI_REG_ERROR, code);
}

void R32(uint32_t *addr, uint32_t *rdata)
{
  *rdata = *addr;
  printf("R32: ADDR=0x%x; RDATA=0x%x;\n", addr, *rdata);
//  return;
}

void RE32(uint32_t *addr, uint32_t expected)
{
  uint32_t mask = 0xFFFFFFFF;
  if((*addr * mask) != (expected * mask))
  {
    printf("ERROR: RE32: ADDR=0x%x; RDATA=0x%x; EXP=0x%x;\n", addr, *addr, expected);
    ERROR(0xACCE55EE);
  }
  else
  {
    printf("DEBUG: RE32: ADDR=0x%x; RDATA=0x%x; EXP=0x%x\n", addr, *addr, expected);
  }
//  return;
}
void REM32(uint32_t *addr, uint32_t expected, uint32_t mask)
{
  if((*addr * mask) != (expected * mask))
  {
    printf("[ERROR] REM32: ADDR=0x%x; RDATA=0x%x; EXP=0x%x; MSK=0x%x;\n", addr, *addr, expected, mask);
    ERROR(0xACCE55EE);
  }
  else
  {
    printf("[DEBUG] REM32: ADDR=0x%x; RDATA=0x%x; EXP=0x%x; MSK=0x%x;\n", addr, *addr, expected, mask);
  }
}

void FATAL() {
  W32(CAPI_REG_ERROR, 0xFFFFFFFF);
}

void END_SIM() {
  *((volatile uint32_t *)CAPI_REG_END_SIM) = 0x0;
}
// --- end Marcel's code.
