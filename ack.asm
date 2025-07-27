; ack(2,3)=9
;math:
;  a(0,n)=n+1
;  a(m+1,0)=a(m,1)
;  a(m+1,n+1)=a(m,a(m+1,n))
;stack:
;  0,n -> n+1
;  m,0 -> m-1,1
;  m,n -> m-1,m,n-1
;pseudocode:
;  input two args, loop:
;  pop a, if !a, pop a, push --a, push 1, goto loop
;  pop b, if !b, push ++a, if stack==1 exit, goto loop
;  push --b, push ++b, push --a, goto loop

.ack '0 '0 ; init

:ack ; main loop
.stp swp pop cnd .zero jmp ; pop a, if !a goto .zero
swp .tmp swp set .stp swp pop cnd .less jmp ; tmp=a, pop b, if !b goto .less
; (... m n) -> (... m-1 m n-1)
swp '1 swp sub swp .stp swp psh  swp '1 add swp .stp swp psh ; psh--b, psh++b
.tmp swp get swp '1 swp sub swp .stp swp psh   .ack jmp ; push --a, goto loop

:zero ; (... m 0) -> (... m-1 1)
pop swp '1 swp sub swp .stp swp psh '1 psh .ack jmp

:less ; (... 0 n) -> (... n+1) - if stack<2, goto print
.tmp swp get swp '1 add swp .stp swp psh
get sub swp '1 sub cnd .print jmp .ack jmp

; output then halt
:print .stp swp '1 add swp get swp "0" add out '10 out '0 jmp

; data
:tmp '0 :stp .stack_top '2 :stack_top '3
