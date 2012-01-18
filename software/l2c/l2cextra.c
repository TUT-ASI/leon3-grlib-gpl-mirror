#include <stdlib.h>
#include "l2capi.h"

  void l2c_mtrr_show(struct l2cregs *l2c) {
    int mtrr = (l2c->status & L2C_STA_MTRR_MASK) >> L2C_STA_MTRR;
    int i;
    int en = 0;
    unsigned int mtr;
    if (mtrr != 0) {
      printf("%d MTRR implemented\n", mtrr);
      for (i = 0; i < mtrr; i++) {
        mtr = l2c->mtr[i];
        /* printf("mtr[%d][0x%08X]: %08X\n", i, &l2c->mtr[i] ,mtr); */
        if ((mtr & (L2C_MTR_EN)) != 0 ) { 
          if (((mtr & (L2C_MTR_ACC_MASK)) >> L2C_MTR_ACC) == 0) {
            printf("%2d: 0x%08X - 0x%08X : Uncached\n", i, (mtr & L2C_MTR_ADDR_MASK), 
                   (mtr & L2C_MTR_ADDR_MASK) | ~((mtr & L2C_MTR_MASK_MASK) << 16));
          } else if (((mtr & (L2C_MTR_ACC_MASK)) >> L2C_MTR_ACC) == 1) {
            printf("%2d: 0x%08X - 0x%08X : Write-Through\n", i, (mtr & L2C_MTR_ADDR_MASK), 
                   (mtr & L2C_MTR_ADDR_MASK) | ~((mtr & L2C_MTR_MASK_MASK) << 16));
          };
          en = 1;
        } else if ((mtr & (L2C_MTR_WP)) != 0 ) { 
          printf("%2d: 0x%08X - 0x%08X : Write-Protection\n", i, (mtr & L2C_MTR_ADDR_MASK), 
                 (mtr & L2C_MTR_ADDR_MASK) | ~((mtr & L2C_MTR_MASK_MASK) << 16));
          en = 1;
        };
      };
      if (en == 0) {
        printf("No enabled MTRR found\n");
      };
    } else {
      printf("No MTRR implemented\n");
    }
  };

  void l2c_scrub_show(struct l2cregs *l2c){
    unsigned int ctrl = l2c->scrub_ctrl;
    printf("Scrubber: %s\n", ((ctrl & L2C_SCRUB_EN) ? "Enabled" : "Disabled"));
    printf("Scrub line: %s\n", ((ctrl & L2C_SCRUB_PEN) ? "Pneding" : "Not Pending"));
    printf("Scrub index: %d, way: %d, delay: %d\n", 
          (ctrl & L2C_SCRUB_INDEX_MASK) >> L2C_SCRUB_INDEX,
          (ctrl & L2C_SCRUB_WAY_MASK) >> L2C_SCRUB_WAY,
          l2c->scrub_delay & L2C_SCRUB_DELAY_MASK);
  };

  void l2c_error_show(struct l2cregs *l2c){
    unsigned int err = l2c->error;
    if ((err & L2C_ERR_VALID) != 0 ) {
      printf("Error found\n");
      printf("%s %s-error at addr: 0x%08X\n", 
             ((err & L2C_ERR_COR_UCOR) ? "Un-correctable" : "Correctable"),
             ((err & L2C_ERR_TAG_DATA) ? "data" : "tag"),
             l2c->err_addr);
      if (err & L2C_ERR_SCRUB) {
        printf("Error type: %d, Scrubber%s, Cor-count: %d\n",
              (err & L2C_ERR_TYPE_MASK) >> L2C_ERR_TYPE,
              ((err & L2C_ERR_MULTI) ? ", Multi-error" : ""),
              (err & L2C_ERR_COR_COUNT_MASK) >> L2C_ERR_COR_COUNT);
      } else {
        printf("Error type: %d, AHB-master: %d%s, Cor-count: %d\n",
              (err & L2C_ERR_TYPE_MASK) >> L2C_ERR_TYPE,
              (err & L2C_ERR_MASTER_MASK) >> L2C_ERR_MASTER,
              ((err & L2C_ERR_MULTI) ? ", Multi-error" : ""),
              (err & L2C_ERR_COR_COUNT_MASK) >> L2C_ERR_COR_COUNT);
      };
      printf("IRQ: %d, IRQ-mask: %d, SCB: %d, STCB: %d, COMP: %s\n",
             (err & L2C_ERR_IRQ_PEN_MASK) >> L2C_ERR_IRQ_PEN,
             (err & L2C_ERR_IRQ_MASK_MASK) >> L2C_ERR_IRQ_MASK,
             (err & L2C_ERR_SEL_DCB_MASK) >> L2C_ERR_SEL_DCB,
             (err & L2C_ERR_SEL_TCB_MASK) >> L2C_ERR_SEL_TCB,
             ((err & L2C_ERR_COMP) ? "Enabled" : "Disabled"));

    } else {
      printf("No error found\n");
    };
  };
  
  void l2c_diag_show_data_line(unsigned int diagd_base, int way, int index, int linesize) {
    unsigned int addr = diagd_base + way*(1024*512) + index*linesize;
    volatile unsigned int *p = (unsigned int*)addr;
    printf("0x%08X  %08X %08X %08X %08X %08X %08X %08X %08X\n",
           addr, p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7]);
    if (linesize == 64)
    printf("            %08X %08X %08X %08X %08X %08X %08X %08X\n",
           p[8], p[9], p[10], p[11], p[12], p[13], p[14], p[15]);
  };

  void l2c_diag_show_tag(unsigned int diagt_base, int index, int linesize, int setsize, int header) {
    unsigned int addr = diagt_base + index*linesize;
    volatile unsigned int *p = (unsigned int*)addr;
    unsigned int tmp[4];
    int i;
    for (i=0; i<4; i++) tmp[i] = *(p+i);
    if (header)
      printf("Index Address    |LRU | V D TAG      | V D TAG      | V D TAG      | V D TAG      |\n");
    printf("%5d 0x%08X | %2d | %1d %1d %08X | %1d %1d %08X | %1d %1d %08X | %1d %1d %08X | \n",
           index, addr, l2c_diag_get_lru(tmp[0]),
           l2c_diag_get_valid(tmp[0]), l2c_diag_get_dirty(tmp[0]), l2c_diag_get_tag(tmp[0], setsize),
           l2c_diag_get_valid(tmp[1]), l2c_diag_get_dirty(tmp[1]), l2c_diag_get_tag(tmp[1], setsize),
           l2c_diag_get_valid(tmp[2]), l2c_diag_get_dirty(tmp[2]), l2c_diag_get_tag(tmp[2], setsize),
           l2c_diag_get_valid(tmp[3]), l2c_diag_get_dirty(tmp[3]), l2c_diag_get_tag(tmp[3], setsize));
  };


