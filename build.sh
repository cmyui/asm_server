#!/usr/bin/env bash
set -euo pipefail

nasm -f elf64 \
    -g -F dwarf \
    -O0 \
    main.asm \
    -o main.o

ld main.o -o main.out
