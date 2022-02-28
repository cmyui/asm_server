#!/usr/bin/env bash
set -euo pipefail

nasm -f elf64 main.asm -o main.o
ld main.o -o main.out
