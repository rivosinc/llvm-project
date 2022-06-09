# RUN: not llvm-mc -triple riscv64 -mattr=+experimental-zisslpcfi < %s 2>&1 | FileCheck %s
# RUN: not llvm-mc -triple riscv32 -mattr=+experimental-zisslpcfi < %s 2>&1 | FileCheck %s

# CHECK: :[[@LINE+1]]:1: error: too few operands for instruction
lpcll
# CHECK: :[[@LINE+1]]:7: error: immediate must be an integer in the range [0, 255]
lpcml 0x100
# CHECK: :[[@LINE+1]]:7: error: immediate must be an integer in the range [0, 255]
lpcul 0x100
# CHECK: :[[@LINE+1]]:7: error: immediate must be an integer in the range [0, 511]
lpsll 0x200
# CHECK: :[[@LINE+1]]:7: error: immediate must be an integer in the range [0, 255]
lpsml -1
# CHECK: :[[@LINE+1]]:7: error: immediate must be an integer in the range [0, 255]
lpsul 0x100

# CHECK: :[[@LINE+1]]:1: error: too few operands for instruction
sspush
# CHECK: :[[@LINE+1]]:7: error: invalid operand for instruction
sspop x4
# CHECK: :[[@LINE+1]]:1: error: too few operands for instruction
ssprr
# CHECK: :[[@LINE+1]]:9: error: invalid operand for instruction
sschkra x4

# CHECK: :[[@LINE+1]]:1: error: too few operands for instruction
ssamoswap x2,x3
# CHECK: :[[@LINE+1]]:17: error: expected '(' or optional integer offset
ssamoswap x2,x3,x4
