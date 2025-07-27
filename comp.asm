; builtin assembler routines and environment for compiled code

; in prod: heap 32kb, stack after code
.main '0 '0 :retval '0 :stp 'x1000 :csp 'x1000 :hap 'x2000 :smb '0

:invarg '3 swp '0 jmp ; invalid argument

:printstr ; (... *str ret) - works
	.stp swp pop swp '6 add swp .printstr_ret swp set
	; check tag
	;.stp swp pop psh swp '7 and swp '3 xor cnd '1 cnd .invarg jmp
	;.stp swp pop swp 'x33 swp sft swp :printstr_loop
	.stp swp pop swp :printstr_loop
	get cnd :printstr_ret '0 jmp out '1 add swp .printstr_loop jmp

:printnum ; (... num ret) works XXX shorten? XXX print backwards!
	.stp swp pop swp '6 add swp .printnum_ret swp set
	.stp swp pop psh swp '3 and swp '2 xor cnd '1 cnd .invarg jmp
	.stp swp pop swp '2 swp sft swp .printnum_val swp set
	:printnum_loop
	.printnum_val swp get cnd .printnum_ret jmp
		swp 'x44 swp sft swp .printnum_tmp swp set
	.printnum_val swp get swp :printnum_tmp '0 swp sub
	swp .printnum_data add swp get out
	.printnum_val swp get swp 'x4 swp sft swp .printnum_val swp set
	:printnum_val '0 cnd :printnum_ret '0 jmp .printnum_loop jmp
:printnum_data "0123456789abcdef"

:printargs ; (... args[] numargs ret)
	.stp swp pop swp '6 add swp .printargs_ret swp set
	.stp swp pop swp .printargs_argnum swp set
	:printargs_argnum '0 cnd :printargs_ret '0 jmp
	swp '1 swp sub swp .printargs_argnum swp set
	;'0 swp get swp .stp swp psh .printnum jmp '10 out ; XXX not always num!
	.stp swp pop out '10 out
	.printargs_argnum jmp

:predret ; (... ret) ; if0 .retval - works
	.stp swp pop swp '6 add swp .pred_ret swp set
	.retval swp get cnd .pred_tru jmp ; conditional
	.retval swp '0 set .pred_ret jmp ; nil if false
	:pred_tru .retval swp '2 set ; 0 if true
	:pred_ret '0 jmp

:return ; (... oldcsp clos :csp ret ...)
	.csp swp get swp .stp swp set ; reset stack index
	.stp swp pop swp .return_ret swp set ; store ret addr
	.stp swp pop pop swp .csp swp set ; remove closure, reset stack frame
	:return_ret '0 jmp

:getptr ; (... arg ret)
	.stp swp pop swp '6 add swp .getptr_ret swp set
	.stp swp pop psh swp '7 and swp '5 xor cnd '1 cnd .getptr_err jmp
	.stp swp pop swp 'x33 swp sft swp get swp .retval swp set
	:getptr_ret '0 jmp :getptr_errmsg "invalid fncptr!" '10 '0
	:getptr_err .stp swp .getptr_errmsg psh '2 psh .printstr jmp

:memcpy ; (... to from size ret) - works
	; could prolly use pointer trickery to get this done even neater
	; specifically, the *dst=*src,dst++,src++ could use psh/pop instead of
	;  get/set - iow *dst++=*src++
	.stp swp pop swp '6 add swp .memcpy_ret swp set
	.stp swp pop swp .memcpy_num swp set ; init counters
	.stp swp pop swp .memcpy_src swp set
	.stp swp pop swp .memcpy_dst swp set
	:memcpy_num '0 cnd :memcpy_ret '0 jmp ; loop: if size==0 return
	:memcpy_src '0 swp get swp :memcpy_dst '0 swp set ; *dst=*src
	.memcpy_src swp get swp '1 add swp .memcpy_src swp set ; src++
	.memcpy_dst swp get swp '1 add swp .memcpy_dst swp set ; dst++
	.memcpy_num swp get swp '1 swp sub swp .memcpy_num swp set ; num--
	.memcpy_num jmp ; goto loop

:builtin_eq ; (... arg1 arg2 ret) - works
	.stp swp pop swp .b_eq_ret_addr swp set ; store ret addr
	.stp swp pop swp .b_eq_slf swp set ; selfmod arg
	.stp swp pop swp :b_eq_slf '0 sub swp .retval swp set ; .retval=diff
	.stp swp :b_eq_ret_addr '0 psh .predret jmp ; belay to predret

:tagnum ; (... val ret) - works
	.stp swp pop swp '6 add swp .tagnum_ret swp set
	.stp swp pop swp 'x20 swp sft swp '2 xor swp .retval swp set
	:tagnum_ret '0 jmp

:builtin_add ; (... arg ... argnum ret) - works
	; could use .retval to store intermediaries - see .b_mlt2
	.stp swp pop swp .b_add_ret_addr swp set ; store retaddr
	.stp swp pop swp .b_add_anum swp set ; store argnum
	.b_add_res swp '0 set ; init res=0 XXX retval
	:b_add_anum '0 cnd .b_add_ret jmp ; loop:if!argnum goto b_add_ret
	.b_add_anum swp get swp '1 swp sub swp .b_add_anum swp set ; anum--
	.stp swp pop psh swp '3 and swp '2 xor cnd '1 cnd .invarg jmp
	.stp swp pop swp '2 swp sft swp .b_add_inc swp set ; inc=pop()
	.b_add_res swp get swp :b_add_inc '0 add swp .b_add_res swp set ; magic
	.b_add_anum jmp ; goto loop
	:b_add_ret .stp swp :b_add_res '0 psh :b_add_ret_addr '0 psh .tagnum jmp

:builtin_sub ; (... a b ret) - seems to work?
	.stp swp pop swp .b_sub_ret swp set ; store retaddr
	.stp swp pop psh swp '3 and swp '2 xor cnd '1 cnd .invarg jmp
	.stp swp pop swp '2 swp sft swp .b_sub_shd swp set
	.stp swp pop psh swp '3 and swp '2 xor cnd '1 cnd .invarg jmp
	.stp swp pop swp '2 swp sft swp :b_sub_shd '0 swp sub swp .stp swp psh
	:b_sub_ret '0 psh .tagnum jmp

:builtin_mlt2 ; (... arg1 arg2 ret) - works
	.stp swp pop swp .b_mlt2_ret swp set ; store retaddr
	.stp swp pop psh swp '3 and swp '2 xor cnd '1 cnd .invarg jmp
	.stp swp pop swp 'x2 swp sft swp .b_mlt2_loop swp set
	.stp swp pop psh swp '3 and swp '2 xor cnd '1 cnd .invarg jmp
	.stp swp pop swp 'x2 swp sft swp .b_mlt2_arg swp set
	.retval swp '0 set
	:b_mlt2_loop '0 cnd .b_mlt2_tag jmp
	swp '1 swp sub swp .b_mlt2_loop swp set
	.retval swp get swp :b_mlt2_arg '0 add swp .retval swp set .b_mlt2_loop jmp
	;:b_mlt2_tag .stp swp :b_mlt2_ret '0 psh .tagnum jmp
	:b_mlt2_tag .retval swp get swp .stp swp psh
		:b_mlt2_ret '0 psh .tagnum jmp

:builtin_mlt ; (... arg ... argnum ret) XXX dont work?
	.stp swp pop swp '6 add swp .b_mlt_ret_addr swp set ; store retaddr
	; if !argnum ret 1
	.retval swp '6 set  .stp swp pop cnd .b_mlt_ret_addr jmp
	; if argnum==1 ret arg
		swp '1 swp sub cnd .b_mlt_ret1 jmp
		swp '1 add swp .b_mlt_loop swp set ; set counter to argnum
		;swp .b_mlt_loop swp set ; set counter to argnum
	:b_mlt_loop '0 cnd .b_mlt_ret jmp ; if !cnt return
	swp '1 swp sub swp .b_mlt_loop swp set ; cnt--
	.retval swp get swp .stp swp psh
	'0 swp get swp .stp swp psh .builtin_mlt2 jmp .b_mlt_loop jmp
	:b_mlt_ret1 .stp swp pop swp .retval swp set .b_mlt_ret_addr jmp
	;:b_mlt_ret .retval swp get swp .stp swp psh
	;	:b_mlt_ret_addr '0 psh .tagnum jmp
	:b_mlt_ret :b_mlt_ret_addr '0 jmp

:builtin_set ; (... val loc ret) XXX test
	.stp swp pop swp '6 add swp .b_set_ret swp set
	.stp swp pop swp .b_set_slf swp set
	.stp swp pop swp :b_set_slf '0 set
	:b_set_ret '0 jmp

:builtin_car ; (... arg ret) - works XXX check tags
	.stp swp pop swp '6 add swp .b_car_ret swp set
	.stp swp pop psh swp '3 and cnd '1 cnd .invarg jmp
	.stp swp pop swp 'x12 swp sft swp get
	swp .retval swp set :b_car_ret '0 jmp

:builtin_cdr ; (... arg ret) - works XXX check tags
	.stp swp pop swp '6 add swp .b_cdr_ret swp set
	.stp swp pop psh swp '3 and cnd '1 cnd .invarg jmp
	.stp swp pop swp 'x12 swp sft swp '1 add swp get
	swp .retval swp set :b_cdr_ret '0 jmp

:malloc ; (... arg ret) - works, but looks a bit ugly
	; note that this returns untagged address (multiple of 8)
	.stp swp pop swp '6 add swp .malret swp set
	; if no memory demanded, we return brk XXX or nil?
	.hap swp get swp .retval swp set ; set return value ; below reuses .acc
	.stp swp pop cnd .malret jmp psh
	swp '7 and cnd .mal_add jmp .malinc swp '8 set ; if arg&7 inc=8
	:mal_add .stp swp pop swp 'x33 swp sft swp ; clear lowest 3 bits
		:malinc '0 add swp .malval swp set ; add optional increment
	.malinc swp '0 set ; reset increment
	.hap swp get swp :malval '0 swp sub swp .hap swp set swp .retval swp set
	:malret '0 jmp

:makecons ; (... car cdr ret) - works
	.stp swp pop swp '6 add swp .makecons_ret swp set
	.stp swp pop swp .makecons_cdr swp set
	.stp swp pop swp .makecons_car swp set
	.stp swp '2 swp psh '0 swp get swp .stp swp psh .malloc jmp
	.retval swp get swp :makecons_car '0 set '1 add swp :makecons_cdr '0 set
	; no need to retag - malloc guarantees lowest bits are 000
	:makecons_ret '0 jmp

:makevec ; (... args ... argnum ret) - works
	.stp swp pop swp '6 add swp .makevec_ret swp set
	.stp swp pop psh swp .makevec_num swp set ; copy argnum malloc/memcpy
	swp '3 swp cnd '0 jmp; if !argnum hcf XXX or ret 0?
	'0 swp get swp .stp swp psh .malloc jmp ; call malloc
	.retval swp get swp .stp swp psh psh ; once for memcpy, once for return
	.stp swp get swp :makevec_num '0 swp sub swp
		'1 swp sub swp .stp swp psh ; *args
	.makevec_num swp get swp .stp swp psh ; argnum (annoying, i know)
	'0 swp get swp .stp swp psh .memcpy jmp ; defer to memcpy to fill vector
	.stp swp pop swp 'x33 swp sft swp '1 xor swp .retval swp set ; tag
	; pop values from stack
	.makevec_num swp get swp .makevec_rem swp set
	:makevec_rem '0 cnd .makevec_ret jmp
	swp '1 swp sub swp .makevec_rem swp set
	.stp swp pop .makevec_rem jmp
	:makevec_ret '0 jmp

:getvec ; (... vec at ret) - works
	; untagged variant used by compiler XXX merge?
	.stp swp pop swp '6 add swp .getvec_ret swp set
	.stp swp pop swp .getvec_at swp set
	;.stp swp pop psh swp '7 and swp '1 xor cnd '1 cnd .invarg jmp
	.stp swp pop psh swp '1 and cnd .invarg jmp ; *any* vector type
	.stp swp pop swp 'x33 swp sft swp :getvec_at '0 add swp get
	swp .retval swp set :getvec_ret '0 jmp

:setvec ; XXX

:makeclos ; (... funcptr size ret)
	.stp swp pop swp '6 add swp .makeclos_ret swp set
		.stp swp pop psh swp .addclos_num swp set ; oh this feels dirty...
	'0 swp get swp .stp swp psh .malloc jmp ; call malloc w/ argnum
	.stp swp pop swp .makeclos_val swp set ; fetch funcptr
	.retval swp get swp :makeclos_val '0 set ; set funcptr
		.addclos_clos swp set ; ugly hack strikes again!
	swp '5 ior swp .retval swp set ; so we can push it for binding
	:makeclos_ret '0 jmp

:addclos ; (... args[] numargs ret)
	.stp swp pop swp '6 add swp .addclos_ret swp set
	.stp swp get swp :addclos_num '0 swp sub swp '2 add swp .addclos_dst swp set
	:addclos_clos '0 swp '1 add swp .stp swp psh ; set by .makeclos
	:addclos_dst '0 psh .addclos_num swp get swp .stp swp psh
	'0 swp get swp .stp swp psh .memcpy jmp
	.addclos_dst swp get swp '1 swp sub swp .stp swp set ; clean up stack
	.stp swp pop swp .retval swp set ; pop closure, set retval
	:addclos_ret '0 jmp

:makestr ; calls malloc then retags XXX test
	.stp swp pop swp '6 add swp .makestr_ret swp set
	.stp swp pop psh swp '3 and cnd '1 cnd .invarg jmp
	.stp swp pop swp '2 swp sft swp .stp swp psh
	'0 swp get swp .stp swp psh .malloc jmp ; call malloc w/ arg
	.retval swp get swp '2 xor swp .retval swp set
	:makestr_ret '0 jmp

:strat ; (... str ind ret) XXX test
	.stp swp pop swp .strat_ret swp set
	.stp swp pop psh swp '3 and cnd '1 cnd .invarg jmp
	.stp swp pop swp '2 swp sft swp .strat_inc swp set
	.stp swp pop psh swp '7 and swp '3 xor cnd '1 cnd .invarg jmp
	.stp swp pop swp '3 xor swp :strat_inc '0 add swp get
	swp .stp swp psh :strat_ret '0 psh .tagnum jmp

:strset ; (... str ind val ret) XXX test
	.stp swp pop swp '6 add swp .strset_ret swp set
	.stp swp pop psh swp '3 and cnd '1 cnd .invarg jmp
	.stp swp pop swp '2 swp sft swp .strset_val swp set
	.stp swp pop psh swp '3 and cnd '1 cnd .invarg jmp
	.stp swp pop swp '2 swp sft swp .strset_ind swp set
	.stp swp pop psh swp '7 and swp '3 xor cnd '1 cnd .invarg jmp
	.stp swp pop swp '3 xor swp :strset_ind '0 add swp :strset_val '0 set
	.retval swp '0 set :strset_ret '0 jmp

; ---

;:sc_data '10 "compiler tests passed" '10 '0 :hw "Hello, World!" '10 '0
:main ;'0 swp '0 jmp
	;.stp swp '5 psh psh '2 psh  '0 swp get swp .stp swp psh .builtin_mlt jmp
	;.retval swp get swp .stp swp psh
	;'0 swp get swp .stp swp psh .printnum jmp '10 out
