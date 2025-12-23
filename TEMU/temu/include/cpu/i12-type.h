#ifndef __I12TYPE_H__
#define __I12TYPE_H__

make_helper(ori);
make_helper(addi_w);
make_helper(andi);
make_helper(xori);

make_helper(sltui);

/* 12-bit 立即数的 load/store 与 byte 访问以及分支 */
make_helper(ld_w);
make_helper(st_w);
make_helper(ld_b);
make_helper(st_b);

make_helper(beq);
make_helper(bne);
make_helper(bgeu);

#endif
