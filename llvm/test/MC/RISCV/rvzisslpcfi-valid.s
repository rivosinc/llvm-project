# With Control-Flow Integrity extension:
# RUN: llvm-mc %s -triple=riscv64 -mattr=+a,+experimental-zisslpcfi -show-encoding \
# RUN:     | FileCheck -check-prefixes=CHECK-ASM,CHECK-ASM-AND-OBJ %s
# RUN: llvm-mc %s -triple=riscv32 -mattr=+a,+experimental-zisslpcfi -show-encoding \
# RUN:     | FileCheck -check-prefixes=CHECK-ASM,CHECK-ASM-AND-OBJ %s
# RUN: llvm-mc -filetype=obj -triple=riscv64 -mattr=+a,+experimental-zisslpcfi < %s \
# RUN:     | llvm-objdump --mattr=+a,+experimental-zisslpcfi -d -r - \
# RUN:     | FileCheck --check-prefix=CHECK-ASM-AND-OBJ %s
# RUN: llvm-mc -filetype=obj -triple=riscv32 -mattr=+a,+experimental-zisslpcfi < %s \
# RUN:     | llvm-objdump --mattr=+a,+experimental-zisslpcfi -d -r - \
# RUN:     | FileCheck --check-prefix=CHECK-ASM-AND-OBJ %s

# CHECK-ASM-AND-OBJ: lpsll 291
# CHECK-ASM: encoding: [0x73,0xc0,0x91,0x82]
lpsll 291 # (0x123 >> 1) == 0x91,8
# CHECK-ASM-AND-OBJ: lpcll 291
# CHECK-ASM: encoding: [0x73,0xc0,0x91,0x83]
lpcll 291 # (0x123 >> 1) == 0x91,8
# CHECK-ASM-AND-OBJ: lpsml 137
# CHECK-ASM: encoding: [0x73,0xc0,0x44,0x86]
lpsml 137 # 0x89
# CHECK-ASM-AND-OBJ: lpcml 137
# CHECK-ASM: encoding: [0x73,0xc0,0xc4,0x86]
lpcml 137 # 0x89
# CHECK-ASM-AND-OBJ: lpsul 137
# CHECK-ASM: encoding: [0x73,0xc0,0x44,0x87]
lpsul 137 # 0x89
# CHECK-ASM-AND-OBJ: lpcul 137
# CHECK-ASM: encoding: [0x73,0xc0,0xc4,0x87]
lpcul 137 # 0x89

# CHECK-ASM-AND-OBJ: sspush t0
# CHECK-ASM: encoding: [0x73,0xc0,0xc2,0x81]
sspush t0
# CHECK-ASM-AND-OBJ: sspop ra
# CHECK-ASM: encoding: [0xf3,0x40,0xc0,0x81]
sspop ra
# CHECK-ASM-AND-OBJ: ssprr t0
# CHECK-ASM: encoding: [0xf3,0x42,0xd0,0x81]
ssprr t0
# CHECK-ASM-AND-OBJ: sschkra
# CHECK-ASM: encoding: [0x73,0xc0,0x12,0x8a]
sschkra

# CHECK-ASM-AND-OBJ: ssamoswap t0, t1, (t2)
# CHECK-ASM: encoding: [0xf3,0xc2,0x63,0x82]
ssamoswap t0, t1, (t2)
