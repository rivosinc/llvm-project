// RUN: %clang -target riscv64 -x c -E -dM -o - -fcf-protection=branch %s | FileCheck %s --check-prefix=BRANCH
// RUN: %clang -target riscv64 -o - -emit-llvm -S -fcf-protection=branch %s | FileCheck %s --check-prefixes=CFPROT

// BRANCH: #define __RISCV_ZISSLPCFI__ 1
// CFPROT: !{i32 8, !"cf-protection-branch", i32 1}

void foo() {}
