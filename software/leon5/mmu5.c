void mmu5(void)
{
        int o;
        unsigned long tbl[1024];
        unsigned long *tblp = tbl;
        o = ((unsigned long)tblp) & 2047;
        if (o != 0) tblp += (512 - (o >> 2));
        mmudmap(tblp, 0x00ff0000);
        mmudmap_modify(tblp, 0x50000000, 0x40000000, 1, 3);
}
