; RUN: llc -mtriple riscv32-linux %s -o - \
; RUN:   | FileCheck %s --check-prefix=RV32-ASM
; RUN: llc -mtriple riscv64-linux %s -o - \
; RUN:   | FileCheck %s --check-prefix=RV64-ASM
; RUN: llc -mtriple riscv32-linux %s -filetype=obj -o - | llvm-readelf --notes - \
; RUN:   | FileCheck %s --check-prefix=RV32-OBJ
; RUN: llc -mtriple riscv64-linux %s -filetype=obj -o - | llvm-readelf --notes - \
; RUN:   | FileCheck %s --check-prefix=RV64-OBJ

; This test checks that the compiler emits a .note.gnu.property section for
; modules with "cf-protection" module flags.

; RV32-ASM:      .section        .note.gnu.property,"a",@note
; RV32-ASM-NEXT: .p2align 2
; RV32-ASM-NEXT: .word    4
; RV32-ASM-NEXT: .word    12
; RV32-ASM-NEXT: .word    5
; RV32-ASM-NEXT: .asciz   "GNU"
; RV32-ASM-NEXT: .word    3221225475
; RV32-ASM-NEXT: .word    4
; RV32-ASM-NEXT: .word    3
; RV32-ASM-NEXT: .p2align 2

; RV64-ASM:      .section        .note.gnu.property,"a",@note
; RV64-ASM-NEXT: .p2align 3
; RV64-ASM-NEXT: .word    4
; RV64-ASM-NEXT: .word    16
; RV64-ASM-NEXT: .word    5
; RV64-ASM-NEXT: .asciz   "GNU"
; RV64-ASM-NEXT: .word    3221225475
; RV64-ASM-NEXT: .word    4
; RV64-ASM-NEXT: .word    3
; RV64-ASM-NEXT: .p2align 3

; RV32-OBJ:      GNU 0x0000000c NT_GNU_PROPERTY_TYPE_0
; RV32-OBJ-NEXT: Properties: riscv feature: FCFI, BCFI

; RV64-OBJ:      GNU 0x00000010 NT_GNU_PROPERTY_TYPE_0
; RV64-OBJ-NEXT: Properties: riscv feature: FCFI, BCFI

!llvm.module.flags = !{!0, !1}

!0 = !{i32 8, !"cf-protection-return", i32 1}
!1 = !{i32 8, !"cf-protection-branch", i32 1}
