#!/usr/bin/env bash
set -euo pipefail

./build.sh
strace ./main.out
