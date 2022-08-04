; RUN: llc -mtriple=riscv32 -mattr=+experimental-zisslpcfi -verify-machineinstrs < %s \
; RUN:   | FileCheck %s
; RUN: llc -mtriple=riscv64 -mattr=+experimental-zisslpcfi -verify-machineinstrs < %s \
; RUN:   | FileCheck %s

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Test1
;; -----
;; Checks LPCLL insertion in case of switch case statement.
;; Also since the function is not internal, make sure that endbr32/64 was
;; added at the beginning of the function.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

define i8 @test_switch_cases(){
; CHECK-LABEL:   test_switch_cases
; CHECK:         lpcll
; CHECK:         jr
; CHECK:         .LBB0_1:
; CHECK-NEXT:    lpcll
; CHECK:         .LBB0_2:
; CHECK-NEXT:    lpcll
entry:
  %0 = select i1 undef, ptr blockaddress(@test_switch_cases, %bb), ptr blockaddress(@test_switch_cases, %bb6) ; <ptr> [#uses=1]
  indirectbr ptr %0, [label %bb, label %bb6]

bb:                                               ; preds = %entry
  ret i8 1

bb6:                                              ; preds = %entry
  ret i8 2
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Checks LPCLL insertion in case of indirect call instruction.
;; The new instruction should be added to the called function
;; (test_func_addr_taken) although it is internal.
;; Also since the function is not internal, LPCLL instruction should be
;; added to its first basic block.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

define void @test_indirect_call() {
; CHECK-LABEL:   test_indirect_call
; CHECK:         lpcll
; CHECK:         jalr
entry:
  %f = alloca ptr, align 8
  store ptr @test_func_addr_taken, ptr %f, align 8
  %0 = load ptr, ptr %f, align 8
  %call = call i32 (...) %0()
  ret void
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Checks LPCLL insertion in case of internal function.
;; Since the function is internal and its address was not taken,
;; make sure that LPCLL was not added at the beginning of the
;; function.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

define internal i8 @test_internal(){
; CHECK-LABEL:   test_internal
; CHECK-NOT:     lpcll
  ret i8 1
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Checks LPCLL insertion in case of function that its was address taken.
;; Since the function's address was taken by test_indirect_call() and despite
;; being internal, check for added LPCLL at the beginning of the function.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

define internal i32 @test_func_addr_taken(i32 %a) {
; CHECK-LABEL:   test_func_addr_taken
; CHECK:         lpcll
  ret i32 1
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Checks LPCLL insertion in case of non-internal function.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

define i32 @test_non_internal() {
; CHECK-LABEL:   test_non_internal
; CHECK:         lpcll
  ret i32 1
}

!llvm.module.flags = !{!0}

!0 = !{i32 8, !"cf-protection-branch", i32 1}
