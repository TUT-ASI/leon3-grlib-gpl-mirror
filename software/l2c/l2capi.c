#include "l2capi.h"

/* L2C Enable / Disable ********************************************************** */
  int l2c_enable(struct l2cregs *l2c){
    unsigned int ctrl = l2c->ctrl;
    l2c->ctrl = (ctrl | L2C_CTRL_EN);
    return((ctrl & L2C_CTRL_EN) != 0);
  };
  
  int l2c_disable(struct l2cregs *l2c){
    unsigned int ctrl = l2c->ctrl;
    l2c->ctrl = (ctrl & ~L2C_CTRL_EN);
    return((ctrl & L2C_CTRL_EN) != 0);
  };
/* ******************************************************************************* */

/* L2C EDAC Enable / Disable ***************************************************** */
  int l2c_edac_enable(struct l2cregs *l2c){
    unsigned int ctrl = l2c->ctrl;
    l2c->ctrl = (ctrl | L2C_CTRL_EDACEN);
    return((ctrl & L2C_CTRL_EDACEN) != 0);
  };

  int l2c_edac_disable(struct l2cregs *l2c){
    unsigned int ctrl = l2c->ctrl;
    l2c->ctrl = (ctrl & ~L2C_CTRL_EDACEN);
    return((ctrl & L2C_CTRL_EDACEN) != 0);
  };
/* ******************************************************************************* */

/* L2C HPROT Enable / Disable **************************************************** */
  void l2c_hprot_enable(struct l2cregs *l2c){
    l2c->ctrl = (l2c->ctrl | L2C_CTRL_HP);
  };

  void l2c_hprot_disable(struct l2cregs *l2c){
    l2c->ctrl = (l2c->ctrl & ~L2C_CTRL_HP);
  };
/* ******************************************************************************* */

/* L2C write-through Enable / Disable ******************************************** */
  void l2c_write_through_enable(struct l2cregs *l2c){
    l2c->ctrl = (l2c->ctrl | L2C_CTRL_WP);
  };

  void l2c_write_through_disable(struct l2cregs *l2c){
    l2c->ctrl = (l2c->ctrl & ~L2C_CTRL_WP);
  };
/* ******************************************************************************* */

/* L2C Status ******************************************************************** */
  int l2c_get_waysize( struct l2cregs *l2c){
    return ((l2c->status & L2C_STA_WAYSIZE_MASK) >> L2C_STA_WAYSIZE);
  };

  int l2c_get_ways( struct l2cregs *l2c){
    return ((l2c->status & L2C_STA_WAYS_MASK) >> L2C_STA_WAYS) + 1;
  };
  
  int l2c_get_linesize( struct l2cregs *l2c){
    int res = 32;
    if ((l2c->status & L2C_STA_LINESIZE) != 0) res = 64; 
    return res;
  };
/* ******************************************************************************* */

/* L2C Flush ********************************************************************* */
  void l2c_invalidate_all(int disable, struct l2cregs *l2c){
    l2c->flusha = (L2C_FLUSH_ALL | L2C_FLUSH_DI*disable | L2C_FLUSH_INV);
  };
  
  void l2c_write_back_all(int disable, struct l2cregs *l2c){
    l2c->flusha = (L2C_FLUSH_ALL | L2C_FLUSH_DI*disable | L2C_FLUSH_WB);
  };
  
  void l2c_flush_all(int disable, struct l2cregs *l2c){
    l2c->flusha = (L2C_FLUSH_ALL | L2C_FLUSH_DI*disable | L2C_FLUSH_INV | L2C_FLUSH_WB);
  };
  
  void l2c_invalidate_addr(unsigned int addr, struct l2cregs *l2c){
    l2c->flusha = (addr & L2C_FLUSH_ADDR_MASK | L2C_FLUSH_INV);
  };
  
  void l2c_write_back_addr(unsigned int addr, struct l2cregs *l2c){
    l2c->flusha = (addr & L2C_FLUSH_ADDR_MASK | L2C_FLUSH_WB);
  };
  
  void l2c_flush_addr(unsigned int addr, struct l2cregs *l2c){
    l2c->flusha = (addr & L2C_FLUSH_ADDR_MASK | L2C_FLUSH_INV | L2C_FLUSH_WB);
  };
  
  void l2c_invalidate_line(unsigned int index, unsigned int way, struct l2cregs *l2c){
    l2c->flushd = (((index << L2C_FLUSH_INDEX) & L2C_FLUSH_INDEX_MASK) | 
                   ((way << L2C_FLUSH_WAY) & L2C_FLUSH_WAY_MASK) | L2C_FLUSH_INV);
  };
  
  void l2c_write_back_line(unsigned int index, unsigned int way, struct l2cregs *l2c){
    l2c->flushd = (((index << L2C_FLUSH_INDEX) & L2C_FLUSH_INDEX_MASK) | 
                   ((way << L2C_FLUSH_WAY) & L2C_FLUSH_WAY_MASK) | L2C_FLUSH_WB);
  };
  
  void l2c_flush_line(unsigned int index, unsigned int way, struct l2cregs *l2c){
    l2c->flushd = (((index << L2C_FLUSH_INDEX) & L2C_FLUSH_INDEX_MASK) | 
                   ((way << L2C_FLUSH_WAY) & L2C_FLUSH_WAY_MASK) | L2C_FLUSH_INV | L2C_FLUSH_WB);
  };
  
  void l2c_invalidate_way(unsigned int tag, unsigned int way, int fetch, int disable, struct l2cregs *l2c){
    l2c->flushd = ((tag & L2C_FLUSH_TAG_MASK) |
                   ((way << L2C_FLUSH_WAY) & L2C_FLUSH_WAY_MASK) | 
                   (L2C_FLUSH_FETCH*fetch) | (L2C_FLUSH_VALID*fetch) | 
                   L2C_FLUSH_WAYFLUSH | L2C_FLUSH_DI*disable | L2C_FLUSH_INV);
  };
  
  void l2c_write_back_way(unsigned int tag, unsigned int way, int fetch, int disable, struct l2cregs *l2c){
    l2c->flushd = ((tag & L2C_FLUSH_TAG_MASK) |
                   ((way << L2C_FLUSH_WAY) & L2C_FLUSH_WAY_MASK) | 
                   (L2C_FLUSH_FETCH*fetch) | (L2C_FLUSH_VALID*fetch) | 
                   L2C_FLUSH_WAYFLUSH | L2C_FLUSH_DI*disable | L2C_FLUSH_WB);
  };
  
  void l2c_flush_way(unsigned int tag, unsigned int way, int fetch, int disable, struct l2cregs *l2c){
    l2c->flushd = ((tag & L2C_FLUSH_TAG_MASK) |
                   ((way << L2C_FLUSH_WAY) & L2C_FLUSH_WAY_MASK) | 
                   (L2C_FLUSH_FETCH*fetch) | (L2C_FLUSH_VALID*fetch) | 
                   L2C_FLUSH_WAYFLUSH | L2C_FLUSH_DI*disable | L2C_FLUSH_INV | L2C_FLUSH_WB);
  };
  
/* ******************************************************************************* */

/* L2C Lock ********************************************************************** */
  int l2c_lock(unsigned int addr, int fetch, struct l2cregs *l2c) {
    int res = 0;
    unsigned int ctrl;
    int lock, ways;
  
    ctrl = l2c->ctrl;
    ways = (l2c->status & L2C_STA_WAYS_MASK) >> L2C_STA_WAYS;
    lock = ((ctrl & L2C_CTRL_LOCK_MASK) >> L2C_CTRL_LOCK) + 1;

    if (lock <= (ways + 1)) {
      l2c->ctrl = (l2c->ctrl & ~L2C_CTRL_LOCK_MASK | ((lock << L2C_CTRL_LOCK) & L2C_CTRL_LOCK_MASK));
      l2c_flush_way(addr, (ways +1 - lock), fetch, 0, l2c);
    } else {
      res = -1;
    }
    return res;
  };
  
  int l2c_unlock(struct l2cregs *l2c) {
    int res = 0;
    unsigned int ctrl;
    int lock;

    ctrl = l2c->ctrl;
    lock = ((ctrl & L2C_CTRL_LOCK_MASK) >> L2C_CTRL_LOCK);

    if (lock > 0) {
      l2c->ctrl = (l2c->ctrl & ~L2C_CTRL_LOCK_MASK | (((lock - 1) << L2C_CTRL_LOCK) & L2C_CTRL_LOCK_MASK));
    } else {
      res = -1;
    }
    return res;
  };
  
  int l2c_unlock_flush(struct l2cregs *l2c) {
    int res = 0;
    unsigned int ctrl;
    int lock, ways;

    ctrl = l2c->ctrl;
    ways = (l2c->status & L2C_STA_WAYS_MASK) >> L2C_STA_WAYS;
    lock = ((ctrl & L2C_CTRL_LOCK_MASK) >> L2C_CTRL_LOCK);

    if (lock <= (ways + 1)) {
      l2c_flush_way(0, (ways +1 - lock), 0, 1, l2c);
      l2c->ctrl = (l2c->ctrl & ~L2C_CTRL_LOCK_MASK | (((lock - 1) << L2C_CTRL_LOCK) & L2C_CTRL_LOCK_MASK));
      l2c_enable(l2c);
    } else {
      res = -1;
    }
    return res;
  };
  
/* ******************************************************************************* */

/* L2C MTRR ********************************************************************** */
  int l2c_mtrr_add_uncached(unsigned int addr, unsigned short mask, struct l2cregs *l2c) {
    int mtrr = (l2c->status & L2C_STA_MTRR_MASK) >> L2C_STA_MTRR;
    int res = 0;
    int en, i;
    i = 0;
    do{
      en = (l2c->mtr[i] & (L2C_MTR_WP | L2C_MTR_EN));
      if (en == 0) {
        l2c->mtr[i] = (addr & L2C_MTR_ADDR_MASK) | (0 << L2C_MTR_ACC) | 
                      (mask & L2C_MTR_MASK_MASK) | L2C_MTR_EN;
      };
      i++;
    }while(i < mtrr && en != 0);
    if (i == mtrr && en != 0) res = -1;
    return res;
  };
  
  int l2c_mtrr_add_writethrough(unsigned int addr, unsigned short mask, struct l2cregs *l2c) {
    int mtrr = (l2c->status & L2C_STA_MTRR_MASK) >> L2C_STA_MTRR;
    int res = 0;
    int en, i;
    i = 0;
    do{
      en = (l2c->mtr[i] & (L2C_MTR_WP | L2C_MTR_EN));
      if (en == 0) {
        l2c->mtr[i] = (addr & L2C_MTR_ADDR_MASK) | (1 << L2C_MTR_ACC) | 
                      (mask & L2C_MTR_MASK_MASK) | L2C_MTR_EN;
      };
      i++;
    }while(i < mtrr && en != 0);
    if (i == mtrr && en != 0) res = -1;
    return res;
  };

  int l2c_mtrr_add_writeprotect(unsigned int addr, unsigned short mask, struct l2cregs *l2c) {
    int mtrr = (l2c->status & L2C_STA_MTRR_MASK) >> L2C_STA_MTRR;
    int res = 0;
    int en, i;
    i = 0;
    do{
      en = (l2c->mtr[i] & (L2C_MTR_WP | L2C_MTR_EN));
      if (en == 0) {
        l2c->mtr[i] = (addr & L2C_MTR_ADDR_MASK) | (0 << L2C_MTR_ACC) | 
                      (mask & L2C_MTR_MASK_MASK) | L2C_MTR_WP;
      };
      i++;
    }while(i < mtrr && en != 0);
    if (i == mtrr && en != 0) res = -1;
    return res;
  };
  
  int l2c_mtrr_del(unsigned int addr, unsigned short mask, struct l2cregs *l2c) {
    int mtrr = (l2c->status & L2C_STA_MTRR_MASK) >> L2C_STA_MTRR;
    int res = -1;
    int en, i;
    unsigned int mtr;
    for (i = 0; i < mtrr; i++) {
      mtr = l2c->mtr[i];
      if ( (mtr & (L2C_MTR_WP | L2C_MTR_EN)) != 0 && 
           ((mtr & L2C_MTR_ADDR_MASK) == (addr & L2C_MTR_ADDR_MASK)) &&
           ((mtr & L2C_MTR_MASK_MASK) == (mask & L2C_MTR_MASK_MASK))) { 
        l2c->mtr[i] = mtr & ~(L2C_MTR_WP | L2C_MTR_EN);
        res++;
      };
    };
    return res;
  };

/* ******************************************************************************* */

/* L2C Scrub ********************************************************************* */
  void l2c_scrub_start(unsigned short delay, struct l2cregs *l2c){
    l2c->scrub_delay = (delay & L2C_SCRUB_DELAY_MASK);
    l2c->scrub_ctrl = (L2C_SCRUB_EN);
  };
  
  void l2c_scrub_stop(struct l2cregs *l2c){
    l2c->scrub_ctrl = (l2c->scrub_ctrl & ~L2C_SCRUB_EN);
  };
  
  void l2c_scrub_line(unsigned int index, unsigned int way, struct l2cregs *l2c){
    l2c->scrub_ctrl = (((index << L2C_SCRUB_INDEX) & L2C_SCRUB_INDEX_MASK) | 
                       ((way << L2C_SCRUB_WAY) & L2C_SCRUB_WAY_MASK) | 
                       L2C_SCRUB_PEN);
  };
  
/* ******************************************************************************* */

/* L2C Error ********************************************************************* */
  void l2c_error_inject_clear(struct l2cregs *l2c) {
    l2c->dcb = 0;
    l2c->tcb = 0;
    l2c->error = l2c->error & ~L2C_ERR_XCB;
  };
  
  int l2c_error_reset(struct l2cregs *l2c) {
    unsigned int err = l2c->error;
    l2c->error = err | L2C_ERR_RST;
    return (err & L2C_ERR_VALID != 0);
  };
  
  
  void l2c_error_inject_tag_rep(int tcb, struct l2cregs *l2c) {
    l2c->tcb = (((tcb << L2C_TCB) & L2C_TCB_MASK));
    l2c->error = (l2c->error | L2C_ERR_XCB);
  };
  
  void l2c_error_inject_data_write(int dcb, struct l2cregs *l2c) {
    l2c->dcb = (((dcb << L2C_DCB_D0) & L2C_DCB_D0_MASK) |
                ((dcb << L2C_DCB_D1) & L2C_DCB_D1_MASK) |
                ((dcb << L2C_DCB_D2) & L2C_DCB_D2_MASK) |
                ((dcb << L2C_DCB_D3) & L2C_DCB_D3_MASK));
    l2c->error = (l2c->error | L2C_ERR_XCB);
  };
  
  void l2c_error_inject_data(unsigned int addr, int dcb, struct l2cregs *l2c) {
    l2c->dcb = (((dcb << L2C_DCB_D0) & L2C_DCB_D0_MASK) |
                ((dcb << L2C_DCB_D1) & L2C_DCB_D1_MASK) |
                ((dcb << L2C_DCB_D2) & L2C_DCB_D2_MASK) |
                ((dcb << L2C_DCB_D3) & L2C_DCB_D3_MASK));
    l2c->err_inject = (addr & L2C_ERR_INJECT_ADDR_MASK | L2C_ERR_INJECT_PEN);
  };

  void l2c_error_irq_enable(int mask, struct l2cregs *l2c){
    l2c->error = (l2c->error | ((mask << L2C_ERR_IRQ_MASK) & L2C_ERR_IRQ_MASK_MASK));
  };
  
  void l2c_error_irq_disable(int mask, struct l2cregs *l2c){
    l2c->error = (l2c->error & ~((mask << L2C_ERR_IRQ_MASK) & L2C_ERR_IRQ_MASK_MASK));
  };
  
/* ******************************************************************************* */

/* L2C Diagnostic **************************************************************** */
  unsigned int log2int(unsigned int v) {
    unsigned r = 0;
    while (v >>= 1){
      r++;
    };
    return r;
  };

  unsigned int l2c_diag_get_tag(unsigned int tag, int waysize){
    unsigned int tmp;
    int i;
    i = 10 + log2int(waysize);
    tmp = (tag >> i); 
    tmp = (tmp << i);
    return tmp;
  };
  
  unsigned int l2c_diag_get_index(unsigned int addr, int waysize, int linesize){
    unsigned int tmp, tmp2;
    int i, j;
    i = 10 + log2int(waysize);
    j = log2int(linesize);
    tmp2 = 0xFFFFFFFF;
    tmp2 = (tmp2 << (32-i));
    tmp2 = (tmp2 >> (32-i+j));
    tmp = ((addr >> j) & tmp2);
    return tmp;
  };
  
  unsigned int l2c_diag_get_offset(unsigned int tag, int linesize){
    unsigned int tmp, tmp2;
    int j;
    j = log2int(linesize);
    tmp2 = 0xFFFFFFFF;
    tmp2 = (tmp2 << (32-j));
    tmp2 = (tmp2 >> (32-j));
    tmp = (tag & tmp2);
    return tmp;
  };
  
  unsigned int l2c_diag_get_valid(unsigned int tag){
    unsigned int tmp;
    tmp = ((tag >> 8) & 0x3);
    return tmp;
  };
  
  unsigned int l2c_diag_get_dirty(unsigned int tag){
    unsigned int tmp;
    tmp = ((tag >> 6) & 0x3);
    return tmp;
  };
  
  unsigned int l2c_diag_get_lru(unsigned int tag){
    unsigned int tmp;
    tmp = (tag  & 0x1f);
    return tmp;
  };

  struct lookup_res l2c_lookup(unsigned int addr, int waysize, int linesize, struct l2cregs *l2c) {
    volatile unsigned int *tags = (unsigned int*)((unsigned int)l2c + 0x80000);
    struct lookup_res res;
    unsigned int tag, index, offset;
    unsigned int tmp;
    int i; 
    
    tag = l2c_diag_get_tag(addr, waysize);
    index = l2c_diag_get_index(addr, waysize, linesize);
  
    res.valid = 0; res.dirty = 0;
    res.lru = l2c_diag_get_lru(*(tags + index*8));

    for (i=0; i<4; i++) {
      tmp = *(tags + index*8 + i);
      if(tag == l2c_diag_get_tag(tmp, waysize)){
        if(l2c_diag_get_valid(tmp) != 0){
          res.valid += l2c_diag_get_valid(tmp);
          res.dirty += l2c_diag_get_dirty(tmp);
          res.way = i;
        };
        if (linesize == 64) {
          tmp = *(tags + index*8 + i + 4);
          if(l2c_diag_get_valid(tmp) != 0){
            res.valid += l2c_diag_get_valid(tmp);
            res.dirty += l2c_diag_get_dirty(tmp);
            res.way = i;
          };
        };
        if (res.valid != 0) break;
      };
    };
    res.tag_addr = ((unsigned int)l2c + 0x80000 + index*linesize + res.way*0x4);
    res.data_addr = ((unsigned int)l2c + 0x200000 + index*linesize + res.way*(1024*512));
    return res;
  };


/* ******************************************************************************* */

