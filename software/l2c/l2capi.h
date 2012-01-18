/* Ctrl register */
#define L2C_CTRL_EN      (1 << 31)
#define L2C_CTRL_EDACEN  (1 << 30)
#define L2C_CTRL_REP_LRU (0 << 28)
#define L2C_CTRL_REP_RAN (1 << 28)
#define L2C_CTRL_REP_IDX (2 << 28)
#define L2C_CTRL_REP_MOD (3 << 28)
#define L2C_CTRL_INDEX_WAY 12      /* 15:12 */
#define L2C_CTRL_INDEX_WAY_MASK (0xF << 12)
#define L2C_CTRL_LOCK    8         /* 11:8  */
#define L2C_CTRL_LOCK_MASK (0xF << 8)
#define L2C_CTRL_HPRHBP  (1 <<  5)
#define L2C_CTRL_HPB     (1 <<  4)
#define L2C_CTRL_UC      (1 <<  3)
#define L2C_CTRL_HC      (1 <<  2)
#define L2C_CTRL_WP      (1 <<  1)
#define L2C_CTRL_HP      (1 <<  0)

/* Status register */
#define L2C_STA_LINESIZE (1 << 24)
#define L2C_STA_FTTIMING (1 << 23)
#define L2C_STA_EDAC (1 << 22)
#define L2C_STA_MTRR 16       /* 21:16 */
#define L2C_STA_MTRR_MASK (0x3F << 16)
#define L2C_STA_BBUS 13       /* 15:13 */
#define L2C_STA_BBUS_MASK (7 << 13)
#define L2C_STA_WAYSIZE 2     /* 12:2  */
#define L2C_STA_WAYSIZE_MASK (0x7FF << 2)
#define L2C_STA_WAYS  0       /* 1:0   */
#define L2C_STA_WAYS_MASK  (3 << 0)

/* Flush regsters */
#define L2C_FLUSH_ADDR 5        /* 31:5  */
#define L2C_FLUSH_ADDR_MASK (0x7FFFFFF << 5)
#define L2C_FLUSH_DI  (1 << 3)
#define L2C_FLUSH_ALL (1 << 2)
#define L2C_FLUSH_WB  (1 << 1)
#define L2C_FLUSH_INV (1 << 0)
#define L2C_FLUSH_TAG 10        /* 31:10 */
#define L2C_FLUSH_TAG_MASK (0x3FFFFF << 10)
#define L2C_FLUSH_INDEX 16      /* 31:16 */
#define L2C_FLUSH_INDEX_MASK (0xFFFF << 16)
#define L2C_FLUSH_FETCH (1 << 9)
#define L2C_FLUSH_VALID (1 << 8)
#define L2C_FLUSH_DIRTY (1 << 7)
#define L2C_FLUSH_WAY 4         /* 5:4   */
#define L2C_FLUSH_WAY_MASK (3 << 4)
#define L2C_FLUSH_WAYFLUSH (1 << 2)

/* Error regster */
#define L2C_ERR_MASTER 28     /* 31:28 */
#define L2C_ERR_MASTER_MASK (0xF << 28) 
#define L2C_ERR_SCRUB (1 << 27) 
#define L2C_ERR_TYPE 24       /* 31:26 */
#define L2C_ERR_TYPE_MASK (0x7 << 24) 
#define L2C_ERR_TAG_DATA (1 << 23) 
#define L2C_ERR_COR_UCOR (1 << 22) 
#define L2C_ERR_MULTI (1 << 21) 
#define L2C_ERR_VALID (1 << 20) 
#define L2C_ERR_COR_COUNT 16  /* 18:16 */
#define L2C_ERR_COR_COUNT_MASK (0x7 << 16)
#define L2C_ERR_IRQ_PEN 12  /* 15:12 */
#define L2C_ERR_IRQ_PEN_MASK (0xF << 12)
#define L2C_ERR_IRQ_MASK 8   /* 11:8  */
#define L2C_ERR_IRQ_MASK_MASK (0xF << 8)
#define L2C_ERR_SEL_DCB 6     /* 7:6   */
#define L2C_ERR_SEL_DCB_MASK (0x3 << 6)
#define L2C_ERR_SEL_TCB 4     /* 5:4   */
#define L2C_ERR_SEL_TCB_MASK (0x3 << 4)
#define L2C_ERR_XCB (1 << 3) 
#define L2C_ERR_RCB (1 << 2) 
#define L2C_ERR_COMP (1 << 1) 
#define L2C_ERR_RST (1 << 0) 

/* TCB regster */
#define L2C_TCB 0     /* 6:0   */
#define L2C_TCB_MASK (0x7F << 0) 

/* DCB regster */
#define L2C_DCB 0     /* 27:0  */
#define L2C_DCB_MASK (0xFFFFFFF << 0) 
#define L2C_DCB_D3 0  /* 6:0   */
#define L2C_DCB_D3_MASK (0x7F << 0) 
#define L2C_DCB_D2 7  /* 13:7   */
#define L2C_DCB_D2_MASK (0x7F << 7) 
#define L2C_DCB_D1 14  /* 20:14   */
#define L2C_DCB_D1_MASK (0x7F << 14) 
#define L2C_DCB_D0 21  /* 27:21   */
#define L2C_DCB_D0_MASK (0x7F << 21) 

/* Scrubber regsters */
#define L2C_SCRUB_INDEX 16  /* ..:16 */
#define L2C_SCRUB_INDEX_MASK (0xFFFF << 16) 
#define L2C_SCRUB_WAY 4     /* 5:4   */
#define L2C_SCRUB_WAY_MASK (0x3 << 4) 
#define L2C_SCRUB_PEN (1 << 1) 
#define L2C_SCRUB_EN (1 << 0) 
#define L2C_SCRUB_DELAY 0   /* 16:0  */
#define L2C_SCRUB_DELAY_MASK (0xFFFF << 0) 

/* Error-inject regster */
#define L2C_ERR_INJECT_ADDR 2  /* ..:2 */
#define L2C_ERR_INJECT_ADDR_MASK (0xFFFFFFFC) 
#define L2C_ERR_INJECT_PEN (1 << 0) 

/* MTR regsters */
#define L2C_MTR_ADDR 18     /* 31:18  */
#define L2C_MTR_ADDR_MASK (0x3FFF << 18) 
#define L2C_MTR_ACC 16      /* 17:16  */ /* 00: uncached, 01: write-through */
#define L2C_MTR_ACC_MASK (0x3 << 16) 
#define L2C_MTR_MASK 2      /* 15:2   */
#define L2C_MTR_MASK_MASK (0x3FFF << 2) 
#define L2C_MTR_WP (1 << 1) 
#define L2C_MTR_EN (1 << 0) 

struct l2cregs {
  volatile unsigned int ctrl;
  volatile unsigned int status;
  volatile unsigned int flusha;
  volatile unsigned int flushd;
  volatile unsigned int acount;
  volatile unsigned int hcount;
  volatile unsigned int ccount;
  volatile unsigned int ucount;
  volatile unsigned int error;
  volatile unsigned int err_addr;
  volatile unsigned int tcb;
  volatile unsigned int dcb;
  volatile unsigned int scrub_ctrl;
  volatile unsigned int scrub_delay;
  volatile unsigned int err_inject;
  volatile unsigned int tmp[17];
  volatile unsigned int mtr[32];
};

struct lookup_res {
  int valid;
  int dirty;
  int tag_addr;
  int data_addr;
  int way;
  int lru;
};

/* L2C Enable / Disable ********************************************************** */
  int l2c_enable(struct l2cregs *l2c);
  int l2c_disable(struct l2cregs *l2c);
/* ******************************************************************************* */

/* L2C EDAC Enable / Disable ***************************************************** */
  int l2c_edac_enable(struct l2cregs *l2c);
  int l2c_edac_disable(struct l2cregs *l2c);
/* ******************************************************************************* */

/* L2C HPROT Enable / Disable **************************************************** */
  void l2c_hprot_enable(struct l2cregs *l2c);
  void l2c_hprot_disable(struct l2cregs *l2c);
/* ******************************************************************************* */

/* L2C write-through Enable / Disable ******************************************** */
  void l2c_write_through_enable(struct l2cregs *l2c);
  void l2c_write_through_disable(struct l2cregs *l2c);
/* ******************************************************************************* */

/* L2C Status ******************************************************************** */
  int l2c_get_waysize( struct l2cregs *l2c);
  int l2c_get_ways( struct l2cregs *l2c);
  int l2c_get_linesize( struct l2cregs *l2c);
/* ******************************************************************************* */

/* L2C Flush ********************************************************************* */
  void l2c_invalidate_all(int disable, struct l2cregs *l2c);
  void l2c_write_back_all(int disable, struct l2cregs *l2c);
  void l2c_flush_all(int disable, struct l2cregs *l2c);
  void l2c_invalidate_addr(unsigned int addr, struct l2cregs *l2c);
  void l2c_write_back_addr(unsigned int addr, struct l2cregs *l2c);
  void l2c_flush_addr(unsigned int addr, struct l2cregs *l2c);
  void l2c_invalidate_line(unsigned int index, unsigned int way, struct l2cregs *l2c);
  void l2c_write_back_line(unsigned int index, unsigned int way, struct l2cregs *l2c);
  void l2c_flush_line(unsigned int index, unsigned int way, struct l2cregs *l2c);
  void l2c_invalidate_way(unsigned int tag, unsigned int way, int fetch, int disable, struct l2cregs *l2c);
  void l2c_write_back_way(unsigned int tag, unsigned int way, int fetch, int disable, struct l2cregs *l2c);
  void l2c_flush_way(unsigned int tag, unsigned int way, int fetch, int disable, struct l2cregs *l2c);
/* ******************************************************************************* */

/* L2C Lock ********************************************************************** */
  int l2c_lock(unsigned int addr, int fetch, struct l2cregs *l2c);
  int l2c_unlock(struct l2cregs *l2c);
  int l2c_unlock_flush(struct l2cregs *l2c);
/* ******************************************************************************* */

/* L2C MTRR ********************************************************************** */
  int l2c_mtrr_add_uncached(unsigned int addr, unsigned short mask, struct l2cregs *l2c);
  int l2c_mtrr_add_writethrough(unsigned int addr, unsigned short mask, struct l2cregs *l2c);
  int l2c_mtrr_add_writeprotect(unsigned int addr, unsigned short mask, struct l2cregs *l2c);
  int l2c_mtrr_del(unsigned int addr, unsigned short mask, struct l2cregs *l2c);
/* ******************************************************************************* */

/* L2C Scrub ********************************************************************* */
  void l2c_scrub_start(unsigned short delay, struct l2cregs *l2c);
  void l2c_scrub_stop(struct l2cregs *l2c);
  void l2c_scrub_line(unsigned int index, unsigned int way, struct l2cregs *l2c);
/* ******************************************************************************* */

/* L2C Error ********************************************************************* */
  void l2c_error_inject_clear(struct l2cregs *l2c);
  int l2c_error_reset(struct l2cregs *l2c);
  void l2c_error_inject_tag_rep(int tcb, struct l2cregs *l2c);
  void l2c_error_inject_data_write(int dcb, struct l2cregs *l2c);
  void l2c_error_inject_data(unsigned int addr, int dcb, struct l2cregs *l2c);
  void l2c_error_irq_enable(int mask, struct l2cregs *l2c);
  void l2c_error_irq_disable(int mask, struct l2cregs *l2c);
/* ******************************************************************************* */

/* L2C Diagnostic **************************************************************** */
  unsigned int log2int(unsigned int v);
  unsigned int l2c_diag_get_tag(unsigned int tag, int waysize);
  unsigned int l2c_diag_get_index(unsigned int addr, int waysize, int linesize);
  unsigned int l2c_diag_get_offset(unsigned int tag, int linesize);
  unsigned int l2c_diag_get_valid(unsigned int tag);
  unsigned int l2c_diag_get_dirty(unsigned int tag);
  unsigned int l2c_diag_get_lru(unsigned int tag);
  struct lookup_res l2c_lookup(unsigned int addr, int waysize, int linesize, struct l2cregs *l2c);
/* ******************************************************************************* */

