"general: 5 a 50 8064 6 (1 2 84 4 96) 7 5 (120 120 120 120)"
(+ 2 3) (defun a 42) (+ a 8)
(begin (set a 84) (set b 96) (* a b))
(let ((a 2) (b 3)) (* a b))
(list 1 2 a 4 b)
(begin (defun f (lambda (x y) (+ x (* 2 y)))) (f 3 2))
(begin (defun g (lambda (x) (lambda (y) (+ x y)))) ((g 2) 3))
(begin
	(defun fac (lambda (x) (if (eq x 0) 1 (* x (fac (- x 1))))))
	(defun factail (lambda (x)(
		(lambda (f) (f f x 1)) ; this time w/ y-combinator for tail recursion
		(lambda (f x res) (if
			(eq x 0) res
			(f f (- x 1) (* x res)))))))
	(defun faclet (lambda (x) (let
		((f (lambda (x res) (if (eq x 0) res (f (- x 1) (* x res))))))
		(f x 1) )))
	(defun facdef (lambda (x)
		(defun f (lambda (x res) (if (eq x 0) res (f (- x 1) (* x res)))))
		(f x 1)))
	(list (fac 5) (factail 5) (faclet 5) (facdef 5)))



"string stuff"

(defun range (lambda (from to) (if (eq from to) ()
	(cons from (range (+ from 1) to)))))

(defun iter (lambda (func list) (if list
	(begin (func (car list)) (iter func (cdr list))))))

(let ((stra "hello  world")) (str-at stra 4) (str-set stra 5 44) stra)

(let ((defun strb (str 11)))
	(iter (lambda (x) (str-set strb x (+ x 97))) (range 0 10)) strb)



"dot,quote,vararg - ((1 2.3)4.5) b c err,332nil 9520"
'((1 2 . 3) 4 . 5)
;(quote (blafa 'bla '(bla bleh) blop) beh) 'a '(a b c)
(defun b (lambda (x . y) (if y (car y) x)))
(defun c (lambda x
	(defun sum (lambda (x) (if x (+ (car x) (sum (cdr x))) 0)))
	(if x (sum x) 0)))
(list (b 2 3 4) (b 2 3) (b 2) (b))
(list (c 2 3 4) (c 2 3) (c 2) (c))



"macro stuff - 5,1 mycond 6 9 nil expand 9"
(let ((infix (macro (a b c) (list b a c))))
	(list (infix 2 + (+ 1 1 1)) (infix 1 quote 2)))

(defun mycond (macro x (defun f (lambda (x)
	(if x (list if (car (car x)) (cons begin (cdr (car x))) (f (cdr x)) ))
	))(f x)))

(mycond ((eq 2 3) (+ 2 3)) (1 (* 2 3)))
(mycond ((eq 3 3) (+ 2 3) (+ 4 5)) (1 (* 2 3)))
(mycond ((eq 2 3) (+ 2 3)) )

(defun expand (macro (fnc args) (cons fnc args)))
(expand + (2 3 4)) ; ok damn this is POWERFUL



"set globenv from local"
; XXX this *might* break if its not actually globenv
(let ((a ()) (conj (lambda (x) (set a (cons x a)))))
	(iter conj '(0 1 2)) (print a)
	(iter conj '(3 4 5)) a)

"ack(2,3)=?"
(begin
	(defun ack (lambda (x y) (cond
		((eq x 0) (+ y 1))
		((eq y 0) (ack (- x 1) 1))
		('t (ack (- x 1) (ack x (- y 1))))
	)))
	(ack 2 3))

(quote "oop stuff")

(defun env (lambda (val) (lambda (opr . arg) (case opr
	('set (set val (car arg)) ()) ('get val) ))))
(let
	((e1 (env '(1 2 3))))
	(let ((f (lambda (x) (x 'set '(4 5 6))))) (f e1))
	(e1 'get))
