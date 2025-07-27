all:
	gcc -o asm asm.c -g
	gcc -o vm vm.c -g
	gcc -o eval eval.c -g

clean:
	rm asm vm eval coredump t.*

run:
	./eval comp.scm >/dev/null
	cat comp.asm > t.asm
	cat coredump >> t.asm
	./asm t.asm t.vm 1 > t.dbg
	./vm t.vm

go:
	./asm t.asm t.vm 1 > t.dbg
	./vm t.vm | hexdump -C
