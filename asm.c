/* QWAK Lisp assembler
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
#include<stdlib.h> // for malloc
#include<string.h> // for strcmp XXX remove?
#define u16 unsigned short // from vm.c
#define MAX 0x2000
u16 mem[MAX],at=0;FILE*fd;char DEBUG,tmpstr[32]; // for passing stuff
#define white(a) (a==' '|a=='\n'|a=='\t')
#define dpr(lvl,...) if(DEBUG>lvl)printf(__VA_ARGS__)

typedef struct bind{
	char name[32];
	int val,rn,refs[16];
	struct bind*next;
}bind;bind*env=0;

// XXX constructor

void makebind(int val){
	for(bind*t=env;t;t=t->next)if(!strcmp(tmpstr,t->name)){
		if(t->val)printf("err: overwriting value of %s\n",t->name);
		for(int i=0;i<t->rn;i++)mem[t->refs[i]]=val;
		t->val=val;t->rn=0;return;}
	// create new entry
	dpr(1,"dbg: binding label '%s' to %i\n",tmpstr,val);
	bind*newbind=malloc(sizeof(bind));
	strcpy(newbind->name,tmpstr);
	newbind->val=val;
	newbind->rn=0;
	newbind->next=env;
	env=newbind;
}

u16 getref(){
	for(bind*t=env;t;t=t->next)if(!strcmp(tmpstr,t->name)){
		if(t->val)return t->val;
		if(t->rn>15)printf("err: too many bindings for %s\n",t->name);
		else t->refs[t->rn++]=at;return 0;}
	// create new entry
	dpr(1,"dbg: delayed binding of '%s'\n",tmpstr);
	bind*newbind=malloc(sizeof(bind));
	strcpy(newbind->name,tmpstr);
	newbind->val=0;
	newbind->rn=1;
	newbind->refs[0]=at;
	newbind->next=env;
	env=newbind;return 0;
}

void assemble(){for(;;){
	char a=getc(fd);while(white(a))a=getc(fd);if(!a||a==EOF)return;
	// XXX switch?

	if(a==';')while(a!='\n' && a!=EOF)a=getc(fd);

	else if(a=='\''){ // parse int, output that
		u16 res=0;a=getc(fd);
		if(a=='x'){a=getc(fd);
			while(('0'<=a&&a<='9')||('a'<=a&&a<='f'))
				res=res*16+a-(a>'@'?'a'-10:'0'),a=getc(fd);
		}else if(a=='b'){a=getc(fd);
			while(a=='0' || a=='1')
				res=(res<<1)+(a=='1'),a=getc(fd);
		}else // decimal
			while('0'<=a&&a<='9')
				res=res*10+a-'0',a=getc(fd);
		mem[at++]=res;

	}else if(a=='"'){ // output ascii until we match another doublequote
		a=getc(fd);while(a!='"')mem[at++]=a,a=getc(fd);

	}else if(a==':'){ // copy to tmpstr, then pass to makebind()
		int sat=0;a=getc(fd);
		while(!white(a))tmpstr[sat++]=a,a=getc(fd);
		tmpstr[sat]=0;makebind(at);

	}else if(a=='.'){ // copy to tmpstr, then pass to getref()
		int sat=0;a=getc(fd);
		while(!white(a))tmpstr[sat++]=a,a=getc(fd);
		tmpstr[sat]=0;mem[at]=getref();at++;

	}else{ // check against builtins
		const char*cmdnames=
			"jmp cnd get set and ior xor sft "
			"add sub swp out idk idc pop psh ";
			//"jmp\0cnd\0get\0set\0and\0ior\0xor\0sft\0"
			//"add\0sub\0swp\0out\0idk\0idc\0pop\0psh\0";
		//char*t=cmdnames+((op&0xf)<<2);
		tmpstr[0]=a;tmpstr[1]=getc(fd);tmpstr[2]=getc(fd);tmpstr[3]=0;
		for(int op=0;op<16;op++)
			if( // XXX come up w/ smth better?
				cmdnames[op*4+0]==tmpstr[0] &&
				cmdnames[op*4+1]==tmpstr[1] &&
				cmdnames[op*4+2]==tmpstr[2]
			){
				mem[at++]=0xfff0|op;
				tmpstr[0]=0;
			}
		if(tmpstr[0]){
			printf("err: unknown cmd '%s' at %i\n",tmpstr,at);
			mem[at++]=0xfffc;
		}
	}
}}

void main(int argc,char**argv){
	fd=argc>1?fopen(argv[1],"r"):stdin;
	DEBUG=argc>3?argv[3][0]-'0':0;assemble();fclose(fd);
	for(bind*t=env;t;t=t->next)
		if(!t->val)printf("err: did not find label for '%s'\n",t->name);
	if(DEBUG>0){
		printf("dbg: bindings:\n");
		for(bind*t=env;t;t=t->next)
			printf("dbg:  % 4x : %s\n",t->val,t->name);
		printf("dbg: assembled to %i words\n",at);
	}fd=argc>2?fopen(argv[2],"w"):stdout;
	for(int i=0;i<at;i++){putc(mem[i]>>8,fd);putc(mem[i],fd);}fclose(fd);
}

/* assembler for the vm isa

strcmp is VERY hacky, pls come up w/ smth better
*/
