# QWAK Lisp

*QWAK* ("Qlosure With A K") is a dialect of Lisp largely inspired by Scheme.
It started as a toy project to learn how to implement an interpreter, and it
grew to be pretty useful, parts of it finding way into other projects of mine
(like [SpaceCore][spc] and [ExBot][exbot]). My main goal was to make something
small enough to be comprehensible and easily modifiable, yet good enough to
be usable. ChickenScheme is 760kloc, ChibiScheme is just under 20kloc, and
while they are both "efficient" at what they do, they are riddled with
`defun`s for various features that are more distracting than useful, and
neither of them is easy to grasp unless you already know how it works.
Meanwhile, the entire QWAK source, including VM compiler, assembler, and
emulator, Makefile, *and* the file with my freeform ramblings about error
codes and call conventions, still clocks in at 1500loc.

[spc]: https://avethenoul.neocities.org/spc
[exbot]: https://ivykingsley.itch.io/exhibotanist

It is mainly implemented as an interpreter in C, although im toying around
with a compiler targeted at a custom ISA. The compiler is written in QWAK and
some assembly, the ISA is implemented as an assembler and emulator (also in
this repo).

I have a [series of articles][lisp] describing the language, how it works, and
how it's implemented. I am still in the process of bringing them up to date,
this README is thus also correspondingly short.

[lisp]: https://avethenoul.neocities.org/lisp

The contents of this repo are loosely licensed under CC-BY-NC-SA. I am reading
up on the GPL, I do not foresee licensing to be an issue anytime soon, feel
free to shoot me a mail or similar if you have questions, comments, or would
like to use this somewhere (regardless of licensing - I'd love to hear about
it!).
