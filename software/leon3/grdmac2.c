#include <string.h>
#include <report.h>
#include "grdmac2.h"

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

#define STS_ST          (0x1fU  << 27) /* GRDMAC2 state */
#define STS_FP          (0x3ffU << 17) /* FIFO offset of error */
#define STS_FE          (1U     << 16)
#define STS_NPE         (1U     << 15)
#define STS_WDE         (1U     << 14)
#define STS_RDE         (1U     << 13)
#define STS_TO          (1U     << 12)
#define STS_WBE         (1U     << 11)
#define STS_TRE         (1U     << 10)
#define STS_PE          (1U     <<  9)
#define STS_RE          (1U     <<  8)
#define STS_DE          (1U     <<  7)
#define STS_KP          (1U     <<  6)
#define STS_RSP         (1U     <<  5)
#define STS_IF          (1U     <<  4)
#define STS_PAU         (1U     <<  3)
#define STS_ONG         (1U     <<  2)
#define STS_ERR         (1U     <<  1)
#define STS_CMP         (1U     <<  0)

/* These can be combined into a bit mask. */
#define CAP_AES256  0x01  /* encryption accelerator */
#define CAP_SHA256  0x02  /* authentication accelerator */

static struct {
  struct d_desc   ddesc1; /* Data/AES/SHA descriptor */
  struct acc_desc adesc1; /* IV descriptor */
  struct acc_desc adesc2; /* KEY descriptor */
  unsigned int rxbuf[512];
} priv;


static unsigned char aes_iv[] = {
  0xF0, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7,
  0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE, 0xFF,
};

static unsigned char aes_key[] = {
  0x60, 0x3d, 0xeb, 0x10, 0x15, 0xca, 0x71, 0xbe,
  0x2b, 0x73, 0xae, 0xf0, 0x85, 0x7d, 0x77, 0x81,
  0x1f, 0x35, 0x2c, 0x07, 0x3b, 0x61, 0x08, 0xd7,
  0x2d, 0x98, 0x10, 0xa3, 0x09, 0x14, 0xdf, 0xf4,
};

static unsigned char aes_plaintext[] = {
  0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96,
  0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,

  0xae, 0x2d, 0x8a, 0x57, 0x1e, 0x03, 0xac, 0x9c,
  0x9e, 0xb7, 0x6f, 0xac, 0x45, 0xaf, 0x8e, 0x51,
};

static unsigned char aes_ciphertext[] = {
  0x60, 0x1e, 0xc3, 0x13, 0x77, 0x57, 0x89, 0xa5,
  0xb7, 0xa7, 0xf5, 0x04, 0xbb, 0xf3, 0xd2, 0x28,

  0xf4, 0x43, 0xe3, 0xca, 0x4d, 0x62, 0xb5, 0x9a,
  0xca, 0x84, 0xe9, 0x90, 0xca, 0xca, 0xf5, 0xc5,
};

static unsigned char hash4[] = {
  0x5A, 0x73, 0x33, 0x18, 0xFC, 0x52, 0x9E, 0x7B,
  0x4B, 0xC7, 0xF8, 0x59, 0x79, 0x66, 0xA3, 0x36,
  0x5E, 0x9F, 0x8C, 0x63, 0x21, 0xAF, 0x93, 0xA3,
  0x7A, 0x62, 0x1D, 0x70, 0x64, 0x65, 0x64, 0xE6,
};

static unsigned char hash16[] = {
  0xA0, 0x63, 0xDF, 0x83, 0xA8, 0xC2, 0x8A, 0x49,
  0xDA, 0xF4, 0xAE, 0xBA, 0x0E, 0x29, 0xEE, 0x7B,
  0x21, 0x77, 0xE8, 0x51, 0x10, 0x72, 0x94, 0x4C,
  0x3D, 0x29, 0x9C, 0xF7, 0x7D, 0xC8, 0x3E, 0x7A,
};

static unsigned char hash32[] = {
  0xB9, 0xA9, 0xC6, 0x36, 0xA2, 0x55, 0x3A, 0xD6,
  0xA8, 0x26, 0xBE, 0x94, 0x75, 0x5D, 0xC5, 0x5A,
  0xA7, 0x01, 0x3C, 0x9F, 0xB2, 0x3A, 0xBD, 0xC0,
  0xB6, 0x14, 0x99, 0xCE, 0x32, 0xDD, 0x6F, 0xD5,
};


int grdmac2_test(void *paddr) {
  int en_acc;
  int diff;

  struct grdmac2_register *grdmac2_reg = (struct grdmac2_register *) paddr;
  struct d_desc   *ddesc_reg           = &priv.ddesc1; /* Data/AES/SHA descriptor */
  struct acc_desc *adesc_reg1          = &priv.adesc1; /* IV descriptor */
  struct acc_desc *adesc_reg2          = &priv.adesc2; /* KEY descriptor */

  report_device(0x010c0000);
  en_acc = (grdmac2_reg->capability & 0x1f000) >> 12;

  if (en_acc & CAP_AES256) {
    report_subtest(1);
    // Setup descriptor queue for updating IV and KEY and encrypting 4 bytes
    // Descriptor type 5, length 16 bytes
    adesc_reg1->control = 16<<9 | 5<<1 | 1<<0;
    adesc_reg1->next_desc = (unsigned int) adesc_reg2;
    adesc_reg1->src_address = (unsigned int) &aes_iv[0];
    adesc_reg1->status = 0x00000000;
    // Descriptor type 5, length 32 bytes
    adesc_reg2->control = 32<<9 | 5<<1 | 1<<0;
    adesc_reg2->next_desc = (unsigned int) ddesc_reg;
    adesc_reg2->src_address = (unsigned int) &aes_key[0];
    adesc_reg2->status = 0x00000000;
    // Descriptor type 4, length 4 bytes
    ddesc_reg->control = 4<<11 | 4<<1 | 1<<0;
    ddesc_reg->next_desc = 0x00000001;
    ddesc_reg->dest_address = (unsigned int) priv.rxbuf;
    ddesc_reg->src_address = (unsigned int) &aes_plaintext[0];
    ddesc_reg->status = 0x00000000;

    // Setup GRDMAC2
    grdmac2_reg->status = 0xffffffff;
    grdmac2_reg->empty = 0x00000000;
    grdmac2_reg->fdesc = (unsigned int) adesc_reg1;
    // Start GRDMAC2
    grdmac2_reg->control = 0x00000001;
    // Wait until finished with descriptor queue
    while ((grdmac2_reg->status & STS_CMP) == 0) ;

    // Check if encrypted data is correct
    diff = memcmp(priv.rxbuf, &aes_ciphertext[0], 4);
    if (diff != 0) {
      fail(0);
    }

    report_subtest(2);
    // Setup single descriptor for encrypting 16 bytes
    // Descriptor type 4, length 16 bytes
    ddesc_reg->control = 16<<11 | 4<<1 | 1<<0;
    ddesc_reg->next_desc = 0x00000001;
    ddesc_reg->dest_address = (unsigned int) priv.rxbuf;
    ddesc_reg->src_address = (unsigned int) &aes_plaintext[0];
    ddesc_reg->status = 0x00000000;

    // Restart GRDMAC2
    grdmac2_reg->control = 0x00000008;
    // Setup GRDMAC2
    grdmac2_reg->empty = 0x00000000;
    grdmac2_reg->fdesc = (unsigned int) ddesc_reg;
    // Start GRDMAC2
    grdmac2_reg->control = 0x00000001;
    // Wait until finished with descriptor queue
    while ((grdmac2_reg->status & STS_CMP) == 0) ;

    // Check if encrypted data is correct
    diff = memcmp(priv.rxbuf, &aes_ciphertext[0], 16);
    if (diff != 0) {
      fail(diff);
    }

    report_subtest(3);
    // Setup single descriptor for encrypting 32 bytes
    // Descriptor type 4, length 32 bytes
    ddesc_reg->control = 32<<11 | 4<<1 | 1<<0;
    ddesc_reg->next_desc = 0x00000001;
    ddesc_reg->dest_address = (unsigned int) priv.rxbuf;
    ddesc_reg->src_address = (unsigned int) &aes_plaintext[0];
    ddesc_reg->status = 0x00000000;

    // Restart GRDMAC2
    grdmac2_reg->control = 0x00000008;
    // Setup GRDMAC2
    grdmac2_reg->empty = 0x00000000;
    grdmac2_reg->fdesc = (unsigned int) adesc_reg1;
    // Start GRDMAC2
    grdmac2_reg->control = 0x00000001;
    // Wait until finished with descriptor queue
    while ((grdmac2_reg->status & STS_CMP) == 0) ;

    // Check if encrypted data is correct
    diff = memcmp(priv.rxbuf, &aes_ciphertext[0], 32);
    if (diff != 0) {
      fail(diff);
    }
  }

  if (en_acc & CAP_SHA256) {
    report_subtest(7);
    // Setup single descriptor for calculating hash of 4 bytes
    // Descriptor type 6, length 4 bytes
    ddesc_reg->control = 4<<11 | 6<<1 | 1<<0;
    ddesc_reg->next_desc = 0x00000001;
    ddesc_reg->dest_address = (unsigned int) priv.rxbuf;
    ddesc_reg->src_address = (unsigned int) &aes_plaintext[0];
    ddesc_reg->status = 0x00000000;

    // Restart GRDMAC2
    grdmac2_reg->control = 0x00000008;
    // Setup GRDMAC2
    grdmac2_reg->empty = 0x00000000;
    grdmac2_reg->fdesc = (unsigned int) ddesc_reg;
    // Start GRDMAC2
    grdmac2_reg->control = 0x00000001;
    // Wait until finished with descriptor queue
    while ((grdmac2_reg->status & STS_CMP) == 0) ;

    // Check that hash is correct
    diff = memcmp(priv.rxbuf, &hash4[0], sizeof hash4);
    if (diff != 0) {
      fail(diff);
    }


    report_subtest(8);
    // Setup single descriptor for calculating hash of 16 bytes
    // Descriptor type 6, length 16 bytes
    ddesc_reg->control = 16<<11 | 6<<1 | 1<<0;
    ddesc_reg->next_desc = 0x00000001;
    ddesc_reg->dest_address = (unsigned int) priv.rxbuf;
    ddesc_reg->src_address = (unsigned int) &aes_plaintext[0];
    ddesc_reg->status = 0x00000000;

    // Restart GRDMAC2
    grdmac2_reg->control = 0x00000008;
    // Setup GRDMAC2
    grdmac2_reg->empty = 0x00000000;
    grdmac2_reg->fdesc = (unsigned int) ddesc_reg;
    // Start GRDMAC2
    grdmac2_reg->control = 0x00000001;
    // Wait until finished with descriptor queue
    while ((grdmac2_reg->status & STS_CMP) == 0) ;

    // Check that hash is correct
    diff = memcmp(priv.rxbuf, &hash16[0], sizeof hash16);
    if (diff != 0) {
      fail(diff);
    }


    report_subtest(9);
    // Setup single descriptor for calculating hash of 32 bytes
    // Descriptor type 6, length 32 bytes
    ddesc_reg->control = 32<<11 | 6<<1 | 1<<0;
    ddesc_reg->next_desc = 0x00000001;
    ddesc_reg->dest_address = (unsigned int) priv.rxbuf;
    ddesc_reg->src_address = (unsigned int) &aes_plaintext[0];
    ddesc_reg->status = 0x00000000;

    // Restart GRDMAC2
    grdmac2_reg->control = 0x00000008;
    // Setup GRDMAC2
    grdmac2_reg->empty = 0x00000000;
    grdmac2_reg->fdesc = (unsigned int) ddesc_reg;
    // Start GRDMAC2
    grdmac2_reg->control = 0x00000001;
    // Wait until finished with descriptor queue
    while ((grdmac2_reg->status & STS_CMP) == 0) ;

    // Check that hash is correct
    diff = memcmp(priv.rxbuf, &hash32[0], sizeof hash32);
    if (diff != 0) {
      fail(diff);
    }
  }


  report_subtest(4);
  // Setup single descriptor for transferring 4 bytes
  // Descriptor type 0, length 4 bytes
  ddesc_reg->control = 4<<11 | 0<<1 | 1<<0;
  ddesc_reg->next_desc = 0x00000001;
  ddesc_reg->dest_address = (unsigned int) priv.rxbuf;
  ddesc_reg->src_address = (unsigned int) &aes_iv[0];
  ddesc_reg->status = 0x00000000;

  // Restart GRDMAC2
  grdmac2_reg->control = 0x00000008;
  // Setup GRDMAC2
  grdmac2_reg->empty = 0x00000000;
  grdmac2_reg->fdesc = (unsigned int) ddesc_reg;
  // Start GRDMAC2
  grdmac2_reg->control = 0x00000001;
  // Wait until finished with descriptor queue
  while ((grdmac2_reg->status & STS_CMP) == 0) ;

  // Check that stored data is same as transferred
  diff = memcmp(priv.rxbuf, &aes_iv[0], 4);
  if (diff != 0) {
    fail(diff);
  }


  report_subtest(5);
  // Setup single descriptor for transferring 16 bytes
  // Descriptor type 0, length 16 bytes
  ddesc_reg->control = 16<<11 | 0<<1 | 1<<0;
  ddesc_reg->next_desc = 0x00000001;
  ddesc_reg->dest_address = (unsigned int) priv.rxbuf;
  ddesc_reg->src_address = (unsigned int) &aes_key[0];
  ddesc_reg->status = 0x00000000;

  // Restart GRDMAC2
  grdmac2_reg->control = 0x00000008;
  // Setup GRDMAC2
  grdmac2_reg->empty = 0x00000000;
  grdmac2_reg->fdesc = (unsigned int) ddesc_reg;
  // Start GRDMAC2
  grdmac2_reg->control = 0x00000001;
  // Wait until finished with descriptor queue
  while ((grdmac2_reg->status & STS_CMP) == 0) ;

  // Check that stored data is same as transferred
  diff = memcmp(priv.rxbuf, &aes_key[0], 16);
  if (diff != 0) {
    fail(diff);
  }


  report_subtest(6);
  // Setup single descriptor for transferring 32 bytes
  // Descriptor type 0, length 32 bytes
  ddesc_reg->control = 32<<11 | 0<<1 | 1<<0;
  ddesc_reg->next_desc = 0x00000001;
  ddesc_reg->dest_address = (unsigned int) priv.rxbuf;
  ddesc_reg->src_address = (unsigned int) &aes_plaintext[0];
  ddesc_reg->status = 0x00000000;

  // Restart GRDMAC2
  grdmac2_reg->control = 0x00000008;
  // Setup GRDMAC2
  grdmac2_reg->empty = 0x00000000;
  grdmac2_reg->fdesc = (unsigned int) ddesc_reg;
  // Start GRDMAC2
  grdmac2_reg->control = 0x00000001;
  // Wait until finished with descriptor queue
  while ((grdmac2_reg->status & STS_CMP) == 0) ;

  // Check that stored data is same as transferred
  diff = memcmp(priv.rxbuf, &aes_plaintext[0], 32);
  if (diff != 0) {
    fail(diff);
  }

  return 0;
}

