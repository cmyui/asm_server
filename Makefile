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
