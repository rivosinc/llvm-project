//===-- RISCVInstrInfoZisslpcfi.td - RISC-V 'Zisslpcfi' instructions ----*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file describes the RISC-V instructions from the Rivos 'Zisslpcfi',
// Shadow-Stack Landing-Pad Control Flow Integrity.
//
//===----------------------------------------------------------------------===//

def uimm8 : Operand<XLenVT> {
  let ParserMatchClass = UImmAsmOperand<8>;
  let DecoderMethod = "decodeUImmOperand<8>";
  let OperandType = "OPERAND_UIMM8";
  let OperandNamespace = "RISCVOp";
}

def uimm9 : Operand<XLenVT> {
  let ParserMatchClass = UImmAsmOperand<9>;
  let DecoderMethod = "decodeUImmOperand<9>";
  let OperandType = "OPERAND_UIMM9";
  let OperandNamespace = "RISCVOp";
}

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in
class RVInstZimops_i9<bits<8> funct8, string opcodestr>
    : RVInst<(outs),  (ins uimm9:$uimm9), opcodestr, "$uimm9", [], InstFormatI> {
  bits<9> uimm9;
  let Inst{31-24} = funct8;
  let Inst{23-15} = uimm9;
  let Inst{14-12} = 0b100;
  let Inst{11-7} = 0;
  let Opcode = OPC_SYSTEM.Value;
}

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in
class RVInstZimops_i8<bits<9> funct9, string opcodestr>
    : RVInst<(outs),  (ins uimm8:$uimm8), opcodestr, "$uimm8", [], InstFormatI> {
  bits<8> uimm8;
  let Inst{31-23} = funct9;
  let Inst{22-15} = uimm8;
  let Inst{14-12} = 0b100;
  let Inst{11-7} = 0;
  let Opcode = OPC_SYSTEM.Value;
}

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in
class RVInstZimops_rr<bits<8> funct8, string opcodestr>
    : RVInst<(outs),  (ins uimm9:$uimm9), opcodestr, "uimm9:$uimm9", [], InstFormatI> {
  bits<9> uimm9;
  let Inst{31-24} = funct8;
  let Inst{23-15} = uimm9;
  let Inst{14-12} = 0b100;
  let Inst{11-7} = 0;
  let Opcode = OPC_SYSTEM.Value;
}

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in
class RVInstZimops_rs1<bits<12> funct12, dag ins, string opcodestr>
    : RVInst<(outs), ins, opcodestr, "$rs1", [], InstFormatI> {
  bits<5> rs1;
  let Inst{31-20} = funct12;
  let Inst{19-15} = rs1;
  let Inst{14-12} = 0b100;
  let Inst{11-7} = 0;
  let Opcode = OPC_SYSTEM.Value;
}

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in
class RVInstZimops_rd<bits<17> funct17, dag outs, string opcodestr>
    : RVInst<outs, (ins), opcodestr, "$rd", [], InstFormatI> {
  bits<5> rd;
  let Inst{31-15} = funct17;
  let Inst{14-12} = 0b100;
  let Inst{11-7} = rd;
  let Opcode = OPC_SYSTEM.Value;
}

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in
class RVInstZimops_<bits<25> funct25, string opcodestr>
    : RVInst<(outs), (ins), opcodestr, "", [], InstFormatI> {
  let Inst{31-7} = funct25;
  let Opcode = OPC_SYSTEM.Value;
}

let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in
class RVInstZimops_rrr<bits<7> funct7, string opcodestr, string argstr>
    : RVInst<(outs GPR:$rd), (ins GPRMemZeroOffset:$rs1, GPR:$rs2), opcodestr, argstr, [], InstFormatI> {
  bits<5> rd;
  bits<5> rs1;
  bits<5> rs2;
  let Inst{31-25} = funct7;
  let Inst{24-20} = rs2;
  let Inst{19-15} = rs1;
  let Inst{14-12} = 0b100;
  let Inst{11-7} = rd;
  let Opcode = OPC_SYSTEM.Value;
}

let Predicates = [HasStdExtZisslpcfi] in {
def LPSLL : RVInstZimops_i9<0b10000010, "lpsll">;
def LPCLL : RVInstZimops_i9<0b10000011, "lpcll">;
def LPSML : RVInstZimops_i8<0b100001100, "lpsml">;
def LPCML : RVInstZimops_i8<0b100001101, "lpcml">;
def LPSUL : RVInstZimops_i8<0b100001110, "lpsul">;
def LPCUL : RVInstZimops_i8<0b100001111, "lpcul">;
let mayStore = 1 in
def SSPUSH : RVInstZimops_rs1<0b100000011100, (ins GPRX1X5:$rs1), "sspush">;
let mayLoad = 1 in
def SSPOP : RVInstZimops_rd<0b10000001110000000, (outs GPRX1X5:$rd), "sspop">;
def SSPRR : RVInstZimops_rd<0b10000001110100000, (outs GPR:$rd), "ssprr">;
def SSAMOSWAP : RVInstZimops_rrr<0b1000001, "ssamoswap", "$rd, $rs2, $rs1">;
def SSCHKRA : RVInstZimops_<0b1000101000010010110000000, "sschkra">;
} // Predicates = [HasStdExtZisslpcfi]
