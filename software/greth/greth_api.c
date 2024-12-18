/*****************************************************************************/
/*   This file is a part of the GRLIB VHDL IP LIBRARY            */
/*   Copyright (C) 2007 - 2012 Aeroflex Gaisler                  */
/*                                       */
/*   This program is free software; you can redistribute it and/or modify    */
/*   it under the terms of the GNU General Public License as published by    */
/*   the Free Software Foundation; either version 2 of the License, or       */
/*   (at your option) any later version.                     */
/*                                       */
/*   See the file COPYING for the full details of the license.           */
/*****************************************************************************/

/* Changelog */
/* 2008-02-01: GRETH API separated from test  - Marko Isomaki */
/* 2012-09-06: include stdlib.h */
/* 2013-06-11: Clarify almalloc */

#include "greth_api.h"
#include <stdlib.h>

#ifdef NOELV_SYSTEST
/* Bypass cache load  */
static inline int load(addr_t addr)
{
    int tmp;
    asm volatile ("lw %0, 0(%1)"
    : "=r"(tmp)
    : "r"(addr)
    );
    return tmp;
}

static inline int save(addr_t addr, unsigned int data)
{
    *((volatile unsigned int*)addr) = data;
}

static inline int saved(addr_t addr, uint64_t data)
{
    asm volatile ("sd %0, 0(%1)"
    : "=r"(data)
    : "r"(addr)
    );
}

/* Allocate memory aligned to the size. Size needs to be a power of two. */
static char *almalloc(int sz)
{
    // NOTE: each descriptor size is 8 bytes: ctrl+addr
    int descriptor_table_size = sz / 8;
    char* mem_8aligned;
    uint32_t* mem_32aligned;
    int i;
    mem_8aligned = malloc(2 * sz);
    mem_8aligned = (char*)(((uint32_t)mem_8aligned + sz) & ~(sz - 1));

    /* Initialize, what will be, every ctrl word */
    mem_32aligned = (uint32_t*)mem_8aligned;
    for (i = 0; i < descriptor_table_size; ++i) {
        mem_32aligned[i * 2] = 0;
        if (i == 0) {
        }
    }
    return(mem_8aligned);
}
#else // Leon3
/* Bypass cache load  */
static inline int load(int addr)
{
    int tmp;
    asm volatile(" lda [%1]1, %0 "
    : "=r"(tmp)
    : "r"(addr)
    );
    return tmp;
}

static inline int save(unsigned int addr, unsigned int data)
{
    *((volatile unsigned int *)addr) = data;
}

/* Allocate memory aligned to the size. Size needs to be a power of two. */
static char *almalloc(int sz)
{
    char* mem_8aligned;
    int* mem_32aligned;
    int i;
    mem_8aligned = malloc(2 * sz);
    mem_8aligned = (char*)(((int)mem_8aligned + sz) & ~(sz - 1));

    /* Initialize, what will be, every ctrl word */
    mem_32aligned = (int*)mem_8aligned;
    for (i = 0; i < sz / 8; ++i) {
        mem_32aligned[i * 2] = 0;
    }
    return(mem_8aligned);
}
#endif // end ifdef NOELV_SYSTEST


int read_mii(int phyaddr, int addr, volatile greth_regs *regs)
{
    unsigned int tmp;

    do {
        tmp = load((addr_t)&(regs->mdio));
    } while (tmp & GRETH_MII_BUSY);

    tmp = (phyaddr << 11) | ((addr & 0x1F) << 6) | 2;
    save((addr_t)&(regs->mdio), tmp);

    do {
        tmp = load((addr_t)&(regs->mdio));
    } while (tmp & GRETH_MII_BUSY);

    if (!(tmp & GRETH_MII_NVALID)) {
        tmp = load((addr_t)&(regs->mdio));
        return (tmp >> 16) & 0xFFFF;
    } else {
        return -1;
    }
}

void write_mii(int phyaddr, int addr, int data, volatile greth_regs *regs)
{
    unsigned int tmp;

    do {
        tmp = load((addr_t)&(regs->mdio));
    } while (tmp & GRETH_MII_BUSY);

    tmp = ((data & 0xFFFF) << 16) | (phyaddr << 11) | ((addr & 0x1F) << 6) | 1;

    save((addr_t)&regs->mdio, tmp);

    do {
        tmp = load((addr_t)&(regs->mdio));
    } while (tmp & GRETH_MII_BUSY);

}

int greth_set_mac_address(struct greth_info *greth, unsigned char *addr)
{
    greth->esa[0] = addr[0];
    greth->esa[1] = addr[1];
    greth->esa[2] = addr[2];
    greth->esa[3] = addr[3];
    greth->esa[4] = addr[4];
    greth->esa[5] = addr[5];
    save((addr_t)&greth->regs->esa_msb, addr[0] << 8 | addr[1]);
    save((addr_t)&greth->regs->esa_lsb, addr[2] << 24 | addr[3] << 16 | addr[4] << 8 | addr[5]);
    return 1;
}

int greth_init(struct greth_info *greth)
{
    unsigned int tmp;
    int i;
    int duplex, speed;
    int gbit;

    tmp = load((addr_t)&greth->regs->control);
    greth->gbit = (tmp >> 27) & 1;
    greth->edcl = (tmp >> 31) & 1;
    greth->timestamps = (tmp >> GRETH_CTRL_TS_CAPABLE_BIT) & 1;
    greth->edclen = ((tmp >> 14) & 1) ^ 1;

    if (greth->edcl == 0) {
        /* Reset the controller. */
        save((addr_t)&greth->regs->control, GRETH_RESET);
        do {
            tmp = load((addr_t)&greth->regs->control);
        } while (tmp & GRETH_RESET);
    }

    /* Get the phy address which assumed to have been set
     * correctly with the reset value in hardware
     */
    tmp = load((addr_t)&greth->regs->mdio);
    greth->phyaddr = ((tmp >> 11) & 0x1F);

    greth->txd = (struct descriptor *) almalloc(1024); // Orig: 1024
    greth->rxd = (struct descriptor *) almalloc(1024); // Orig: 1024
#ifdef NOELV_SYSTEST
    save((greth_reg_t)&(greth->regs->tx_desc_p), (greth_reg_t) greth->txd);
    save((greth_reg_t)&(greth->regs->rx_desc_p), (greth_reg_t) greth->rxd);
#else
    save((int)&(greth->regs->tx_desc_p), (unsigned int) greth->txd);
    save((int)&(greth->regs->rx_desc_p), (unsigned int) greth->rxd);
#endif
    greth->txpnt = 0;
    greth->rxpnt = 0;
    greth->txchkpnt = 0;
    greth->rxchkpnt = 0;

    /* Reset PHY */
    if (greth->edcl == 0 || greth->edclen == 0) {
        write_mii(greth->phyaddr, 0, 0x8000, greth->regs);
        while ((tmp = read_mii(greth->phyaddr, 0, greth->regs)) & 0x8000);
        i = 0;
        if (tmp & 0x1000) { /* auto neg */
            while (!(read_mii(greth->phyaddr, 1, greth->regs) & 0x20)) {
                i++;
                if (i > 50000) {
                    /* //* printf("Auto-negotiation failed\n"); */
                    break;
                }
            }
        }
        tmp = read_mii(greth->phyaddr, 0, greth->regs);

        if (greth->gbit && !((tmp >> 13) & 1) && ((tmp >> 6) & 1)) {
            gbit = 1; speed = 0;
        } else if (((tmp >> 13) & 1) && !((tmp >> 6) & 1)) {
            gbit = 0; speed = 1;
        } else if (!((tmp >> 13) & 1) && !((tmp >> 6) & 1)) {
            gbit = 0; speed = 0;
        }
        duplex = (tmp >> 8) & 1;

        /* Disable Gbit PHY if Gigabit GRETH isn't included */
        if (!greth->gbit) {
           gbit = 0;
           write_mii(greth->phyaddr, 0x9, 0x0000 , greth->regs);
        }

        save((addr_t)&greth->regs->control, ((greth->edclen^1) << 14) | (duplex << 4) | (speed << 7) | (gbit << 8));
    } else {
        /* Wait for edcl phy initialisation to finish */
        i = 0;
        while (i < 3) {
            tmp = load((addr_t)&greth->regs->mdio);
            if ((tmp >> 3) & 1) {
                i = 0;
            } else {
                i++;
            }
        }
    }
    // printf("GRETH(%s) Ethernet MAC at [0x%x]. Running %d Mbps %s duplex\n",
    //        greth->gbit?"10/100/1000":"10/100" , \
    //        (unsigned int)(greth->regs),  \
    //        (speed == 0x2000) ? 100:10, duplex ? "full":"half");
    greth_set_mac_address(greth, greth->esa);

}

inline int greth_tx(int size, char *buf, struct greth_info *greth)
{
    int timestamps_enabled;
    volatile struct descriptor_timestamps *descriptors_ts;

    timestamps_enabled = load((addr_t)&(greth->regs->control)) &
                              (1u << GRETH_CTRL_TS_ENABLE_BIT);

    if (timestamps_enabled) {
        descriptors_ts = (struct descriptors_timestamps *) greth->txd;

        if ((load((addr_t)&(descriptors_ts[greth->txpnt].ctrl)) >> 11) & 1) {
            return 0;
        }

        descriptors_ts[greth->txpnt].addr = (greth_reg_t)buf;
        if (greth->txpnt == GRETH_TXBD_NUM_TS - 1) {
            descriptors_ts[greth->txpnt].ctrl = GRETH_BD_WR | GRETH_BD_EN | size;
            greth->txpnt = 0u;
        } else {
            descriptors_ts[greth->txpnt].ctrl = GRETH_BD_EN | size;
            greth->txpnt++;
        }
    } else {
        if ((load((addr_t)&(greth->txd[greth->txpnt].ctrl)) >> 11) & 1) {
            return 0;
        }

        greth->txd[greth->txpnt].addr = (greth_reg_t)buf;
        if (greth->txpnt == GRETH_TXBD_NUM - 1) {
            greth->txd[greth->txpnt].ctrl = GRETH_BD_WR | GRETH_BD_EN | size;
            greth->txpnt = 0u;
        } else {
            greth->txd[greth->txpnt].ctrl = GRETH_BD_EN | size;
            greth->txpnt++;
        }
    }

    greth->regs->control = load((addr_t)&(greth->regs->control)) | GRETH_TXEN; // Original
    return 1;
}

inline int greth_rx(char *buf, struct greth_info *greth)
{
    int timestamps_enabled;
    volatile struct descriptor_timestamps *descriptors_ts;

    timestamps_enabled = load((addr_t)&(greth->regs->control)) &
                              (1u << GRETH_CTRL_TS_ENABLE_BIT);

    if(timestamps_enabled) {
        descriptors_ts = (struct descriptors_timestamps *) greth->rxd;

        if (((load((addr_t)&(descriptors_ts[greth->rxpnt].ctrl)) >> 11) & 1)) {
            return 0;
        }
        descriptors_ts[greth->rxpnt].addr = (greth_reg_t)buf;
        if (greth->rxpnt == GRETH_RXBD_NUM_TS - 1) {
            descriptors_ts[greth->rxpnt].ctrl = GRETH_BD_WR | GRETH_BD_EN;
            greth->rxpnt = 0;
        } else {
            descriptors_ts[greth->rxpnt].ctrl = GRETH_BD_EN; // set it to 2048 (busy bit ON)
            greth->rxpnt++;
        }
    } else {
        if (((load((addr_t)&(greth->rxd[greth->rxpnt].ctrl)) >> 11) & 1)) {
            return 0;
        }
        greth->rxd[greth->rxpnt].addr = (greth_reg_t)buf;
        if (greth->rxpnt == GRETH_RXBD_NUM - 1) {
            greth->rxd[greth->rxpnt].ctrl = GRETH_BD_WR | GRETH_BD_EN;
            greth->rxpnt = 0;
        } else {
            greth->rxd[greth->rxpnt].ctrl = GRETH_BD_EN; // set it to 2048 (busy bit ON)
            greth->rxpnt++;
        }
    }

    greth->regs->control = load((addr_t)&(greth->regs->control)) | GRETH_RXEN; // Original
    return 1;
}

inline int greth_checkrx(int *size, struct rxstatus *rxs, struct greth_info *greth)
{
    int tmp;
    int timestamps_enabled;
    volatile struct descriptor_timestamps *descriptors_ts;

    timestamps_enabled = load((addr_t)&(greth->regs->control)) &
                              (1u << GRETH_CTRL_TS_ENABLE_BIT);

    if (timestamps_enabled) {
        descriptors_ts = (struct descriptors_timestamps *) greth->rxd;
        tmp = load((addr_t)&(descriptors_ts[greth->rxchkpnt].ctrl));
    } else {
        tmp = load((addr_t)&(greth->rxd[greth->rxchkpnt].ctrl));
    }
    if (!((tmp >> 11) & 1)) { // Check Enable bit
        *size = tmp & GRETH_BD_LEN; // Get number of bytes received (10 downto 0)
        if (tmp & GRETH_BD_WR) { // Descriptor is indicating to wrap.
            greth->rxchkpnt = 0;
        } else {
            greth->rxchkpnt++;
        }
        return 1;
    } else {
        return 0;
    }
}

inline int greth_checktx(struct greth_info *greth)
{
    int tmp;
    int timestamps_enabled;
    volatile struct descriptor_timestamps *descriptors_ts;

    timestamps_enabled = load((addr_t)&(greth->regs->control)) &
                              (1u << GRETH_CTRL_TS_ENABLE_BIT);

    if (timestamps_enabled) {
        descriptors_ts = (struct descriptors_timestamps *) greth->rxd;
        tmp = load((addr_t)&(descriptors_ts[greth->txchkpnt].ctrl));
    } else {
        tmp = load((addr_t)&(greth->txd[greth->txchkpnt].ctrl));
    }
    if (!((tmp >> 11) & 1)) {
        if (tmp & GRETH_BD_WR) { /* Descriptor indicates to wrap */
            greth->txchkpnt = 0;
        } else {
            greth->txchkpnt++;
        }
        return 1;
    } else {
      return 0;
    }
}

inline int greth_enable_timestamps(struct greth_info *greth)
{
    unsigned int tmp;
    tmp = load((addr_t)&(greth->regs->control));
    save((addr_t)&(greth->regs->control), tmp | (1 << GRETH_CTRL_TS_ENABLE_BIT));
    return (tmp >> GRETH_CTRL_TS_CAPABLE_BIT) & 1;
}
