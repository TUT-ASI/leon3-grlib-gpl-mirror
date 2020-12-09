//#define CMDTEST

#define KIND 1

// For exhaustive testing of all combinations of the provided numbers,
// LOOPS needs to be set to the highest number of arguments required
// by an FPU instruction being tested.
// Note that testing time (outside of setup overhead) is k * n^LOOPS.
#define LOOPS 2

// Create a copy of all numbers and negate them.
//#define NEGATE

// Test all rounding modes
//#define ALLRM

// Specific rounding mode to test
#define RM 0

// NaN-box all numbers
#define NANBOX

#define INT2FLOAT
#define FLOAT2INT
#define FLOAT2FLOAT
//#define SQRT
//#define CLASS
#define ADDSUB
//#define MUL
//#define DIV
//#define MINMAX
//#define CMP
//#define SIGN
//#define MULADD

//#define IDIV

//#define SP
#define DP

#include <stdio.h>
#include <inttypes.h>
#include <math.h>

#if !defined(CMDTEST)
# include "util.h"
int __errno;

#define rounding "dyn"

#define SETUP(type,fpr,value)                                               \
  do { asm volatile ("fmv." #type ".x " #fpr ", %0; "                       \
                     :                                                      \
                     : "r" (value)                                          \
                    );                                                      \
  } while (0)
#define F2F(op,type,dfpr,sfpr)                                              \
  do { asm volatile (#op "." #type " " #dfpr ", " #sfpr ", " rounding "; "  \
                     :                                                      \
                     :                                                      \
                     : #dfpr                                                \
                    );                                                      \
  } while (0)
#define F2Fx(op,type1,type2,dfpr,sfpr)                                      \
  do { asm volatile (#op "." #type1 "." #type2 " " #dfpr ", " #sfpr ", " rounding "; "  \
                     :                                                      \
                     :                                                      \
                     : #dfpr                                                \
                    );                                                      \
  } while (0)
#define F2Fxnr(op,type1,type2,dfpr,sfpr)                                    \
  do { asm volatile (#op "." #type1 "." #type2 " " #dfpr ", " #sfpr "; "    \
                     :                                                      \
                     :                                                      \
                     : #dfpr                                                \
                    );                                                      \
  } while (0)
#define FF2F(op,type,dfpr,s1fpr,s2fpr)                                      \
  do { asm volatile (#op "." #type " " #dfpr ", " #s1fpr ", " #s2fpr ", " rounding "; "  \
                     :                                                      \
                     :                                                      \
                     : #dfpr                                                \
                    );                                                      \
  } while (0)
#define FF2Fnr(op,type,dfpr,s1fpr,s2fpr)                                    \
  do { asm volatile (#op "." #type " " #dfpr ", " #s1fpr ", " #s2fpr "; "   \
                     :                                                      \
                     :                                                      \
                     : #dfpr                                                \
                    );                                                      \
  } while (0)
#define FF2Inr(op,type,dgpr,s1fpr,s2fpr)                                    \
  do { asm volatile (#op "." #type " " #dgpr ", " #s1fpr ", " #s2fpr "; "   \
                     :                                                      \
                     :                                                      \
                     : #dgpr                                                \
                    );                                                      \
  } while (0)
#define FFF2F(op,type,dfpr,s1fpr,s2fpr,s3fpr)                               \
  do { asm volatile (#op "." #type " " #dfpr ", " #s1fpr ", " #s2fpr ", " #s3fpr ", " rounding "; "  \
                     :                                                      \
                     :                                                      \
                     : #dfpr                                                \
                    );                                                      \
  } while (0)
#define F2I(op,type,dgpr,sfpr)                                              \
  do { asm volatile (#op "." #type " " #dgpr ", " #sfpr ", " rounding "; "  \
                     :                                                      \
                     :                                                      \
                     : #dgpr                                                \
                    );                                                      \
  } while (0)
#define F2Inr(op,type,dgpr,sfpr)                                            \
  do { asm volatile (#op "." #type " " #dgpr ", " #sfpr "; "                \
                     :                                                      \
                     :                                                      \
                     : #dgpr                                                \
                    );                                                      \
  } while (0)
#define F2Ix(op,itype,ftype,dgpr,sfpr)                                      \
  do { asm volatile (#op "." #itype "." #ftype " " #dgpr ", " #sfpr ", " rounding "; "  \
                     :                                                      \
                     :                                                      \
                     : #dgpr                                                \
                    );                                                      \
  } while (0)
#define I2F(op,ftype,itype,dfpr,value)                                      \
  do { asm volatile (#op "." #ftype "." #itype " " #dfpr ", %0; "           \
                     :                                                      \
                     : "r" (value)                                          \
                     : #dfpr                                                \
                    );                                                      \
  } while (0)
#define VERIFY_F(type,fpr,fgpr,cgpr)                                        \
  do { asm volatile ("csrrw  %1, fflags, x0; "                              \
                     "fmv.x." #type " %0, " #fpr"; "                        \
                     : "=r" (fgpr),                                         \
                       "=r" (cgpr)                                          \
                    );                                                      \
  } while (0)
#define VERIFY_I(type,cgpr)                                                 \
  do { asm volatile ("csrrw  %0, fflags, x0; "                              \
                     : "=r" (cgpr)                                          \
                    );                                                      \
  } while (0)
#define CHECK_F2F(op,type,dfpr,sfpr,fgpr,cgpr)                              \
  do { F2F(op, type, dfpr, sfpr);                                           \
       VERIFY_F(type, dfpr, cgpr, fgpr);                                    \
  } while (0)
#define CHECK_F2Fx(op,type1,type2,dfpr,sfpr,fgpr,cgpr)                      \
  do { F2Fx(op, type1, type2, dfpr, sfpr);                                  \
       VERIFY_F(type1, dfpr, cgpr, fgpr);                                   \
  } while (0)
#define CHECK_F2Fxnr(op,type1,type2,dfpr,sfpr,fgpr,cgpr)                    \
  do { F2Fxnr(op, type1, type2, dfpr, sfpr);                                \
       VERIFY_F(type1, dfpr, cgpr, fgpr);                                   \
  } while (0)
#define CHECK_FF2F(op,type,dfpr,s1fpr,s2fpr,fgpr,cgpr)                      \
  do { FF2F(op, type, dfpr, s1fpr, s2fpr);                                  \
       VERIFY_F(type, dfpr, cgpr, fgpr);                                    \
  } while (0)
#define CHECK_FF2Fnr(op,type,dfpr,s1fpr,s2fpr,fgpr,cgpr)                    \
  do { FF2Fnr(op, type, dfpr, s1fpr, s2fpr);                                \
       VERIFY_F(type, dfpr, cgpr, fgpr);                                    \
  } while (0)
#define CHECK_FF2Inr(op,type,dgpr,s1fpr,s2fpr,cgpr)                         \
    do { FF2Inr(op, type, dgpr, s1fpr, s2fpr);                              \
       VERIFY_I(type, cgpr);                                                \
  } while (0)
#define CHECK_FFF2F(op,type,dfpr,s1fpr,s2fpr,s3fpr,fgpr,cgpr)               \
    do { FFF2F(op, type, dfpr, s1fpr, s2fpr, s3fpr);                        \
       VERIFY_F(type, dfpr, cgpr, fgpr);                                    \
  } while (0)
#define CHECK_F2I(op,type,dgpr,sfpr,cgpr)                                   \
  do { F2I(op, type, dgpr, sfpr);                                           \
       VERIFY_I(type, cgpr);                                                \
  } while (0)
#define CHECK_F2Inr(op,type,dgpr,sfpr,cgpr)                                 \
  do { F2Inr(op, type, dgpr, sfpr);                                         \
       VERIFY_I(type, cgpr);                                                \
  } while (0)
#define CHECK_F2Ix(op,itype,ftype,dgpr,sfpr,cgpr)                           \
  do { F2Ix(op, itype, ftype, dgpr, sfpr);                                  \
       VERIFY_I(type, cgpr);                                                \
  } while (0)
#define CHECK_I2F(op,ftype,itype,dfpr,sgpr,fgpr,cgpr)                       \
  do { I2F(op, ftype, itype, dfpr, sgpr);                                   \
    VERIFY_F(ftype, dfpr, cgpr, fgpr);                                      \
  } while (0)

#endif
//VERIFY(d, f4, t1, t2);

double pow2(int power)
{
#if 0
  return pow(2, power);
#else
  double v = 1;
  int abspower = (power > 0) ? power : -power;
  while (abspower >= 30) {
    v        *= 1 << 30;
    abspower -= 30;
  }
  v *= 1 << abspower;

  if (power < 0) {
    v = 1 / v;
  }

  return v;
#endif
}

const int exps[]    = { 8, 11,  5,  8,  8,  7,  4};
const int fracs[]   = {23, 52, 10,  7, 10, 16,  3};

uint64_t inf2bin(int kind)
{
  int exp_bits  = exps[kind];
  int frac_bits = fracs[kind];
  int exp_max   = (1 << exp_bits) - 1;

  return (uint64_t)exp_max << frac_bits;
}

uint64_t snan2bin(int kind)
{
  return inf2bin(kind) | 1;
}

uint64_t qnan2bin(int kind)
{
  int frac_bits = fracs[kind];

  return snan2bin(kind) | (1LL << (frac_bits - 1));
}

uint64_t zero2bin(int kind)
{
  return 0;
}

uint64_t minsub2bin(int kind)
{
  return zero2bin(kind) | 1;
}

uint64_t maxsub2bin(int kind)
{
  int frac_bits = fracs[kind];

  return zero2bin(kind) | ((1LL << frac_bits) - 1);
}

uint64_t min2bin(int kind)
{
  int      exp_bits  = exps[kind];
  int      frac_bits = fracs[kind];
  int      bits      = 1 + exp_bits + frac_bits;
  int      exp_max   = (1 << exp_bits) - 1;
  uint64_t mant_max  = (1ULL << frac_bits) - 1;
  uint64_t data      = 0;

  return 1LL << frac_bits;
}

uint64_t max2bin(int kind)
{
  int      exp_bits  = exps[kind];
  int      frac_bits = fracs[kind];
  int      exp_max   = (1 << exp_bits) - 1;
  uint64_t mant_max  = (1ULL << frac_bits) - 1;

  return ((exp_max - 1LL) << frac_bits) | mant_max;
}

uint64_t negbin(uint64_t v, int kind)
{
  int exp_bits  = exps[kind];
  int frac_bits = fracs[kind];
  int bits      = 1 + exp_bits + frac_bits;

  return v | (1LL << (bits - 1));
}

uint64_t nanboxbin(uint64_t v, int kind)
{
  int      exp_bits  = exps[kind];
  int      frac_bits = fracs[kind];
  int      bits      = 1 + exp_bits + frac_bits;
  uint64_t mask      = (~0LL << 1) << (bits - 1);

  return v | mask;
}

// Floating point to binary conversion
// kind 0 - 32 bit IEEE754-2008 single precision
//      1 - 64 bit IEEE754-2008 double precision
//      2 - 16 bit IEEE754-2008 half precision
//      3 - bfloat16
//      4 - NVIDIA TensorFloat
//      5 - AMD fp24
//      6 - 8 bit 1/4/3 minifloat
// Does not deal with infinity, NaN and such.
uint64_t float2bin(double f, int kind)
{
  int      exp_bits  = exps[kind];
  int      frac_bits = fracs[kind];
  int      bits      = 1 + exp_bits + frac_bits;
  int      exp_max   = (1 << exp_bits) - 1;
  uint64_t mant_max  = (1ULL << frac_bits) - 1;
  uint64_t sign      = 0;
  uint64_t data      = 0;
  int      exp       = 0;
  int      frac;

  if (f < 0.0) {
    f    = -f;
    sign = 1ULL << (bits - 1);
  }
//  printf("A %f 0x%016llx\n", f, sign);

  // Too large to represent?
  if (f > mant_max * pow2(((exp_max - 1) / 2 - frac_bits))) {
    // +/- Infinity
    return sign | ((1ULL << (bits - 2 - frac_bits)) - 1) << frac_bits;
  } else if (f == 0.0) {
    // +/- 0
    return sign;
  // Too small to represent, even as subnormal?
  } else if (f < pow2((-((exp_max - 1) / 2 + frac_bits)))) {
    // +/- 0
    return sign;
  }

  exp = floor(log2(f));
  f   = f / pow2(exp);
//  printf("B %d %g\n", exp, f);

  // Subnormal?
  if (exp < 1 - (exp_max - 1) / 2) {
    exp  = 1 - (exp_max - 1) / 2;
  } else {
    // Exponent
    data = (uint64_t)(exp + (exp_max - 1) / 2) << frac_bits;
    // Normals have implicit leading 1.
    f   -= 1.0;
  }
//  printf("C %d %g 0x%016llx\n", exp, f, data);

  frac  = trunc(f * pow2(23));
  data |= (uint64_t)frac << (frac_bits - 23);
  f     = f - frac / pow2(23);
//  printf("D %d %g 0x%016llx\n", frac, f, data);
  if (frac_bits > 23) {
    frac  = trunc(f * pow2(frac_bits));
    data |= frac;
  } else {
    f = f * pow2(23);
    if (f > 0.5) {
      data += 1;
    }
  }
//  printf("E %d %g 0x%016llx\n", frac, f, data);

  return sign | data;
}

uint64_t f_0;
uint64_t f_1;
uint64_t f_pi;

#if !defined(CMDTEST)
//void test(uint64_t v1, uint64_t v2)
void test(int kind, uint64_t v1, uint64_t v2, uint64_t v3)
{
  uint64_t csrv, fprv;

#if defined(DP)
  SETUP(d, f1, v1);
  SETUP(d, f2, v2);
  SETUP(d, f3, v3);
#elif defined(SP)
  SETUP(s, f1, v1);
  SETUP(s, f2, v2);
  SETUP(s, f3, v3);
#endif
#if 0
  SETUP(d, f4, f_0);
  SETUP(d, f5, f_1);
  SETUP(d, f6, f_pi);
#endif

#if defined(SQRT)
# if defined(SP)
  CHECK_F2F(fsqrt, s, f20, f1, csrv, fprv);
# endif
# if defined(DP)
  CHECK_F2F(fsqrt, d, f20, f1, csrv, fprv);
# endif
#endif

#if defined(ADDSUB)
# if defined(SP)
  CHECK_FF2F(fadd, s, f21, f1, f2, csrv, fprv);
  CHECK_FF2F(fsub, s, f22, f1, f2, csrv, fprv);
# endif
# if defined(DP)
  CHECK_FF2F(fadd, d, f21, f1, f2, csrv, fprv);
  CHECK_FF2F(fsub, d, f22, f1, f2, csrv, fprv);
# endif
#endif

#if defined(MUL)
# if defined(SP)
  CHECK_FF2F(fmul, s, f23, f1, f2, csrv, fprv);
# endif
# if defined(DP)
  CHECK_FF2F(fmul, d, f23, f1, f2, csrv, fprv);
# endif
#endif

#if defined(DIV)
# if defined(SP)
  CHECK_FF2F(fdiv, s, f24, f5, f1, csrv, fprv);
# endif
# if defined(DP)
  CHECK_FF2F(fdiv, d, f24, f5, f1, csrv, fprv);
# endif
#endif

#if defined(MULADD)
# if defined(SP)
  CHECK_FFF2F(fmadd,  s, f25, f1, f2, f3, csrv, fprv);
  CHECK_FFF2F(fnmadd, s, f26, f1, f2, f3, csrv, fprv);
  CHECK_FFF2F(fmsub,  s, f27, f1, f2, f3, csrv, fprv);
  CHECK_FFF2F(fnmsub, s, f28, f1, f2, f3, csrv, fprv);
# endif
# if defined(DP)
  CHECK_FFF2F(fmadd,  d, f25, f1, f2, f3, csrv, fprv);
  CHECK_FFF2F(fnmadd, d, f26, f1, f2, f3, csrv, fprv);
  CHECK_FFF2F(fmsub,  d, f27, f1, f2, f3, csrv, fprv);
  CHECK_FFF2F(fnmsub, d, f28, f1, f2, f3, csrv, fprv);
# endif
#endif

#if defined(MINMAX)
# if defined(SP)
  CHECK_FF2Fnr(fmin, s, f25, f1, f2, csrv, fprv);
  CHECK_FF2Fnr(fmax, s, f26, f1, f2, csrv, fprv);
# endif
# if defined(DP)
  CHECK_FF2Fnr(fmin, d, f25, f1, f2, csrv, fprv);
  CHECK_FF2Fnr(fmax, d, f26, f1, f2, csrv, fprv);
# endif
#endif

#if defined(CMP)
# if defined(SP)
  CHECK_FF2Inr(feq, s, x21, f1, f2, csrv);
  CHECK_FF2Inr(flt, s, x22, f1, f2, csrv);
  CHECK_FF2Inr(fle, s, x23, f1, f2, csrv);
# endif
# if defined(DP)
  CHECK_FF2Inr(feq, d, x24, f1, f2, csrv);
  CHECK_FF2Inr(flt, d, x25, f1, f2, csrv);
  CHECK_FF2Inr(fle, d, x26, f1, f2, csrv);
# endif
#endif

#if defined(CLASS)
# if defined(SP)
  CHECK_F2Inr(fclass, s, x21, f1, csrv);
# endif
# if defined(DP)
  CHECK_F2Inr(fclass, d, x21, f1, csrv);
# endif
#endif

#if defined(INT2FLOAT)
# if defined(SP)
  CHECK_I2F(fcvt, s,  w, f21, v1, csrv, fprv);
  CHECK_I2F(fcvt, s, wu, f22, v1, csrv, fprv);
  CHECK_I2F(fcvt, s,  l, f23, v1, csrv, fprv);
  CHECK_I2F(fcvt, s, lu, f24, v1, csrv, fprv);
# endif
# if defined(DP)
  CHECK_I2F(fcvt, d,  w, f25, v1, csrv, fprv);
  CHECK_I2F(fcvt, d, wu, f26, v1, csrv, fprv);
  CHECK_I2F(fcvt, d,  l, f27, v1, csrv, fprv);
  CHECK_I2F(fcvt, d, lu, f28, v1, csrv, fprv);
# endif
#endif

#if defined(FLOAT2INT)
# if defined(SP)
  CHECK_F2Ix(fcvt,  w, s, x21, f1, csrv);
  CHECK_F2Ix(fcvt, wu, s, x22, f1, csrv);
  CHECK_F2Ix(fcvt,  l, s, x23, f1, csrv);
  CHECK_F2Ix(fcvt, lu, s, x24, f1, csrv);
# endif
# if defined(DP)
  CHECK_F2Ix(fcvt,  w, d, x25, f1, csrv);
  CHECK_F2Ix(fcvt, wu, d, x26, f1, csrv);
  CHECK_F2Ix(fcvt,  l, d, x27, f1, csrv);
  CHECK_F2Ix(fcvt, lu, d, x28, f1, csrv);
# endif
#endif

#if defined(FLOAT2FLOAT)
# if defined(SP)
  CHECK_F2Fxnr(fcvt, d, s, f29, f1, csrv, fprv);
# endif
# if defined(DP)
  CHECK_F2Fx(fcvt, s, d, f29, f1, csrv, fprv);
# endif
#endif

#if defined(SIGN)
# if defined(SP)
  CHECK_FF2Fnr(fsgnj,  s, f22, f1, f2, csrv, fprv);
  CHECK_FF2Fnr(fsgnjn, s, f23, f1, f2, csrv, fprv);
  CHECK_FF2Fnr(fsgnjx, s, f24, f1, f2, csrv, fprv);
# endif
# if defined(DP)
  CHECK_FF2Fnr(fsgnj,  d, f22, f1, f2, csrv, fprv);
  CHECK_FF2Fnr(fsgnjn, d, f23, f1, f2, csrv, fprv);
  CHECK_FF2Fnr(fsgnjx, d, f24, f1, f2, csrv, fprv);
# endif
#endif

#if defined(IDIV)
  asm volatile ("divu %0, %1, %2; "
                : "=r" (v3)
                : "r" (v1), "r" (v2)
               );
  asm volatile ("remu %0, %1, %2; "
                : "=r" (v3)
                : "r" (v1), "r" (v2)
               );
  asm volatile ("div %0, %1, %2; "
                : "=r" (v3)
                : "r" (v1), "r" (v2)
               );
  asm volatile ("rem %0, %1, %2; "
                : "=r" (v3)
                : "r" (v1), "r" (v2)
               );
# if 1
  asm volatile ("divuw %0, %1, %2; "
                : "=r" (v3)
                : "r" (v1), "r" (v2)
               );
  asm volatile ("remuw %0, %1, %2; "
                : "=r" (v3)
                : "r" (v1), "r" (v2)
               );
  asm volatile ("divw %0, %1, %2; "
                : "=r" (v3)
                : "r" (v1), "r" (v2)
               );
  asm volatile ("remw %0, %1, %2; "
                : "=r" (v3)
                : "r" (v1), "r" (v2)
               );
# endif
#endif
}
#endif

uint64_t setbits(int length, int count, int shift)
{
  if ((length <= 0) || (length > 64))
    return 0;
  if ((count  <= 0) || (count  > length))
    return 0;
  if ((shift  <  0) || (shift  > length - count))
    return 0;

  uint64_t v = 1;
  v = v << (count - 1);
  v = v | (v - 1);

  v = v << (length - count - shift);

  return v;
}

uint64_t split(int length, int step, int count, int shift)
{
  int remain = length;
  uint64_t v = 0;
  while (remain > 0) {
    uint64_t t;
    if (remain >= step)
      t = setbits(step, count, shift) << (remain - step);
    else
      t = setbits(step, count, shift) >> (step - remain);
    v |= t;
    remain -= step;
  }

  return v;
}

#if defined(CMDTEST)
void output(uint64_t v, int length)
{
  char buf[64];
  for(int i = 0; i < length; i++)
    buf[i] = '0' + !!(v & (1ULL << (length - 1 - i)));
  buf[length] = 0;
  printf("%s", buf);
}
#endif

uint64_t *vectors(int length, int step, uint64_t *buf)
{
  for(int i = 1; i <= step; i++) {
    for(int j = 0; j <= step - i; j++) {
#if 0
      uint64_t v = setbits(length, i, j);
#else
      uint64_t v = split(length, step, i, j);
#endif
      *buf++ = v;
    }
  }

  return buf;
}

#if defined(CMDTEST)
void dump(uint64_t *buf, int items, int length)
{
  for(int i = 0; i < items; i++) {
    output(buf[i], length);
    printf("\n");
  }
}
#endif

void tests(int kind, uint64_t *buf, int items)
{
  for(int i = 0; i < items; i++) {
#if LOOPS > 1
    for(int j = 0; j < items; j++)
#else
    int j = i;
#endif
    {
#if LOOPS > 2
      for(int k = 0; k < items; k++)
#else
      int k = j;
#endif
      {
#if !defined(CMDTEST)
        test(kind, buf[i], buf[j], buf[k]);
#else
        printf("%d %d %d\n", i, j, k);
        output(buf[i], 64);
        union {
          uint64_t data;
          double dbl;
          struct {
            float flt;
            uint32_t dummy;
          };
          struct {
            uint32_t low;
            uint32_t high;
          };
        } conv;
        conv.data = buf[i];
        if (kind == 0) {
          printf(" %f %08x %08x\n", conv.flt, conv.low, conv.high);
        } else {
          printf(" %g %08llx\n", conv.dbl, buf[i]);
        }
# if LOOPS > 1
        output(buf[j], 64);
        conv.data = buf[j];
        if (kind == 0) {
          printf(" %f %08x %08x\n", conv.flt, conv.low, conv.high);
        } else {
          printf(" %g %08llx\n", conv.dbl, buf[i]);
        }
# endif
# if LOOPS > 2
        output(buf[k], 64);
        conv.data = buf[k];
        if (kind == 0) {
          printf(" %f %08x %08x\n", conv.flt, conv.low, conv.high);
        } else {
          printf(" %g %08llx\n", conv.dbl, buf[i]);
        }
# endif
#endif
      }
    }
  }
}

uint64_t *copy(uint64_t *buf, int items)
{
  uint64_t *next = buf;

  for(int i = items; i > 0; i--) {
    *next++ = buf[-i];
  }

  return next;
}

void negate(int kind, uint64_t *buf, int items)
{
  for(int i = items; i > 0; i--) {
    buf[-i] = negbin(buf[-i], kind);
  }
}

void nanbox(int kind, uint64_t *buf, int items)
{
  for(int i = items; i > 0; i--) {
    buf[-i] = nanboxbin(buf[-i], kind);
  }
}

uint64_t *normals(int kind, uint64_t *buf)
{
  uint64_t *next = buf;

  *next++ = float2bin(1, kind);
  *next++ = min2bin(kind);
  *next++ = max2bin(kind);

  return next;
}

uint64_t *subnormals(int kind, uint64_t *buf)
{
  uint64_t *next = buf;

  *next++ = minsub2bin(kind);
  *next++ = maxsub2bin(kind);

  return next;
}

uint64_t *specials(int kind, uint64_t *buf)
{
  uint64_t *next = buf;

  *next++ = inf2bin(kind);
  *next++ = qnan2bin(kind);
  *next++ = snan2bin(kind);

  return next;
}

uint64_t *fd2intnums(int kind, uint64_t *buf)
{
  uint64_t *next = buf;

  *next++ = float2bin(0.5,  kind);
  *next++ = float2bin(0.51, kind);
  *next++ = float2bin(0.49, kind);
  *next++ = float2bin(1.5,  kind);
  *next++ = float2bin(1.51, kind);
  *next++ = float2bin(1.49, kind);

#if 1
  if (kind == 0) {
    // Approximate max unsigned 32 bit, with surrounding.
    *next++ = 0x4f7fffffUL;                        // ~ ~0UL
    *next++ = 0x4f7ffffeUL;
    *next++ = 0x4f7ffffdUL;
    *next++ = 0x4f800000UL;
    *next++ = 0x4f800001UL;
    // Approximate max signed 32 bit, with surrounding.
    *next++ = 0x4effffffUL;
    *next++ = 0x4efffffeUL;
    *next++ = 0x4efffffdUL;
    *next++ = 0x4f000000UL;
    *next++ = 0x4f000001UL;
  }
  if (kind == 1) {
    // Max unsigned 32 bit, with surrounding.
    *next++ = float2bin(0xffffffff, kind);
    *next++ = float2bin(0xffffffff + 0.5,  kind);
    *next++ = float2bin(0xffffffff + 0.51, kind);
    *next++ = float2bin(0xffffffff + 0.49, kind);
    *next++ = float2bin(0xffffffff + 1.0,  kind);
    *next++ = float2bin(0xffffffff + 1.5,  kind);
    *next++ = float2bin(0xffffffff + 1.51, kind);
    *next++ = float2bin(0xffffffff + 1.49, kind);
    *next++ = float2bin(0xffffffff - 0.5,  kind);
    *next++ = float2bin(0xffffffff - 0.51, kind);
    *next++ = float2bin(0xffffffff - 0.49, kind);
    *next++ = float2bin(0xffffffff - 1.0,  kind);
    *next++ = float2bin(0xffffffff - 1.5,  kind);
    *next++ = float2bin(0xffffffff - 1.51, kind);
    *next++ = float2bin(0xffffffff - 1.49, kind);
    // Max signed 32 bit, with surrounding.
    *next++ = float2bin(0x7fffffff, kind);
    *next++ = float2bin(0x7fffffff + 0.5,  kind);
    *next++ = float2bin(0x7fffffff + 0.51, kind);
    *next++ = float2bin(0x7fffffff + 0.49, kind);
    *next++ = float2bin(0x7fffffff + 1.0,  kind);
    *next++ = float2bin(0x7fffffff + 1.5,  kind);
    *next++ = float2bin(0x7fffffff + 1.51, kind);
    *next++ = float2bin(0x7fffffff + 1.49, kind);
    *next++ = float2bin(0x7fffffff - 0.5,  kind);
    *next++ = float2bin(0x7fffffff - 0.51, kind);
    *next++ = float2bin(0x7fffffff - 0.49, kind);
    *next++ = float2bin(0x7fffffff - 1.0,  kind);
    *next++ = float2bin(0x7fffffff - 1.5,  kind);
    *next++ = float2bin(0x7fffffff - 1.51, kind);
    *next++ = float2bin(0x7fffffff - 1.49, kind);
    // Approximate max unsigned 64 bit, with surrounding.
    *next++ = 0x43efffffffffffffULL;             // ~0ULL
    *next++ = 0x43effffffffffffeULL;
    *next++ = 0x43effffffffffffdULL;
    *next++ = 0x43f0000000000000ULL;
    *next++ = 0x43f0000000000001ULL;
    // Approximate max signed 64 bit, with surrounding.
    *next++ = 0x43dfffffffffffffULL;
    *next++ = 0x43dffffffffffffeULL;
    *next++ = 0x43dffffffffffffdULL;
    *next++ = 0x43e0000000000000ULL;
    *next++ = 0x43e0000000000001ULL;
  }
#endif

#if 1
  *next++ = float2bin(3e9, kind);
  *next++ = float2bin(5e9, kind);
  *next++ = float2bin(1e18, kind);
  *next++ = float2bin(2e18, kind);
  *next++ = float2bin(0x7fffffff            + 100000000.0, kind);
  *next++ = float2bin(0xffffffff            + 100000000.0, kind);
  *next++ = float2bin(0x7fffffffffffffffULL + 100000000.0, kind);
  *next++ = float2bin(0xffffffffffffffffULL + 100000000.0, kind);
#endif

  return next;
}

uint64_t *denormalmuladdnums(int kind, uint64_t *buf)
{
  uint64_t *next = buf;

#if 1
  if (kind == 0) {
    *next++ = 0xffffffff00000001ULL;
    *next++ = 0xffffffff00000010ULL;
    *next++ = 0xffffffff00000011ULL;
    *next++ = 0xffffffff00000100ULL;
    *next++ = 0xffffffff00000101ULL;
    // The square of this is half the smallest denormal.
    *next++ = float2bin(pow2(-((126 + 23) / 2 + 1)), kind);
  } else {
    // qqq Add double equivalents here later.
    *next++ = 0x0000000000000001ULL;
    *next++ = 0x0000000000000010ULL;
    *next++ = 0x0000000000000011ULL;
    *next++ = 0x0000000000000100ULL;
    *next++ = 0x0000000000000101ULL;
    // The product of these is half the smallest denormal.
    *next++ = float2bin(pow2(-(1022 + 52) / 2), kind);
    *next++ = float2bin(pow2(-((1022 + 52) / 2 + 1)), kind);
  }
  *next++ = float2bin(pow2(-1), kind);
  *next++ = float2bin(pow2(-2), kind);
  *next++ = float2bin(pow2(1), kind);
  *next++ = float2bin(pow2(0), kind);
#endif

#if 0
  *next++ = float2bin(1, kind);
  *next++ = float2bin(10000, kind);
  *next++ = float2bin(10000000, kind);
#endif

#if 0
  *next++ = float2bin(pow2(22), kind);
  *next++ = float2bin(pow2(23), kind);
  *next++ = float2bin(pow2(24), kind);
  *next++ = float2bin(pow2(51), kind);
  *next++ = float2bin(pow2(52), kind);
  *next++ = float2bin(pow2(53), kind);
#endif

  return next;
}

uint32_t seed = 42;

uint32_t myrand()
{
  seed = 1103515245 * seed + 12345;

  return seed;
}

uint64_t myrand64()
{
return ((uint64_t)myrand() << 32) | myrand();
}

void permute(uint64_t *buf, int items)
{
  uint64_t tmp;
  int      pos;

  for(int i = 0; i < items; i++) {
    pos      = myrand() % items;
    tmp      = buf[i];
    buf[i]   = buf[pos];
    buf[pos] = tmp;
  }
}

int main(int argc, char *argv[])
{
  uint64_t buf[16384];
  uint64_t *next = buf;
  uint64_t *tmp, *tmp2;
  int kind = KIND;

  tmp = next;

#if 1
  // 64-bit patterns
# if 1
  next = vectors(64, 64, next);
# endif
# if 1
  next = vectors(64, 32, next);
  next = vectors(64, 16, next);
# endif
# if 1
  next = vectors(64,  8, next);
# endif
# if 1
  next = vectors(64,  4, next);
  next = vectors(64,  2, next);
# endif
#endif

#if 0
  // 64-bit patterns for integer divide
# if 0
  *next++ = 0;
  *next++ = -1;
  *next++ = 1;
  *next++ = 0x8000000000000000ULL;
# endif
# if 1
  *next++ = 3;
  *next++ = 0x8000000000000000ULL;
  *next++ = 0xc000000000000000ULL;
  *next++ = 0xffffffffffffffffULL;
# endif
# if 0
  next = vectors(32, 24, next);
# endif
# if 0  // Done 6min
  next = vectors(32, 16, next);
  for(int i = -7; i <= 7; i++) {
    *next++ = i;
  }
# endif
# if 0
  next = vectors(16, 16, next);
  for(int i = -7; i <= 7; i++) {
    *next++ = i;
  }
# endif
# if 0  // Done 3min
  next = vectors(64,  8, next);
  next = vectors(64,  4, next);
  next = vectors(64,  2, next);
  for(int i = -25; i <= 25; i++) {
    *next++ = i;
  }
# endif
# if 1  // Done 4min
  for(int i = 0; i < 10; i++) {
    *next++ = myrand64();
  }
  for(int i = 0; i < 10; i++) {
    *next++ = myrand64() & 0xffffff;
  }
  for(int i = 0; i < 10; i++) {
    *next++ = myrand64() & 0xff;
  }
  for(int i = 0; i < 10; i++) {
    *next++ = myrand64() << 40;
  }
  for(int i = 0; i < 10; i++) {
    *next++ = myrand64() << 56;
  }
  for(int i = -7; i <= 7; i++) {
    *next++ = i;
  }
# endif
#endif

#if 0
  // 32-bit patterns for integer divide
# if 0
  *next++ = 0;
  *next++ = -1;
  *next++ = 1;
  *next++ = 0x80000000;
# endif
# if 1
  *next++ = 3;
  *next++ = 0x80000000;
  *next++ = 0xc0000000;
  *next++ = 0xffffffff;
# endif
# if 0
  next = vectors(32, 24, next);
# endif
# if 0  // Done 8min
  next = vectors(32, 16, next);
  for(int i = -7; i <= 7; i++) {
    *next++ = i;
  }
# endif
# if 0  // Done 7min
  next = vectors(16, 16, next);
  for(int i = -7; i <= 7; i++) {
    *next++ = i;
  }
# endif
# if 0  // Done 3min
  next = vectors(32,  8, next);
  next = vectors(32,  4, next);
  next = vectors(32,  2, next);
  for(int i = -25; i <= 25; i++) {
    *next++ = i;
  }
# endif
# if 1  // Done 4min
  for(int i = 0; i < 10; i++) {
    *next++ = myrand();
  }
  for(int i = 0; i < 10; i++) {
    *next++ = myrand() & 0xffff;
  }
  for(int i = 0; i < 10; i++) {
    *next++ = myrand() & 0xff;
  }
  for(int i = 0; i < 10; i++) {
    *next++ = myrand() << 16;
  }
  for(int i = 0; i < 10; i++) {
    *next++ = myrand() << 24;
  }
  for(int i = -7; i <= 7; i++) {
    *next++ = i;
  }
# endif
#endif

#if 0
  // Test values for integer rounding, from Wikipedia.
  *next++ = float2bin(+11.5, kind);
  *next++ = float2bin(+12.5, kind);
#endif

#if 0
# if 0
  next    = specials(kind, next);
# endif
# if 0
  next    = subnormals(kind, next);
# endif
# if 0
  next    = normals(kind, next);
# endif
# if 0
  *next++ = zero2bin(kind);
# endif
# if 0
  *next++ = float2bin(1, kind);
# endif
# if 0
  *next++ = float2bin(1.3256986518444048384e19,  kind);
# endif
# if 0
  next    = fd2intnums(kind, next);
# endif
# if 0
  next    = denormalmuladdnums(kind, next);
# endif
# if 0
  *next++ = float2bin(0, kind);
  *next++ = float2bin(2, kind);
  *next++ = float2bin(7, kind);
  *next++ = float2bin(14, kind);
# endif
# if 0
  *next++ = 0x3f7fffffUL;  // 1 - ULP
  *next++ = 0x3f800001UL;  // 1 + ULP
  *next++ = 0x3fffffffUL;  // 2 - ULP
  *next++ = 0x7f7fffffUL;  // max single
  *next++ = 0x00000001UL;  // min single
  *next++ = 0x3f800000UL;  // 1
# endif
# if 0
  // Some failing (before implementation) double muladd numbers.
  *next++ = 0x3fefffffffffffffULL;  // 1 - ULP
  *next++ = 0x3ff0000000000001ULL;  // 1 + ULP
  *next++ = 0x3fffffffffffffffULL;  // 2 - ULP
  *next++ = 0x7fefffffffffffffULL;  // max double
  *next++ = 0x0000000000000001ULL;  // min double
  *next++ = 0x3ff0000000000000ULL;  // 1
//  *next++ = 0x3ff00000ffc80000ULL;  // 1.1111000...
//  *next++ = 0x3ff0000000800010ULL;  // 1.000...1000...
# endif
# if 0
  *next++ = min2bin(kind);
  *next++ = 0x3f7fffffUL;  // 1 - ULP
# endif
# if 0
  *next++ = min2bin(kind);
  *next++ = 0x3fefffffffffffffULL;  // 1 - ULP
# endif
# if 0
  *next++ = 0x1234567887654321ULL;
  *next++ = 0x5ffcba9876543210ULL;
  *next++ = 0x0011223344556677ULL;
  *next++ = 0x6644ee2200aa7711ULL;
  *next++ = 0x0000000000000001ULL;
  *next++ = 0x0000000000000005ULL;
  *next++ = 0x0000000000350211ULL;
  *next++ = 0x0000185fff350211ULL;
  *next++ = 0x4846212839193756ULL;
  *next++ = 0x0f0f0f0f0f0f0f0fULL;
  *next++ = 0x010101010101010fULL;
  *next++ = 0xaaaaaaaaaaaaaaaaULL;
# endif
#endif

#if defined(NEGATE)
  // Copy all numbers and negate them
  tmp2    = next;
  next    = copy(next, next - tmp);
  negate(kind, next, next - tmp2);
#endif

#if defined(NANBOX)
  nanbox(kind, next, next - tmp);
#endif

  int skip  = 0;
  int count = next - buf;

#if 1
  permute(buf, count);
  skip  = 700;
  count = 40;
#endif

#if defined(CMDTEST)
  printf("Vectors: %d\n", count);
# if 1
  dump(buf + skip, count, 64);
# endif
#endif

#if 0
  f_0  = 0x0000000000000000ULL; // float2bin(0.0, 1);
  f_1  = 0x3ff0000000000000ULL; // float2bin(1.0, 1);
  f_pi = 0x400921fb54442d18ULL; // float2bin(3.14159265358979323846, 1);
#endif

#if defined(ALLRM)
  for(int rm = 0; rm <= 4; rm++)
#else
  int rm = RM;
#endif
  {
# if !defined(CMDTEST)
    write_csr(frm, rm);
# else
    printf("rm %d\n", rm);
# endif
    tests(kind, buf + skip, count);
  }

#if 0
  printf("0.0 0x%016llx\n", float2bin(0.0, 1));
  printf("1.0 0x%016llx\n", float2bin(1.0, 1));
  printf("pi  0x%016llx\n", float2bin(3.1415926535897932383, 1));
#endif

  // Use AND/XOR with split(64, 2, 1, 0) split(64,  4, 2, 0) split(64,  6, 3, 0)
  //                  split(64, 8, 4, 0) split(64, 10, 5, 0) split(64, 12, 6, 0)
  // Use inverted
  // Do something about exponent/mantissa size.
  // Do explicitly OK boxed 32 bit floats
}
