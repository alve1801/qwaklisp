/* QWAK Lisp emulator
 Copyright (C) 2023-2025 Ave Tealeaf

This file is part of QWAK Lisp.

QWAK Lisp is free software: you can redistribute it and/or modify it under
 the terms of the GNU Lesser General Public License, version 3 or later, as
 published by the Free Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT
 ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License
 for more details.

You should have received a copy of the GNU Lesser General Public License
 along with this program. If not, see <https://www.gnu.org/licenses/>. */

#include<stdio.h>
#define u16 unsigned short
#define MAXMEM 0x2000 // XXX 0x10000 in prod
u16 mem[MAXMEM];char debug=0;
#define pc mem[0]
#define acc mem[1]
#define opr mem[2]

void step(){
	if(!pc)return; // machine halted
	u16 op=mem[pc++]; // fetch opcode
	if(debug)printf("% 4x : % 4x ",pc-1,op);
	if(op<0xfff0){acc=op;if(debug)printf("%i\n",acc);return;} // acc mode

	if(debug){
		const char*cmdnames=
			"jmp cnd get set and ior xor sft "
			"add sub swp out idk idc pop psh ";
		const char*t=cmdnames+((op&0xf)<<2);
		putchar(*t++);putchar(*t++);putchar(*t++);
		printf(" (%i %i)\n",acc,opr);
	}

	switch(op&0xf){ // remove operand mask
		case 0:pc=acc;break; // jmp
		case 1:if(acc)pc+=2;break; // cnd
		case 2:acc=mem[opr];break; // get
		case 3:mem[opr]=acc;break; // set

		case 4:acc&=opr;break; // and
		case 5:acc|=opr;break; // or
		case 6:acc^=opr;break; // xor
		case 7:acc>>=opr&0xf;acc<<=opr>>4;break; // bitshift

		case 8:acc+=opr;break; // add
		case 9:acc-=opr;break; // sub
		case 10:acc^=opr;opr^=acc;acc^=opr;break; // swp
		case 11: // io XXX deref for modes (once i figure them out)
			if(debug)printf(" < %i '%c'\n",acc,(char)acc);
			else{if(acc>255)putchar(acc>>8);putchar(acc);}

		case 12:case 13:break; // idk idc - nop
		case 14:acc=mem[mem[opr]--];break; // pop
		case 15:mem[++mem[opr]]=acc;break; // psh
	}fflush(stdout);
}

int main(int argc,char**argv){
	FILE*fd=argc>1?fopen(argv[1],"r"):stdin;int at=0;
	if(argc>2)debug=1;
	while(!feof(fd)){mem[at]=getc(fd)<<8;mem[at]|=getc(fd);at++;}
	if(debug)printf("loaded %i words\n",at);
	while(pc && pc<MAXMEM)step();
	if(pc==MAXMEM)printf("stacksize abort\n");
	if(opr)printf("return code %i\n",opr);return 0;
}

/* vm emulator for the lisp compiler

	0 jmp cnd get set
	4 and ior xor sft
	8 add sub swp out
	c idk idc pop psh

- bitshift aac right by low nibble then left by high nibble of opr (ala uxn)
- cnd skips over next two commands if acc!=0 (one to set acc, one to jmp)
 - "if true we skip, if false we jmp"
 - can use ".val cnd '1 cnd .addr jmp" to invert

been meaning to figure out how to shuffle arguments so i dont have to `SWP` so
 often. tldr if half the opcodes that use both registers have their args
 swapped, we dont need to manually swap to interface them w/ the other half

*/
