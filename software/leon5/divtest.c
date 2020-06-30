#include "testmod.h"
#ifdef LEON2
#include "leon2.h"
#endif

struct divcase {
	int	num;
	int	denom;
	int	res;
};

volatile struct divcase diva[] = {
	{  2,  3, 0}, { 3, -2, -1}, {  2, -3, 0}, {  0,  1, 0}, {  0, -1, 0}, {  1, -1, -1},
	{ -1,  1, -1}, { -2,  3, 0}, { -2, -3, 0}, {9, 7, 1}, 
	{ -9, 2, -4}, {-8, 2, -4}, {-8, -4, 2}, {8, -4, -2}, {-8, -8 , 1},
	{-8, -9, 0}, {11, 2, 5}, {47, 2, 23}, 
	{ 12345,  679, 12345/679}, { -63636,  77, -63636/77},
	{ 12345,  -679, -12345/679}, { -63636,  -77, 63636/77},
	{ 145,  -6079, 0}, { -636,  -77777, 0}, { 63226,  7227777, 0},
	{  0,  0, 0}
 };

struct udivcase {
	unsigned int	num;
	unsigned int	denom;
	unsigned int	res;
};

volatile struct udivcase udiva[] = {
	{  2,  3, 0}, {  0,  1, 0}, { 0xfffffffe,  3, 0xfffffffe/3},
	{ 0xfffffffe,  3, 0xfffffffe/3}, { 0x700ffffe,  7, 0x700ffffe/7},
	{  0,  0, 0}
 };

struct bigdivcase {
        unsigned int type; /* 0=UDIV, 1=UDIVCC, 2=SDIV, 3=SDIVCC, >3=EOL */
        unsigned int numhi;
        unsigned int num;
        unsigned int denom;
        unsigned int res;
        unsigned int flags; /* 8=neg, 4=zero, 2=overflow, 1=carry(never set) */
};

struct bigdivcase bigdiva[] = {
        /* UDIVCC */
        /* FFFFFFFF00000000 / 1 -> overflow result 0xFFFFFFFF */
        { 1, 0xffffffff, 0x00000000, 0x00000001, 0xffffffff, 8|2 },
        /* 00000000FFFFFFFF / 1 -> no overflow result 0xFFFFFFFF */
        { 1, 0x00000000, 0xffffffff, 0x00000001, 0xffffffff, 8},
        /* SDIVCC */
        /* 0000000100000000 / 1 -> overflow result 0x7FFFFFFF */
        { 3, 0x00000001, 0x00000000, 0x00000001, 0x7fffffff, 2},
        /* 000000007FFFFFFF / 1 ->  no overflow result 0x7FFFFFFF */
        { 3, 0x00000000, 0x7fffffff, 0x00000001, 0x7fffffff, 0},
        /* 800000000000000 / 0xFFFFFFFF(-1) ->  overflow result 0x7FFFFFFF */
        { 3, 0x80000000, 0x00000000, 0xffffffff, 0x7fffffff, 2},
#if 1
        /* FFFFFFFF80000000 / 0xFFFFFFFF (-1) -> overflow result 0x7FFFFFFF */
        { 3, 0xffffffff, 0x80000000, 0xffffffff, 0x7fffffff, 2},
#endif
        /* FFFFFFFF80000001 / 0xFFFFFFFF(-1) ->  no overflow result 0x7FFFFFFF */
        { 3, 0xffffffff, 0x80000001, 0xffffffff, 0x7fffffff, 0},
        /* FFFFFFFF80000000 / 0x1 ->  no overflow result 0x80000000 */
        { 3, 0xffffffff, 0x80000000, 0x00000001, 0x80000000, 8},
        /* 0000000100000000 / 0xFFFFFFFE(-2) ->  no overflow result 0x80000000 */
        { 3, 0x00000001, 0x00000000, 0xfffffffe, 0x80000000, 8},
        /* FFFFFFFF80000000 / 0xFFFFFFFE(-2) ->  no overflow result 0x40000000 */
        { 3, 0xffffffff, 0x80000000, 0xfffffffe, 0x40000000, 0},
        /* FFFFFFFF80000001 / 0xFFFFFFFF(-1) ->  no overflow result 0x7FFFFFFF */
        { 3, 0xffffffff, 0x80000001, 0xffffffff, 0x7fffffff, 0},
#if 1
        /* FFFFFFFF00000000 / 0xFFFFFFFE(-2) ->  overflow result 0x7FFFFFFF */
        { 3, 0xffffffff, 0x00000000, 0xfffffffe, 0x7fffffff, 2},
#endif
        /* FFFFFFFF00000000 / 0xFFFFFFFC(-4) ->  no overflow result 0x40000000 */
        { 3, 0xffffffff, 0x00000000, 0xfffffffc, 0x40000000, 0},
        /* 0000000100000010 / 0xFFFFFFFE(-2) ->  overflow result 0x80000000 */
        { 3, 0x00000001, 0x00000010, 0xfffffffe, 0x80000000, 8|2},
#if 1
        /* 0000000080000000 / 0xFFFFFFFF(-1) ->  no overflow result 0x80000000 */
        { 3, 0x00000000, 0x80000000, 0xffffffff, 0x80000000, 8},
        /* 0000000180000000 / 0xFFFFFFFD (-3) -> no overflow result 0x80000000 */
        { 3, 0x00000001, 0x80000000, 0xfffffffd, 0x80000000, 8},
#endif
        /* end of list */
        { 9,0,0,0,0 } 
};

unsigned int bigdiv(unsigned int type, unsigned int numhi, unsigned int num,
                    unsigned int denom, int *flags_out);

divtest()
{
#ifdef LEON2
	struct l2regs *lr = (struct l2regs *) 0x80000000;
#endif
	int i = 0, f;

	/* skip test if divider disabled */
#ifdef LEON2
	if (!((lr->leonconf >> DIV_CONF_BIT) & 1)) return(0);
#else
	if (!((get_asr17() >> 8) & 1)) return(0);	
#endif
	
	report_subtest(DIV_TEST+(get_pid()<<4));
	while (diva[i].denom != 0) {
	    if ((diva[i].num / diva[i].denom) != diva[i].res) fail(1);
	    i++;
	}
	i = 0;
	while (udiva[i].denom != 0) {
	    if ((udiva[i].num / udiva[i].denom) != udiva[i].res) fail(2);
	    i++;
	}
	if (!divpipe()) fail(3);

        i = 0;
        while (bigdiva[i].type < 4) {
                if (bigdiv(bigdiva[i].type, bigdiva[i].numhi, bigdiva[i].num,
                           bigdiva[i].denom, &f) != bigdiva[i].res) fail(4+8*i);
                if ((bigdiva[i].type & 1) != 0 && f != bigdiva[i].flags) fail(5+8*i);
                i++;
        }

	return(0);
}
