# Self-hosting Lisp VM

subprojects: vm emulator, assembler, interpreter, compiler (asm/scm)

---

## VM Emulator

shared memory, 16bit words, dynamic stacks, regs are pc/acc/opr
commands are 0xfffX, everything else sets .acc to itself (ala HACK A-mode)
we have some debug limits on execution/sizes for testing, remove those in prod

jmp cnd get set - cnd skip if acc ('if0 jmp') (".val cnd '1 cnd .addr jmp")
and ior xor sft - aac>>low, aac<<high (ala UXN)
add sub swp out - get/set acc~mem[opr]
idk idc pop psh - mem[opr] used as stack pointer (autoinc-/-decrement)

suggestions:
- reorder: jmp cnd idk idc get set pop psh and ior xor sft add sub swp out
- swap regs for memory commands - we use `swp` a *lot*
- io modes - .acc is value, .opr tells us what to do w/ it (ala syscalls)

---

## Assembler

compiles for the vm, same isa, no local labels
linked list to keep track of labels, delays values if needed
written in c because easily interoperable at the current stage
- rewrite in asm once vm usable?

asm syntax:
- three-letter mnemonics as in vm doc
- `:label` sets label for following word
- `.label` inserts label value (ie location of labeled word)
- `'const` to input decimal constant, `'x` for hex, `'b` for bin
- `"..."` puts text between quotes as ascii vals
- stuff separated via spaces, `;` is comment till end of line

suggestions:
- strcmp is *very* hacky, come up w/ smth better
- might wanna copy parser from the interpreter
- `[int]` for padding? alignment?

---

## notes on continuations

easier in compiled code, since it simplifies to copying stack to heap

delimiting should make them a *lot* nicer to use - otherwise they implicitly
 capture to repl, and that gets messy
*nested* continuations would then be messy, but im sure we can come up w/ a
 workaround. tags maybe, so we can match?
also, not as general, but should still be pretty usable
welp, guess r5rs will be even *less* relevant for this...

how the fuck do i implement them in an interpreter?
cps seems to be a thing, but it requires transforming the code a lot and also
 wont cooperate well w/ existing codebase
could be done by manipulating expressions directly, but thats a bit ugly - and
 *also* doesnt cooperate w/ current calling conventions
alexis king had a talk abt this that was kinda helpful...



---

## Interpreter

notes on this at bottom of implementation file - its a lot

tags: pair num symb vec
doesnt implement vectors - that one is for compat w/ compiler



---

## Compiler

pair num vec str cls err - tagged in pointers
 00  10  001 011 101 111

regs: retval, stp (stack pointer), csp (stack frame pointer), hap (heap)
- local vars stored on stack, freevals in closures (vector-type) on heap
- closures put on stack in calls so we know how to reference them
- heap pointers are 8-word aligned (for tagging)

to call (lisp):
- push .csp, closure, retaddr, formargs
- move frame index to return addr, then jmp

to call (asm):
- push args, argnum (if vararity), retaddr, jmp

error codes (stored in .opr reg during hcf, vm does the right thing):
0. regular exit (no error)
1. nonexistent/unimplemented primitive/function (called unbound symbol)
2. unbound variable (`set` or failed/incorrect dereference)
3. invalid argument (probably a tag issue) (this one is *annoying*)
4. unknown operand (tried compiling something that wasnt code)
5. invalid operand (tried *calling* something that wasnt closure or number)

todo:
- type-generic .print
- strings/vectors
 - test strings!
- mcirc, for macro preprop - put in separate subproject file
- better io - depends on ports being implemented in interpreter (ig?)
- assember, parser - separate, depend on ports
- test atomic passthrough
- proper tailcalls
- garbage collector - figure out heap/globenv first
 - vector types dont store length (nor refcount)
 - two power best fit ll-ll
 - requires a `.free`

bootstrapping requires scm interfacing w/ asm. can be hacky - only needed once

a closure implicitly has a pointer to itself, since we have to store one in
 the closure obj. can we use that to accomplish (tail) recursion?
i think the issue is that then wed have to be keeping track (in the compiler)
 of function names (well, identities), and that gets *complicated*

vector bindings and primitives - makevec/getvec assume initlists (shouldnt)

optimisations:
- constant eliminations in lambda preprocessing
- bytecode intermediary - 'push val from, pop val to' can be improved *a lot*
- if we gon do stuff like that, pls figure out the isa stuff first, and make
 sure it *works* (ie usability - if i cant write it by hand, odds are i cant
 compile it)

defun defers to set, should be the other way around

might wanna reorder asm routines somewhat

ports might be pretty useful actually, to generalise all the io stuff we do
they dont *do* a lot, but still, we could manage files from scm instead of c
also `(transcript-off)`





---

## Status

vm: io modes
asm: -
eval: ports, vectors, proper arg checks, occasional parsing issues
 - stringmem gc?
comp: bootstrapping/wrapper/repl, heap (atomic, globenv) and gc
 - vectors, strings, atoms/symbols
