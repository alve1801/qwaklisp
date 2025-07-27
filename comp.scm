; metacircular lisp compiler ala ghuloum (attempt the second)



; ~~~ compatibility redefines ~~~

(defun eq? eq) (defun symb? atom) (defun num? num) (defun pair? pair)
(defun set! set) (defun nil? (lambda (x) (eq x ()))) (defun 't 1)
(defun vec? (lambda () ())) (defun clos? (lambda () ()))



; ~~~ funcprog helpers ~~~

(set! range (lambda (from to) (if (eq? from to) ()
	(cons from (range (+ from 1) to)))))
(set! map (lambda (func list) (if (pair? list)
	(cons (func (car list)) (map func (cdr list))) )))
(set! iter (lambda (func list) (if (pair? list)
	(begin (func (car list)) (iter func (cdr list))) )))
(set! iters (lambda (func list) (if (pair? list)
	(begin (func (car list)) (iters func (cdr list)))
	(if list (func list)) )))
(set! fold (lambda (f x e) (if x (f (car x) (fold f (cdr x) e)) e)))
(set! len (lambda (list) (if list (+ 1 (len (cdr list))) 0)))
(set! concat (lambda (la lb) (if la
	(cons (car la) (concat (cdr la) lb)) lb)))
(set! enums (lambda (x s) ((lambda (f) (f f x s))
	(lambda (f x at) (if x (cons (cons (car x) at) (f f (cdr x) (+ at 1))))))))
(set! enum (lambda (x) (enums x 0)))
(set! filter (lambda (func list) (if list (if (func (car list))
	(cons (car list) (filter func (cdr list))) (filter func (cdr list))))))

(set! and (lambda x (defun f (lambda (x)
	(if x (if (car x) (f (cdr x)) ()) 't))) (f x)))
(set! or  (lambda x (defun f (lambda (x)
	(if x (if (car x) 't (f (cdr x))) ()))) (f x)))
(set! not (lambda (x) (if x () 't)))



; ~~~ io helpers ~~~

(set! curloc 0)
(set! getch (lambda () (set! curloc (+ curloc 1)) (read (- curloc 1))))
(set! putch (lambda (val) (write curloc val) (set! curloc (+ curloc 1)) ()))
(set! putstr (lambda (x) (defun f (lambda (at) (defun c (str-at x at))
	(if (eq c 0) () (begin (putch c) (f (+ at 1)))))) (f 0) ))

(set! emit-wrap (lambda (arg) (iters (lambda (x) (cond
	((nil? x) ()) ((symb? x) (putstr x) (putch 32))
	((num? x) (putch 39) (putstr (itoa x)) (putch 32))
	((pair? x) (putch 40) (emit-wrap x) (putch 41))
	)) arg) ()))
(set! emit (lambda x (emit-wrap x) (putch 59) (putch 10)))
(set! debug 't) ; whether to output helper comments
(set! dpr (lambda x (if debug
	(begin (putch 10) (emit-wrap x) (putch 59) (putch 10)))))



; ~~~ asm helpers ~~~

; 'call subroutine'
(set! goto (lambda (x) (emit "'0 swp get swp .stp swp psh" x "jmp") ()))
; 'push return value to stack'
(set! pushret (lambda () (emit ".retval swp get swp .stp swp psh") ()))
(set! curlabel 0) ; 'give me a new label (dot by default)'
(set! newlabel (lambda () (defun retval (str 8))
	(iter (lambda (x) (str-set retval (cdr x) (car x)))
		(enum (list 46 108 98 108 ; 58
			(+ (/ curlabel 100) 48)
			(+ (% (/ curlabel 10) 10) 48)
			(+ (% curlabel 10) 48)  0)))
	(set! curlabel (+ curlabel 1)) retval))
; 'make this a location/reference label'
(set! relabel-dot (lambda (x) (str-set x 0 46) x)) ; '.'
(set! relabel-loc (lambda (x) (str-set x 0 58) x)) ; ':'



; ~~~ quotation, ie symbol passing ('Atomic Passthrough Assemblage') ~~~

(set! enquote (lambda (expr) (if expr (if (symb? expr) ; works
	(begin (emit ".stp swp")
		(defun str-iter (lambda (at) (defun c (str-at expr at))
			(if (eq c 0) (emit at "psh")
				(begin (emit c "psh") (str-iter (+ at 1))))))
		(str-iter 0) (goto ".makeatom"))
	(begin ; this one's easy
		(enquote (car expr)) (pushret)
		(enquote (cdr expr)) (pushret)
		(goto ".makecons") ))
	(emit ".retval swp '0 set") ) ())) ; nil, for lists



; ~~~ variable dereferencing ~~~

(set! get-bind (lambda (var env) (cond
	((nil? env) ()) ((eq? (car (car env)) var) (cdr (car env)))
	('t (get-bind var (cdr env))))))

(set! wrapenv (lambda (env clos si) ; hell yeah baby were doing oop!
	;(print (list "new env" si))
	(lambda (opr . arg) (case opr
	('getsi si)
	('inc (set! si (+ si (car arg))))
	('dec (set! si (- si (car arg))))
	('addbind (set! si (+ si 1)) (set! env (cons (cons (car arg) si) env)))
	('getenv (get-bind (car arg) env))
	('getclos (get-bind (car arg) clos))
	('cpy (wrapenv env clos si)) ))))

; defers vars. returns nil if found, else symbol (for eg builtins)
; if found, also takes care of emitting code to put value in .retval
(set! eval (lambda (expr env) (let (
		(valenv  (env 'getenv  expr))
		(valclos (env 'getclos expr)))
	(cond
		(valenv  (emit ".csp swp get swp" valenv "add swp get"
			"swp .retval swp set") ()) ; looks good
		(valclos (emit ".csp swp get swp '1 swp sub swp get swp"
			"'x33 swp sft swp" valclos "add swp get") ; XXX check closure tag?
			(emit "  swp .retval swp set") ()) ; for 80c alignment of output
		('t expr))))) ; fallthrough



; ~~~ lambda (pre)processing ~~~

(set! getfreevars (lambda (expr args) (let (
	(contains? (lambda (lst item) (cond ; is item in set
		((nil? lst) ()) ((eq? (car lst) item) 't)
		('t (contains? (cdr lst) item)))))
	(additem (lambda (lst item) (cond ; add item to set
		((nil? lst) (cons item ())) ((eq? item (car lst)) lst)
		('t (cons (car lst) (additem (cdr lst) item))))))
	(join (lambda (x y) (if x (if (pair? x)
		(join (cdr x) (additem y (car x))) (additem y x)) y)))
	(bsmb ; bulitin symbols XXX make sure we got all that comp supports!
		'(t defun lambda cond eq? car cdr cons quote + - * / %
		begin set! if case write read let close str str-at str-set
		num? bool? nil? vec? str? clos? pair?))
	(arglist (lambda (args) (lambda (opr . arg) (case opr
		('add (set! args (additem args (car arg))))
		('addl (set! args (join args (car arg))))
		('has (contains? args (car arg)))
		('cpy (arglist args)) ))))

	(gfv (lambda (expr args)
		(cond ((nil? expr) ()) ((num? expr) ())
		((symb? expr) (if (args 'has expr) () expr))
		((eq? (car expr) 'lambda) ; XXX will break on varargs
			(args 'addl (car (cdr expr))) (gfv (cdr (cdr expr)) args))
		((or (eq (car expr) 'set!) (eq (car expr) 'defun))
			(args 'add (car (cdr expr))) (gfv (cdr (cdr expr)) args))
		((eq (car expr) 'let)
			(defun newargs (args 'cpy))
			(newargs 'addl (map car (car (cdr expr))))
			(fold join ; yikes
				(map (lambda (x) (gfv (cdr x) newargs)) (car (cdr expr)))
				(gfv (cdr expr) newargs)))
		('t (join (gfv (car expr) args) (gfv (cdr expr) args))) )))
	) (filter (lambda (x) (not (contains? bsmb x))) (gfv expr (arglist args)))
)))



; ~~~ compilation ~~~

; does not handle .retval - all subexprs set it, each overwriting the previous
; XXX tail calls here? XXX defuns gon get complicated
(defun compile ()) ; forward declaration
(set! compile-iter (lambda (expr env)
	(iter (lambda (x) (compile x env)) expr) ()))

(defun builtins ()) ; forward declaration
(set! compile (lambda (expr env) (cond
	; constants - encode and return
	((num?  expr) (emit ".retval swp" (+ (* expr 4) 2) "set"))
	((nil?  expr) (emit ".retval swp '0 set"))
	((vec?  expr) (emit "'4 swp '0 jmp")) ; runtime heap objs not
	((clos? expr) (emit "'4 swp '0 jmp")) ;  handled by compiler

	((symb? expr) (let
		((retval (eval expr env))) ; handles fetch to .retval
		(if retval (enquote retval)))) ; handles self-evaluating symbols

	((pair? expr)
		(if (if (symb? (car expr)) ; it works, mothafucka!
			; if builtin, deref to corresponding handler, else eval sets .retval
			(let ((fnc (eval (car expr) env)))
				(if fnc (begin (builtins fnc (cdr expr) env) ()) 't))
			; if not a symbol, compile then call
			(begin (compile (car expr) env) 't))
		; if neither symbol nor builtin, call func (ptr or clos) from .retval
		(let ((retaddr (newlabel)) (tmpenv (env 'cpy))) (dpr "; closure call")
			(emit ".csp swp get swp .stp swp psh") ; push current stack frame ptr
			(pushret) ; push closure
			(emit retaddr "psh") ; push retaddr
			(tmpenv 'inc 3) (iter ; compile args
				(lambda (x) (compile x tmpenv) (pushret) (tmpenv 'inc 1))
				(cdr expr))
			(dpr "; finish closcall")
			(emit ".csp swp get swp" (+ (env 'getsi) 2)
				"add swp get swp .stp swp psh") ; refetch closure
			(goto ".getptr") ; get fncptr jmpaddr from closure
			(emit ; move .csp to return addr, then jump XXX use numargs?
				".stp swp get swp" (len (cdr expr)) "swp sub swp .csp swp set"
				".retval swp get jmp" (relabel-loc retaddr)) ))) ; set retaddr

	; if nothing else works, hcf
	('t (emit "'4 swp '0 jmp"))) ()))



(set! builtins (lambda (op args env) (dpr "; builtin" op) (case op

	('begin (compile-iter args env)) ; works

	('defun (if (or (get-bind (car args) env) (get-bind (car args) clos))
		(builtins 'set! args env) (begin ; defer if binding exists XXX set should
			(env 'addbind (car args)) ;       defer to defun, not this!
			(compile-iter (cdr args) env) (pushret) )))

	('set! (compile (cdr args) env) (pushret) (let (
				(valenv  (env 'getenv  expr))
				(valclos (env 'getclos expr)))
			(cond
				(valenv (emit ".csp swp get swp" valenv "add swp .stp swp psh"))
				(valclos (emit ".csp swp get swp '1 swp sub swp get swp"
					"'x33 swp sft swp" valclos "add swp .stp swp psh"))
				('t (emit "'2 swp '0 jmp"))) ; XXX or quote?
			(goto ".builtin_set")))

	('let (defun newenv (env 'cpy)) ; technically 'let* XXX bind *all* then set?
		(iter (lambda (x) (newenv 'addbind (car x))
				(compile-iter (cdr x) newenv) (pushret)
			) (car args))
		(compile-iter (cdr args) newenv)
	)

	; this one was a nightmare
	('lambda (let ((vars (getfreevars (cdr args) (car args)))
			(funclbl (newlabel)) (skiplbl (newlabel)))
		; create binding
		(emit ".stp swp" funclbl "psh" (+ (len vars) 1) "psh")
			(goto ".makeclos") (pushret)
		; eval freevars
		(iter (lambda (x) (if (eval x env) (emit ".stp swp '0 psh")
			(pushret))) vars) (goto ".addclos")
		; compile function code
		(emit skiplbl "jmp" (relabel-loc funclbl))
		(compile-iter (cdr args) (wrapenv (enums (car args) 1)
			(enums vars 1) (len (car args))))
		(emit ".return jmp" (relabel-loc skiplbl))))

	('if (let ((iftrue (newlabel)) (iffalse (newlabel)))
		(compile (car args) env)
		(emit ".retval swp get cnd" iffalse "jmp")
		(compile (car (cdr args)) env)
		(emit iftrue "jmp" (relabel-loc iffalse))
		(if (car (cdr (cdr args)))
			(compile (car (cdr (cdr args))) env)
			(emit ".retval swp '0 set"))
		(emit (relabel-loc iftrue))))

	('cond (let ((endlabel (newlabel)))
		(iter (lambda (x) (defun skipcur (newlabel))
			(dpr "; conditional") (compile (car x) env)
			(emit ".retval swp get cnd" skipcur "jmp")
			(compile-iter (cdr x) env)
			(emit endlabel "jmp" (relabel-loc skipcur))
		) args) (emit ".retval swp '0 set" (relabel-loc endlabel))))

	('case (let ((endlabel (newlabel))) (compile (car args) env) (pushret)
		(defun tmpenv (env 'cpy)) (tmpenv 'inc 2) ; easier
		(iter (lambda (x) (defun skipcur (newlabel))
			(emit ".stp swp pop psh psh") ; duplicate top of stack
			(compile (car x) tmpenv) (pushret)
			(goto ".builtin_eq") ; XXX or nil
			(emit ".retval swp get cnd" skipcur "jmp .stp swp pop")
			(compile-iter (cdr x) env)
			(emit endlabel "jmp" (relabel-loc skipcur))
		)(cdr args))
		(emit ".stp swp pop .retval swp '0 set" (relabel-loc endlabel))))

	('str (compile (car args) env) (pushret) (goto ".makestr"))
	('str-at
		(compile (car args) env) (pushret) (env 'inc 1)
		(compile (car (cdr args)) env) (pushret) (env 'dec 1)
		(goto ".strat"))
	('str-set (compile (car args) env) (pushret) (env 'inc 1)
		(compile (car (cdr args)) env) (pushret) (env 'inc 1)
		(compile (car (cdr (cdr args))) env) (pushret) (env 'dec 2)
		(goto ".strset"))

	('+ (let ((numargs '0) (tmpenv (env 'cpy))) (iter (lambda (x)
			(compile x tmpenv) (pushret) (tmpenv 'inc 1)
			(set! numargs (+ numargs 1))
		)args) (emit ".stp swp" numargs "psh") (goto ".builtin_add")))

	('* (let ((numargs '0) (tmpenv (env 'cpy))) (iter (lambda (x)
			(compile x tmpenv) (pushret) (tmpenv 'inc 1)
			(set! numargs (+ numargs 1))
		)args) (emit ".stp swp" numargs "psh") (goto ".builtin_mlt")))

	('- (let ((numargs '0) (tmpenv (env 'cpy)))
		(compile (car args) env) (pushret) (tmpenv 'inc 1)
		(iter (lambda (x)
			(compile x tmpenv) (pushret) (tmpenv 'inc 1)
			(set! numargs (+ numargs 1))
		) (cdr args)) (emit ".stp swp" numargs "psh")
		(goto ".builtin_add") (pushret) (goto ".builtin_sub")))

	; XXX mod div etc

	('car (compile (car args) env) (pushret) (goto ".builtin_car"))

	('cdr (compile (car args) env) (pushret) (goto ".builtin_cdr"))

	('cons
		(compile (car args) env) (pushret) (env 'inc 1)
		(compile (car (cdr args)) env) (pushret) (env 'dec 1)
		(goto ".makecons"))

	('quote (enquote args))

	('list (emit "'1 swp '0 out")) ; XXX lol

	; builtin predicates, defer to predret (.retval=0 iff condition true)
	; XXX can we use a macro or smth? istg
	('nil? (compile (car args) env) (goto ".predret"))
	('eq?
		(compile (car args) env) (pushret) (env 'inc 1)
		(compile (car (cdr args)) env) (pushret) (env 'dec 1)
		(goto ".builtin_eq"))
	('num?
		(compile (car args) env)
		(emit ".retval swp get swp '3 and swp '2 xor"
			"swp .retval swp set")(goto ".predret"))
	('pair?
		(compile (car args) env)
		(emit ".retval swp get swp '3 and"
			"swp .retval swp set")(goto ".predret"))
	('vec?
		(compile (car args) env)
		(emit ".retval swp get swp '7 and swp '1 xor"
			"swp .retval swp set")(goto ".predret"))
	('str?
		(compile (car args) env)
		(emit ".retval swp get swp '7 and swp '3 xor"
			"swp .retval swp set")(goto ".predret"))
	('clos?
		(compile (car args) env)
		(emit ".retval swp get swp '7 and swp '5 xor"
			"swp .retval swp set")(goto ".predret"))
	('err? ; not used, but maybe convenient
		(compile (car args) env)
		(emit ".retval swp get swp '7 and swp '7 xor"
			"swp .retval swp set")(goto ".predret"))

	; fallthrough - hcf
	(() (print (list "unknown command: <" op ">")) (emit "'1 swp '0 jmp")))))

(set! comp (lambda (expr)
	(compile expr (wrapenv () () 0))
	(dpr "; global return") ; XXX assumes return value is numeric
	(emit ".retval swp get swp .stp swp psh") (goto ".printnum")
	(emit "'10 out '0 swp '0 jmp :end")))



; ~~~ test ~~~

(comp '(let ((ack
	(lambda (x y) (cond
		((eq? x 0) (+ y 1))
		((eq? y 0) (ack (- x 1) 1))
		(1 (ack (- x 1) (ack x (- y 1))))
	))
)) (ack 3 3)))
