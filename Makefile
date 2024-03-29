#!/usr/bin/make

build:
	nasm -f elf64 \
		-g -F dwarf \
		-O0 \
		main.asm \
		-o main.o
	ld main.o -o main.out

run:
	strace ./main.out

debug:
	gdb ./main.out

objdump:
	objdump -s \
		-j.rodata \
		-j.data \
		-j.bss \
		-j.comment \
		-j.text \
		main.out

valgrind:
	valgrind --leak-check=full \
		--show-leak-kinds=all \
		--track-origins=yes \
		./main.out
