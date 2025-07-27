#include<stdio.h>
#include<stdlib.h> // exit()

// ~~~ memory stuff ~~~

#define MAX 0x4000
#define MSTR 0x2000
int mem[MAX],lm,ls,lh,lg;char str[MSTR],la,DEBUG=0;FILE*fd;
const char initmem[]="nil\0t\0defun\0lambda\0cond\0atom\0"
	"eq\0car\0cdr\0cons\0quote\0print\0mem\0+\0-\0*\0/\0%\0"
	"begin\0set\0if\0case\0write\0read\0let\0close\0str\0"
	"str-at\0str-set\0list\0macro\0num\0itoa\0atoi\0pair\0";
char rwmem[MSTR]; // unsigned short

// tags: pair num symb ERR - concells point to every second
#define iscons(x) (x&&((x&3)==0))
#define isnum(x) ((x&3)==1)
#define isstr(x) ((x&3)==2)
#define tagnum(x) ((x<<2)|1)
#define tagstr(x) ((x<<2)|2)
#define getstr(x) ((x>>2)+str)
#define car(x) mem[x>>1] // neat!
#define cdr(x) mem[(x>>1)+1]
#define dpr(lvl,...) if(DEBUG>lvl)printf(__VA_ARGS__)

void hcf(int err){
	printf("%i,%i/%i of %i/%i used\n",lm,MAX-lg,ls,MAX,MSTR);
	fd=fopen("coredump","w");
	for(int i=0;i<MSTR;i++){
		//fputc(rwmem[i]>>8,fd); // only outputting ascii for now
		fputc(rwmem[i],fd);
	}fclose(fd);exit(err);
}

int cons(int car,int cdr){
	if(lm+2>lg)printf("err: out of cons memory!\n"),hcf(-1);
	mem[lm++]=car;mem[lm++]=cdr;return(lm-2)<<1;
}

int intern(){ // adapted from sectorlisp
	for(int i=0;i<ls;){ // iterates over strings in memory
		char c=str[i++];
		for(int j=0;;j++){
			if(c!=str[ls+j])break; // char dont match, stop testing
			if(!c)return tagstr(i-j-1); // above makes sure c==str[ls+j]
			c=str[i++];
		}if(c)while(str[i++]);} // reels to beginning of next string if not at end
	int ret=tagstr(ls);while(str[ls++]);
	if(ls>MSTR)printf("err: out of string memory!\n"),hcf(-1);
	return ret;
}

int chkstr(){int ret=0; // check if number
	for(int i=ls;str[i];i++){ret=ret*10+str[i]-'0';
		if(str[i]<'0' || '9'<str[i])return intern();
	}return tagnum(ret);
}



// ~~~ parsing ~~~

#define iswhite() (la==' '||la=='\n'||la=='\t')
#define getnext() (la=getc(fd))
char white(){while(1){
	if(iswhite())getnext();else
	if(la==';')while(la!=10)getnext();
	else break;}
}

int parse(char flags){
	/* flags (only 'iterate' valid as argument):
	 * 1 - whether to iterate parsing, or return a single token (for repl)
	 * 2 - dotpair also doesnt iterate, but we skip remaining args
	 * 4 - whether we're autoquoting */
	if(lm>=lg || ls>=MAX)printf("err: out of parse memory!\n"),hcf(-1);
	white();if(la==')' || la==EOF){getnext();return 0;}

	flags&=1; // enforce input flag correctness (just in case)
	int ret=0,head=0;
	if(la=='.'){getnext();white();flags|=2;}else if(flags&1)ret=cons(0,0);
	if(la=='\'')flags|=4,getnext();
	if(la=='(')getnext(),head=parse(1);
	else if(la=='"'){char*s=str+ls;getnext();
		while(la!='"' && la!=EOF)*s++=la,getnext();
		*s=0;getnext();head=chkstr();
	}else{char*s=str+ls;
		while(!iswhite() && la!='(' && la!=')' && la!=EOF && ls<MSTR)
			*s++=la,getnext();
		*s=0;head=chkstr();
	}

	if(flags&4)head=cons(182,cons(head,0));
	if(ret){car(ret)=head;cdr(ret)=parse(1);return ret;}
	if(flags&2){while(la!=')')getnext();getnext();}return head;
}



// ~~~ utility prints ~~~

#define pprdep 5 // depth at which pprint should stop processing
void pprint_(int i,int d){
	if(!i){printf("nil");return;}
	if((i&3)==3){printf("ERR");return;} // differentiate?
	if(isstr(i)){printf("%s",getstr(i));return;}
	if(isnum(i)){printf("#%i",i>>2);return;}
	if(!d){printf("<etc>");return;}d--;
	if(car(i)==418){printf("(closure)");return;}
	putchar('(');int maxlst=pprdep;
	while(iscons(i)&&maxlst--){
		pprint_(car(i),d);i=cdr(i);if(i)putchar(' ');
	}if(i)printf(". "),pprint_(i,0);
	if(i&&!maxlst)printf("<etc>");putchar(')');
}void pprint(int i){pprint_(i,pprdep);putchar(10);}

void printmem(int*env){
	printf("mem use %i/%i of %i/%i, env is %i\n\n",lm,ls,MAX,MSTR,*env>>1);
	for(int i=0;i<lm;i++){printf("% 4i:",i);
		if(isstr(mem[i]))printf("'%s'%i",getstr(mem[i]),mem[i]>>2);
		else if(isnum(mem[i]))printf("#%i",mem[i]>>2);
		else printf(" %i",mem[i]>>1);
		// wed have to manually keep track of line length to fix this one
		if(i%2)putchar(10);else printf("      ");
	}printf("\n");int i=0;
	while(i<ls){printf("%i:<",i);while(str[i])putchar(str[i++]);printf(">  ");
		while(!str[i] && i<ls)i++;}printf("\n\n"); // since there might be gaps
}

void printenv(int*env){printf("env (%i) binds: ",*env);
	for(int t=*env;t;t=cdr(t)){
		if(!iscons(t)){printf("env broke at %i!",t);break;}
		if(!iscons(car(t))){printf("var broke at %i!",car(t));break;}
		printf("%s,",getstr(car(car(t))));
	}putchar(10);
}



// ~~~ garbage collector (read up on SectorLISP if it makes no sense) ~~~

int garbage(int keep,int min,int max){
	// keep is ptr to non-grb, min is lm b4 grb, min is diff to top (lm-min)
	if(keep<min||isstr(keep)||isnum(keep))return keep;
	if(keep&0xff==0xff)printf("err: gc messed up\n"),hcf(-1);
	if(car(keep)==0x7fff)return cdr(keep); // already processed
	int t=cons(car(keep),cdr(keep));
	dpr(3,"  gc %i -> %i\n",keep>>1,(t-max)>>1);
	car(keep)=0x7fff,cdr(keep)=t-max;
	car(t)=garbage(car(t),min,max);
	cdr(t)=garbage(cdr(t),min,max);
	return t-max;
}

int collect(int keep,int*env,int before){
	// keep is stuff to keep, before is top of mem before we called stuff
	if(before==lm){dpr(3,"no garbage!\n");return keep;}int after=lm;
	dpr(3,"gc %i (%i) from %i-%i in %i :",keep>>1,keep,before,after,lm),
		pprint(keep);
	keep=garbage(keep,before*2,(after-before)*2); // takes care of types
	dpr(3,"gc env from %i\n",*env);
	*env=garbage(*env,before*2,(after-before)*2); // stupid...
	dpr(3,"gc env  to  %i\n",*env);

	if(DEBUG>3&&lg<MAX){printf(" guards %i: ",MAX-lg);for(int i=lg;i<MAX;i++)
		printf("%i, ",mem[i]);putchar(10);}

	for(int at=lg;at<MAX;at++){ // guards processed separately
		dpr(3," guard %i : %i :",mem[at],mem[mem[at]]),pprint(mem[mem[at]]);
		if(mem[at&~1]==0x7fff)mem[at]=at+1; // XXX correct?
		else if(mem[mem[at]]==0xffff)mem[at]=0; // XXX and then it gets deleted?
		else if(mem[mem[at]]==0x7fff)mem[at]=(mem[at]>>1)+1;
		else mem[mem[at]]=garbage(mem[mem[at]],before*2,(after-before)*2);
		dpr(3,"  moved to %i\n",mem[mem[at]]);
	}

	// anything under 'before' is not touched
	// 'after' is how much was taken by eval
	// lm is how much extra we took
	dpr(3,"gc %i (%i)  to  %i-%i in %i :",keep>>1,keep,before,after,lm);
	while(lm>after)mem[before++]=mem[after++];
	for(int i=before;i<after;i++)mem[i]=0xffff;
	if(DEBUG>1)pprint(keep);lm=before;return keep;
}

void passguards(int keep){
	if(!iscons(mem[keep]))return;
	for(int at=lg;at<MAX;at++) // very inefficient - no better ideas?
		if(mem[at]==keep)mem[at]=0;
	int t=car(keep);car(keep)=0; // gently abusing c stack memory
	passguards(t);car(keep)=t;
	t=cdr(keep);cdr(keep)=0;
	passguards(t);cdr(keep)=t;
}

void guard(int keep){ // make it return where the guard was set?
	if(!iscons(mem[keep]))return;
	for(int at=lg;at<MAX;at++)if(mem[at]==keep)return;
	dpr(3,"guarding %i : %i :",keep,mem[keep]),pprint(mem[keep]);
	int shift=0; // compact
	for(int i=MAX-1;i>lg;i--){
		if(shift)mem[i]=mem[i-shift];
		while(!mem[i] && i>lg)
			shift++,lg++,mem[i]=mem[i-shift];
	}if(shift)dpr(3,"removed %i guards\n",shift);
	mem[--lg]=keep;
}



// ~~~ interpreter ~~~

int latoi(int index){ // from spc
	char*s=getstr(index),inv=0;int ret=0;
	dpr(0,"- atoi %s\n",s);
	if(*s=='-'){inv=1;s++;}
	while('0'<=*s&&*s<='9')ret=ret*10+*s++ -'0';
	if(inv)ret*=-1;return tagnum(ret);
}

int litoa(int x){x>>=2; // who even needs printf?
	char*s=str+ls,swap,i;
	if(!x)*s++='0';
	while(x)*s++=(x%10)+'0',x/=10; // stringmem check handled by intern
	*s=0,i=s-(str+ls);
	for(int j=0;j<i>>1;j++){
		swap=str[ls+j];
		str[ls+j]=str[ls+i-j-1];
		str[ls+i-j-1]=swap;
	}return intern();
}

int evsing(int,int*,int*),eval(int,int*);

int evlist(int expr,int*env){ // call this when tailcalls aint an option
	while(cdr(expr)){
		collect(eval(car(expr),env),env,lm);
		expr=cdr(expr);
	}return collect(eval(car(expr),env),env,lm);
}

int eval(int expr,int*env){
	// trampoline wrapper for tailcalls - also takes care of gc
	int tramp=1,tmpenv=0,*envptr=env,before;
	while(tramp){dpr(1,"tailcall\n");
		if(tramp==1){ // tailcall
			tramp=0,before=lm;
			expr=evsing(expr,envptr,&tramp);
			if(iscons(tramp)){ // set new env
				tmpenv=tramp;envptr=&tmpenv;
				dpr(1,"tmp"),printenv(envptr);
				tramp=2; // new envs are implicitly iterated
			}else expr=collect(expr,envptr,before);
		}

		if(tramp==2){ // iterated tailcall (evlist)
			dpr(1,"evlist\n");
			tramp=1,before=lm; // since last one will be a regular tailcall
			while(cdr(expr)){
				eval(car(expr),envptr); // discard value - gc here?
				expr=cdr(expr);
			}expr=collect(car(expr),envptr,before);
		}
	}return expr;
}

int evsing(int expr,int*env,int*tramp){
	dpr(0,"- eval: "),pprint_(expr,3);
	if(!expr){dpr(0," - nil\n");return 0;}

	if(isnum(expr)){dpr(0," - isint\n");return expr;}

	if(isstr(expr)){for(int bind=*env;bind;bind=cdr(bind))
		if(car(car(bind))==expr){
			dpr(0," - env: "),pprint(cdr(car(bind)));
			return cdr(car(bind));
		}dpr(0," - isself\n");return expr;
	}dpr(0,"\n");

	int op=car(expr),prev=0;
	for(int max=10;max;max--){ // icoe breaker
		if(!op)hcf(0); // (())
		if(isnum(op)){printf("err: cannot apply number\n");hcf(-1);}
		// following check makes sure op is a builtin w/ an ugly hack
		if(isstr(op) && (op>>2)<sizeof(initmem)-1){op>>=2;switch(op){
			case 71:*tramp=2;return cdr(expr); // begin
			case 45:return car(cdr(expr)); // quote
			case 77: // set
				for(int bind=*env;bind;bind=cdr(bind)) // pls call it 'binks' so we
					if(car(car(bind))==car(cdr(expr))){ // return car car binks
						passguards((car(bind)>>1)+1); // remove previous guards
						cdr(car(bind))=evlist(cdr(cdr(expr)),env);
						guard((car(bind)>>1)+1); // manual cdr - want varloc, not varval
						return car(car(bind));} // to match defun
				// if no binding, fallthrough to defun
			case 6: // defun
				*env=cons(cons(car(cdr(expr)),0),*env);
				cdr(car(*env))=evlist(cdr(cdr(expr)),env);
				dpr(0,"- bound "),pprint(car(car(*env)));
				return car(car(*env));
			case 12: // lambda - make closure
				return cons(tagstr(104),cons(expr,*env));
			case 19: // cond
				*tramp=2;
				for(int cond=cdr(expr);cond;cond=cdr(cond))
					if(eval(car(car(cond)),env))return cdr(car(cond));
				*tramp=0;return 0;
			case 84:{ // case
				*tramp=2;
				int cmp=eval(car(cdr(expr)),env);
				for(int cond=cdr(cdr(expr));cond;cond=cdr(cond))
					if(eval(car(car(cond)),env)==cmp || !car(car(cond))) // fallthru
						return cdr(car(cond));
				*tramp=0;return 0;}
			case 81: // if
				*tramp=1;
				if(eval(car(cdr(expr)),env))
					return car(cdr(cdr(expr)));
				if(cdr(cdr(cdr(expr))))
					return car(cdr(cdr(cdr(expr))));
				tramp=0;return 0;
			case 100:{ // let
				int tmpenv=*env;
				for(int bind=car(cdr(expr));bind;bind=cdr(bind)){
					tmpenv=cons(cons(car(car(bind)), 0),tmpenv);
					cdr(car(tmpenv))=evlist(cdr(car(bind)),&tmpenv);
				}*tramp=tmpenv;
				return cdr(cdr(expr));}
			case 104:case 134:return expr;} // close, macro

			int args=0,res; // evlist
			if(cdr(expr)){int arglist=cdr(expr);
				args=cons(eval(car(arglist),env),0); // XXX assumes we *have* args
				res=args;arglist=cdr(arglist);
				while(arglist){
					cdr(res)=cons(eval(car(arglist),env),0);
					arglist=cdr(arglist);res=cdr(res);
			}}res=0;dpr(0,"- apply %s (%i) to ",getstr(op<<2),op),pprint(args);

			switch(op){
			case 51: dpr(0,"out: ");pprint(car(args)); return 0; // print
			case 57: printmem(env); return 0; // mem XXX dont need evlist for this?
			case 40:  return cons(car(args),car(cdr(args))); // cons
			case 32:  return car(car(args)); // car
			case 36:  return cdr(car(args)); // cdr
			case 24:  return isstr (car(args))?1:0; // atom
			case 140: return isnum (car(args))?1:0; // num
			case 154: return iscons(car(args))?1:0; // pair
			case 29:  return car(args)==car(cdr(args))?1:0; // eq
			case 129: return args; // list (neat)

			case 144: return litoa(car(args)); // itoa
			case 149: return latoi(car(args)); // atoi

			case 95: return tagnum(rwmem[(car(args)>>2)%MSTR]); // read
			case 89: // write
				if((car(args)>>2)<MSTR)
					rwmem[(car(args)>>2)%MSTR]=car(cdr(args))>>2;
				return car(cdr(args));

			case 110: // str
				lh-=car(args); // allocate from the back
				return tagstr(lh);
			case 114: // str-at
				return tagnum(getstr(car(args))[car(cdr(args))>>2]);
			case 121: // str-set
				getstr(car(args))[car(cdr(args))>>2]=car(cdr(cdr(args)))>>2;
				return 0;

			// XXX bignums would be nice
			case 61: // +
				for(res=0;args;args=cdr(args))res+=car(args)>>2;
				return tagnum(res);
			case 65: // *
				for(res=1;args;args=cdr(args))res*=car(args)>>2;
				return tagnum(res);
			case 63:res=car(args)>>2; // - XXX do the asm trick?
				for(args=cdr(args);args;args=cdr(args))res-=car(args)>>2;
				return tagnum(res);
			case 67:res=car(args)>>2; // /
				for(args=cdr(args);args;args=cdr(args))res/=car(args)>>2;
				return tagnum(res);
			case 69:res=car(args)>>2; // %
				for(args=cdr(args);args;args=cdr(args))res%=car(args)>>2;
				return tagnum(res);
		}}

		if(isstr(car(op))){ // obvious as it might seem, we do gotta check
			if(car(op)==50 || car(op)==418){ // lambda or closure
				// defaults for lambda - ugly, but we'll cope
				int cloj=*env,names=car(cdr(op)),body=cdr(cdr(op)),vals=cdr(expr);
				if(car(op)==418)cloj=cdr(cdr(op)), // closure
					names=car(cdr(car(cdr(op)))),body=cdr(cdr(car(cdr(op))));
				for(;iscons(names)&&vals;names=cdr(names),vals=cdr(vals))
					cloj=cons(cons(car(names), eval(car(vals),env) ),cloj);
				if(isstr(names)){int varargs=cons(names,0);cloj=cons(varargs,cloj);
					while(vals){cdr(varargs)=cons(eval(car(vals),env),0);
						varargs=cdr(varargs);vals=cdr(vals);}names=0;}
				if(names)printf("insufficient args!\n");
				while(iscons(names))
					cloj=cons(cons(car(names),0),cloj),names=cdr(names);
				if(names)cloj=cons(cons(names,0),cloj);
				*tramp=cloj;return body;
			}

			if(car(op)==538){ // macro - largely the same as lambdas
				dpr(0,"- macro application\n");
				int cloj=*env,names=car(cdr(op)),body=cdr(cdr(op)),vals=cdr(expr);
				for(;iscons(names)&&vals;names=cdr(names),vals=cdr(vals))
					cloj=cons(cons(car(names), car(vals) ),cloj);
				if(isstr(names)){int varargs=cons(names,0);cloj=cons(varargs,cloj);
					while(vals){cdr(varargs)=cons(car(vals),0);
					varargs=cdr(varargs);vals=cdr(vals);}names=0;}
				if(names)printf("insufficient args!\n");
				while(iscons(names))
					cloj=cons(cons(car(names),0),cloj),names=cdr(names);
				body=evlist(body,&cloj);
				dpr(0,"- macro intermediary is "),pprint(body);
				*tramp=1;return body;
			}
		}

		prev=op;op=eval(op,env);
		if(op==prev)break;
	}

	printf("err: cannot eval @%i/%i: ",expr,lm);pprint(expr);hcf(-1);
}



// ~~~ repl ~~~

int main(int argc,char**argv){
	lm=2;ls=sizeof(initmem)-1;lh=MSTR-1;lg=MAX;
	for(int i=0;i<MAX;i++)mem[i]=0;
	for(int i=0;i<ls;i++)str[i]=initmem[i];
	for(int i=ls;i<MSTR;i++)str[i]=0;

	fd=argc>1?fopen(argv[1],"r"):stdin;
	if(!fd){printf("could not open file\n");return 0;}
	DEBUG=argc>2?argv[2][0]-'0':0;int data,env=0,before;

	while(1){
		if(argc==1)printf("< ");before=lm;
		getnext();data=parse(0);
		dpr(0,"input: "),pprint(data),printenv(&env);
		if(feof(fd))break;data=eval(data,&env);
		dpr(0,"(%i) ",data);printf("> ");pprint(data);
		dpr(1,"repl gc:\n");collect(0,&env,before);
		while(lg<MAX)mem[lg++]=0;

		dpr(0,"mem:%i/%i\n\n",lm,ls);
	}putchar(10);fclose(fd);hcf(0);
}

/* reference implementation of a (usable!) lisp interpreter
currently specifically tailored/hacked to run the self-compiler

tags: pair num symb vec

todo:
- vectors?
- io ports
- hcf if args to primfns missing (macros iffy)
- callstack traces in debugger

we dont check for missing args - which is STILL the leading cause of segfaults

could be nicer if we did (lambda args body) -> (close env args body)

r5rs defines `case` to use a *list* of matches - do we wanna?

its annoying that the parser needs flags. can we figure out how to make it
 work w/out them?

repl cant parse `(expr)(expr)` properly

is there any reason the guard list shouldnt be sorted? passguard could be
 more efficient

debug lvls:
0 - any debugs
1 - tailcalls
3 - gc

`env: (closure` is always output b4 a funcall - any pattern for fncret?
restructuring/sorting dbg msgs should help as well

*/
