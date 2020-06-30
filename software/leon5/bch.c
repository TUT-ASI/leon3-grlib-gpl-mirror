/* Copyright Gaisler Research, all rights reserved */

static int
cbxor (int d)
{

    int i = 16;

    while (i)
      {
	  d ^= (d >> i);
	  i >>= 1;
      }
    return (d & 1);
}

static int cbval[7] = {
    0xb42e4bd1, 0x15571557, 0xa699a699, 0x38e338e3,
    0xc0fcc0fc, 0xff00ff00, 0xff0000ff
};


int
cbgen (int d)			/* return 7 BCH checkbits for 32-bit data */
{
    int i = 16;
    int cbinv = 0x0c;
    int cb = 0;

    for (i = 0; i < 7; i++)
      {
	  cb |= (cbxor (d & cbval[i]) << i);
      }
    cb ^= cbinv;
    return (cb);
}
