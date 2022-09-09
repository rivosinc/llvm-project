// RUN: %clang -target riscv64 -o - -emit-llvm -S -fcf-protection=branch %s | FileCheck %s --check-prefixes=CFPROT
// RUN: %clang -target riscv64 -x c -E -dM -o - -fcf-protection=branch %s | FileCheck %s --check-prefix=BRANCH
// RUN: %clang -target riscv64 -x c -E -dM -o - -fcf-protection=return %s | FileCheck %s --check-prefix=RETURN
// RUN: %clang -target riscv64 -x c -E -dM -o - -fcf-protection=full %s | FileCheck %s --check-prefix=FULL

// BRANCH: #define __RISCV_ZISSLPCFI__ 1
// RETURN: #define __RISCV_ZISSLPCFI__ 2
// FULL: #define __RISCV_ZISSLPCFI__ 3
// CFPROT: !{i32 8, !"cf-protection-branch", i32 1}

void foo() {}
