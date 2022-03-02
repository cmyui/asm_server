#!/usr/bin/env bash
set -euo pipefail

# TODO: option to optimize for size & speed (-O3, strip symbols)
nasm -f elf64 -O0 main.asm -o main.o
ld main.o -o main.out
