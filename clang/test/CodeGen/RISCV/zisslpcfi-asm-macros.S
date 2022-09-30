// RUN: %clang --target=riscv32-linux -march=rv32g_zisslpcfi0p1 \
// RUN:     -menable-experimental-extensions -fcf-protection -c %s -o - | \
// RUN:   llvm-readelf -n - | FileCheck %s --check-prefixes=NOTE
// RUN: %clang --target=riscv32-linux -c %s -o - | \
// RUN:   llvm-readelf -S - | FileCheck %s --check-prefixes=NO-NOTE
// RUN: %clang --target=riscv32-linux -march=rv32g_zisslpcfi0p1 \
// RUN:     -menable-experimental-extensions -fcf-protection -S %s -o - | \
// RUN:   FileCheck %s --check-prefixes=LPCXL
// RUN: %clang --target=riscv32-linux -S %s -o - | \
// RUN:   FileCheck %s --check-prefixes=NO-LPCXL

// RUN: %clang --target=riscv64-linux -march=rv64g_zisslpcfi0p1 \
// RUN:     -menable-experimental-extensions -fcf-protection -c %s -o - | \
// RUN:   llvm-readelf -n - | FileCheck %s --check-prefixes=NOTE
// RUN: %clang --target=riscv64-linux -c %s -o - | \
// RUN:   llvm-readelf -S - | FileCheck %s --check-prefixes=NO-NOTE
// RUN: %clang --target=riscv64-linux -march=rv64g_zisslpcfi0p1 \
// RUN:     -menable-experimental-extensions -fcf-protection -S %s -o - | \
// RUN:   FileCheck %s --check-prefixes=LPCXL
// RUN: %clang --target=riscv64-linux -S %s -o - | \
// RUN:   FileCheck %s --check-prefixes=NO-LPCXL

// NOTE: GNU {{[x0-9a-f]+}} NT_GNU_PROPERTY_TYPE_0 (property note)
// NOTE: Properties: riscv feature: FCFI, BCFI

// NO-NOTE:     Section Headers
// NO-NOTE-NOT: .note.gnu.property

// LPCXL:   foo
// LPCXL: lpcll 0x123
// LPCXL: lpcml 0xAB
// LPCXL: lpcul 0xCD

// NO-LPCXL:   foo
// NO-LPCXL-NOT: lpcll
// NO-LPCXL-NOT: lpcml
// NO-LPCXL-NOT: lpcul

#include <riscv_zisslpcfi.h>

        .text
        .globl  foo
        .type   foo, @function
foo:
        _LPCLL(0x123)
        _LPCML(0xAB)
        _LPCUL(0xCD)
        ret
