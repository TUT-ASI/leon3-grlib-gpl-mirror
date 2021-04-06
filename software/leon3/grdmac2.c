// GRDMAC2 descriptor structure (Data or AES)
  struct d_desc {
    volatile unsigned int control;
    volatile unsigned int next_desc;
    volatile unsigned int dest_address;
    volatile unsigned int src_address;
    volatile unsigned int status;         
  };

// GRDMAC2 descriptor structure (ACC Update)
  struct acc_desc {
    volatile unsigned int control;
    volatile unsigned int next_desc;
    volatile unsigned int src_address;
    volatile unsigned int status;         
  };

// GRDMAC2 register structure
  struct grdmac2_register {
    volatile unsigned int control;          /* 0x00 */
    volatile unsigned int status;           /* 0x04 */
    volatile unsigned int empty;            /* 0x08 */
    volatile unsigned int capability;       /* 0x0C */
    volatile unsigned int fdesc;            /* 0x10 */
    volatile unsigned int desc_ctrl;        /* 0x14 */
    volatile unsigned int desc_next;        /* 0x18 */
    volatile unsigned int desc_fnext;       /* 0x1C */
    volatile unsigned int poll_src;         /* 0x20 */
    volatile unsigned int desc_sts;         /* 0x24 */
    volatile unsigned int expd_data;        /* 0x28 */
    volatile unsigned int cond_mask;        /* 0x2C */
    volatile unsigned int curr_desc;        /* 0x30 */
  };

// en_acc = 1 if acc enabled in hardware, otherwise en_acc = 0
grdmac2_test(int paddr, int en_acc) {

  report_device(0x010c0000);

  struct grdmac2_register *grdmac2_reg = (struct grdmac2_register *) (paddr);
  struct d_desc *ddesc_reg = (struct d_desc *) (0x400FFE90); /* Data/AES descriptor */
  struct acc_desc *adesc_reg1 = (struct acc_desc *) (0x400FFEA4); /* IV descriptor */
  struct acc_desc *adesc_reg2 = (struct acc_desc *) (0x400FFEB4); /* KEY descriptor */

  volatile long int txbuf[512];
  volatile long int rxbuf[512];

  volatile int *memorytx;
  volatile int *memoryrx;

  long int memorytxbase;
  long int memoryrxbase;
  memorytxbase = (long int)&txbuf[0];
  memoryrxbase = (long int)&rxbuf[0];

  // search for 1k boundary within allocated memory, store as base
  memorytxbase = memorytxbase & 0xFFFFFC00;
  memorytxbase = memorytxbase + 0x400;

  // search for 1k boundary within allocated memory, store as base
  memoryrxbase = memoryrxbase & 0xFFFFFC00;
  memoryrxbase = memoryrxbase + 0x400;

  memorytx = (int*)memorytxbase;
  // IV
  *memorytx = 0xF0F1F2F3;
  memorytx++;
  *memorytx = 0xF4F5F6F7;
  memorytx++;
  *memorytx = 0xF8F9FAFB;
  memorytx++;
  *memorytx = 0xFCFDFEFF;
  memorytx++;
  // KEY
  *memorytx = 0x603deb10;
  memorytx++;
  *memorytx = 0x15ca71be;
  memorytx++;
  *memorytx = 0x2b73aef0;
  memorytx++;
  *memorytx = 0x857d7781;
  memorytx++;
  *memorytx = 0x1f352c07;
  memorytx++;
  *memorytx = 0x3b6108d7;
  memorytx++;
  *memorytx = 0x2d9810a3;
  memorytx++;
  *memorytx = 0x0914dff4;
  memorytx++;
  // PLAINTEXT
  *memorytx = 0x6bc1bee2;
  memorytx++;
  *memorytx = 0x2e409f96;
  memorytx++;
  *memorytx = 0xe93d7e11;
  memorytx++;
  *memorytx = 0x7393172a;
  memorytx++;
  *memorytx = 0xae2d8a57;
  memorytx++;
  *memorytx = 0x1e03ac9c;
  memorytx++;
  *memorytx = 0x9eb76fac;
  memorytx++;
  *memorytx = 0x45af8e51;
  memorytx++;

if (en_acc != 0) {

  report_subtest(1);
// Setup descriptor queue for updating IV and KEY and encrypting 4 bytes
// Descriptor type 5, length 16 bytes
  adesc_reg1->control = 0x0000200B;
  adesc_reg1->next_desc = 0x400FFEB4;
  adesc_reg1->src_address = memorytxbase;
  adesc_reg1->status = 0x00000000;
// Descriptor type 5, length 32 bytes
  adesc_reg2->control = 0x0000400B;
  adesc_reg2->next_desc = 0x400FFE90;
  adesc_reg2->src_address = memorytxbase+0x10;
  adesc_reg2->status = 0x00000000;
// Descriptor type 4, length 4 bytes
  ddesc_reg->control = 0x00002009;
  ddesc_reg->next_desc = 0x00000001;
  ddesc_reg->dest_address = memoryrxbase;
  ddesc_reg->src_address = memorytxbase+0x30;
  ddesc_reg->status = 0x00000000;

// Setup GRDMAC2
  grdmac2_reg->status = 0x00000000;
  grdmac2_reg->empty = 0x00000000;
  grdmac2_reg->capability = 0x00000000;
  grdmac2_reg->fdesc = 0x400FFEA4;
// Start GRDMAC2
  grdmac2_reg->control = 0x00000001;
// Wait until finished with descriptor queue
  while ((grdmac2_reg->status) != 0x00000001) ;

// Check if encrypted data is correct
  memoryrx = (int*)memoryrxbase;
  if (*memoryrx != 0x601ec313) fail(0);
  memoryrx++;

  report_subtest(2);
// Setup single descriptor for encrypting 16 bytes
// Descriptor type 4, length 16 bytes
  ddesc_reg->control = 0x00008009;
  ddesc_reg->next_desc = 0x00000001;
  ddesc_reg->dest_address = memoryrxbase;
  ddesc_reg->src_address = memorytxbase+0x30;
  ddesc_reg->status = 0x00000000;

// Restart GRDMAC2
  grdmac2_reg->control = 0x00000008;
// Setup GRDMAC2
  grdmac2_reg->status = 0x00000000;
  grdmac2_reg->empty = 0x00000000;
  grdmac2_reg->capability = 0x00000000;
  grdmac2_reg->fdesc = 0x400FFE90;
// Start GRDMAC2
  grdmac2_reg->control = 0x00000001;
// Wait until finished with descriptor queue
  while ((grdmac2_reg->status) != 0x00000001) ;

// Check if encrypted data is correct
  memoryrx = (int*)memoryrxbase;
  if (*memoryrx != 0x601ec313) fail(0);
  memoryrx++;
  if (*memoryrx != 0x775789a5) fail(1);
  memoryrx++;
  if (*memoryrx != 0xb7a7f504) fail(2);
  memoryrx++;
  if (*memoryrx != 0xbbf3d228) fail(3);
  memoryrx++;

  report_subtest(3);
// Setup single descriptor for encrypting 32 bytes
// Descriptor type 4, length 32 bytes
  ddesc_reg->control = 0x00010009;
  ddesc_reg->next_desc = 0x00000001;
  ddesc_reg->dest_address = memoryrxbase;
  ddesc_reg->src_address = memorytxbase+0x30;
  ddesc_reg->status = 0x00000000;

// Restart GRDMAC2
  grdmac2_reg->control = 0x00000008;
// Setup GRDMAC2
  grdmac2_reg->status = 0x00000000;
  grdmac2_reg->empty = 0x00000000;
  grdmac2_reg->capability = 0x00000000;
  grdmac2_reg->fdesc = 0x400FFEA4;
// Start GRDMAC2
  grdmac2_reg->control = 0x00000001;
// Wait until finished with descriptor queue
  while ((grdmac2_reg->status) != 0x00000001) ;

// Check if encrypted data is correct
  memoryrx = (int*)memoryrxbase;
  if (*memoryrx != 0x601ec313) fail(0);
  memoryrx++;
  if (*memoryrx != 0x775789a5) fail(1);
  memoryrx++;
  if (*memoryrx != 0xb7a7f504) fail(2);
  memoryrx++;
  if (*memoryrx != 0xbbf3d228) fail(3);
  memoryrx++;
  if (*memoryrx != 0xf443e3ca) fail(4);
  memoryrx++;
  if (*memoryrx != 0x4d62b59a) fail(5);
  memoryrx++;
  if (*memoryrx != 0xca84e990) fail(6);
  memoryrx++;
  if (*memoryrx != 0xcacaf5c5) fail(7);
  memoryrx++;
}

  report_subtest(4);
// Setup single descriptor for transferring 4 bytes
// Descriptor type 0, length 4 bytes
  ddesc_reg->control = 0x00002001;
  ddesc_reg->next_desc = 0x00000001;
  ddesc_reg->dest_address = memoryrxbase;
  ddesc_reg->src_address = memorytxbase;
  ddesc_reg->status = 0x00000000;

// Restart GRDMAC2
  grdmac2_reg->control = 0x00000008;
// Setup GRDMAC2
  grdmac2_reg->status = 0x00000000;
  grdmac2_reg->empty = 0x00000000;
  grdmac2_reg->capability = 0x00000000;
  grdmac2_reg->fdesc = 0x400FFE90;
// Start GRDMAC2
  grdmac2_reg->control = 0x00000001;
// Wait until finished with descriptor queue
  while ((grdmac2_reg->status) != 0x00000001) ;

// Check that stored data is same as transferred
  memoryrx = (int*)memoryrxbase;
  if (*memoryrx != 0xF0F1F2F3) fail(0);
  memoryrx++;

  report_subtest(5);
// Setup single descriptor for transferring 16 bytes
// Descriptor type 0, length 16 bytes
  ddesc_reg->control = 0x00008001;
  ddesc_reg->next_desc = 0x00000001;
  ddesc_reg->dest_address = memoryrxbase;
  ddesc_reg->src_address = memorytxbase;
  ddesc_reg->status = 0x00000000;

// Restart GRDMAC2
  grdmac2_reg->control = 0x00000008;
// Setup GRDMAC2
  grdmac2_reg->status = 0x00000000;
  grdmac2_reg->empty = 0x00000000;
  grdmac2_reg->capability = 0x00000000;
  grdmac2_reg->fdesc = 0x400FFE90;
// Start GRDMAC2
  grdmac2_reg->control = 0x00000001;
// Wait until finished with descriptor queue
  while ((grdmac2_reg->status) != 0x00000001) ;

// Check that stored data is same as transferred
  memoryrx = (int*)memoryrxbase;
  if (*memoryrx != 0xF0F1F2F3) fail(0);
  memoryrx++;
  if (*memoryrx != 0xF4F5F6F7) fail(1);
  memoryrx++;
  if (*memoryrx != 0xF8F9FAFB) fail(2);
  memoryrx++;
  if (*memoryrx != 0xFCFDFEFF) fail(3);
  memoryrx++;

  report_subtest(6);
// Setup single descriptor for transferring 32 bytes
// Descriptor type 0, length 32 bytes
  ddesc_reg->control = 0x00010001;
  ddesc_reg->next_desc = 0x00000001;
  ddesc_reg->dest_address = memoryrxbase;
  ddesc_reg->src_address = memorytxbase;
  ddesc_reg->status = 0x00000000;

// Restart GRDMAC2
  grdmac2_reg->control = 0x00000008;
// Setup GRDMAC2
  grdmac2_reg->status = 0x00000000;
  grdmac2_reg->empty = 0x00000000;
  grdmac2_reg->capability = 0x00000000;
  grdmac2_reg->fdesc = 0x400FFE90;
// Start GRDMAC2
  grdmac2_reg->control = 0x00000001;
// Wait until finished with descriptor queue
  while ((grdmac2_reg->status) != 0x00000001) ;

// Check that stored data is same as transferred
  memoryrx = (int*)memoryrxbase;
  if (*memoryrx != 0xF0F1F2F3) fail(0);
  memoryrx++;
  if (*memoryrx != 0xF4F5F6F7) fail(1);
  memoryrx++;
  if (*memoryrx != 0xF8F9FAFB) fail(2);
  memoryrx++;
  if (*memoryrx != 0xFCFDFEFF) fail(3);
  memoryrx++;
  if (*memoryrx != 0x603deb10) fail(4);
  memoryrx++;
  if (*memoryrx != 0x15ca71be) fail(5);
  memoryrx++;
  if (*memoryrx != 0x2b73aef0) fail(6);
  memoryrx++;
  if (*memoryrx != 0x857d7781) fail(7);
  memoryrx++;

}
