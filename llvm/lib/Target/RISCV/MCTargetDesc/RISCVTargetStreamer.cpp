//===-- RISCVTargetStreamer.cpp - RISCV Target Streamer Methods -----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file provides RISCV specific target streamer methods.
//
//===----------------------------------------------------------------------===//

#include "RISCVTargetStreamer.h"
#include "RISCVBaseInfo.h"
#include "RISCVMCTargetDesc.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCSectionELF.h"
#include "llvm/Support/FormattedStream.h"
#include "llvm/Support/RISCVAttributes.h"
#include "llvm/Support/RISCVISAInfo.h"

using namespace llvm;

RISCVTargetStreamer::RISCVTargetStreamer(MCStreamer &S) : MCTargetStreamer(S) {}

void RISCVTargetStreamer::finish() { finishAttributeSection(); }
void RISCVTargetStreamer::reset() {}

void RISCVTargetStreamer::emitDirectiveOptionPush() {}
void RISCVTargetStreamer::emitDirectiveOptionPop() {}
void RISCVTargetStreamer::emitDirectiveOptionPIC() {}
void RISCVTargetStreamer::emitDirectiveOptionNoPIC() {}
void RISCVTargetStreamer::emitDirectiveOptionRVC() {}
void RISCVTargetStreamer::emitDirectiveOptionNoRVC() {}
void RISCVTargetStreamer::emitDirectiveOptionRelax() {}
void RISCVTargetStreamer::emitDirectiveOptionNoRelax() {}
void RISCVTargetStreamer::emitDirectiveVariantCC(MCSymbol &Symbol) {}
void RISCVTargetStreamer::emitAttribute(unsigned Attribute, unsigned Value) {}
void RISCVTargetStreamer::finishAttributeSection() {}
void RISCVTargetStreamer::emitTextAttribute(unsigned Attribute,
                                            StringRef String) {}
void RISCVTargetStreamer::emitIntTextAttribute(unsigned Attribute,
                                               unsigned IntValue,
                                               StringRef StringValue) {}
void RISCVTargetStreamer::setTargetABI(RISCVABI::ABI ABI) {
  assert(ABI != RISCVABI::ABI_Unknown && "Improperly initialized target ABI");
  TargetABI = ABI;
}

void RISCVTargetStreamer::emitTargetAttributes(const MCSubtargetInfo &STI) {
  if (STI.hasFeature(RISCV::FeatureRV32E))
    emitAttribute(RISCVAttrs::STACK_ALIGN, RISCVAttrs::ALIGN_4);
  else
    emitAttribute(RISCVAttrs::STACK_ALIGN, RISCVAttrs::ALIGN_16);

  auto ParseResult = RISCVFeatures::parseFeatureBits(
      STI.hasFeature(RISCV::Feature64Bit), STI.getFeatureBits());
  if (!ParseResult) {
    report_fatal_error(ParseResult.takeError());
  } else {
    auto &ISAInfo = *ParseResult;
    emitTextAttribute(RISCVAttrs::ARCH, ISAInfo->toString());
  }
}

void RISCVTargetStreamer::emitNoteSection(int WordSize, unsigned Flags) {
  if (Flags == 0)
    return;

  MCStreamer &OutStreamer = getStreamer();
  MCContext &Context = OutStreamer.getContext();
  // Emit a .note.gnu.property section with the flags.
  MCSectionELF *Nt = Context.getELFSection(".note.gnu.property", ELF::SHT_NOTE,
                                           ELF::SHF_ALLOC);
  if (Nt->isRegistered()) {
    SMLoc Loc;
    Context.reportWarning(
        Loc,
        "The .note.gnu.property is not emitted because it is already present.");
    return;
  }
  MCSection *Cur = OutStreamer.getCurrentSectionOnly();
  OutStreamer.switchSection(Nt);

  // Emit the note header.
  OutStreamer.emitValueToAlignment(Align(WordSize).value());
  OutStreamer.emitIntValue(4, 4);     // data size for "GNU\0"
  OutStreamer.emitIntValue(8 + WordSize, 4); // Elf_Prop size
  OutStreamer.emitIntValue(ELF::NT_GNU_PROPERTY_TYPE_0, 4);
  OutStreamer.emitBytes(StringRef("GNU", 4)); // note name

  // Emit the PAC/BTI properties.
  OutStreamer.emitIntValue(ELF::GNU_PROPERTY_RISCV_FEATURE_1_AND, 4);
  OutStreamer.emitIntValue(4, 4);     // data size
  OutStreamer.emitIntValue(Flags, 4); // data
  OutStreamer.emitValueToAlignment(Align(WordSize).value()); // padding

  OutStreamer.endSection(Nt);
  OutStreamer.switchSection(Cur);
}

// This part is for ascii assembly output
RISCVTargetAsmStreamer::RISCVTargetAsmStreamer(MCStreamer &S,
                                               formatted_raw_ostream &OS)
    : RISCVTargetStreamer(S), OS(OS) {}

void RISCVTargetAsmStreamer::emitDirectiveOptionPush() {
  OS << "\t.option\tpush\n";
}

void RISCVTargetAsmStreamer::emitDirectiveOptionPop() {
  OS << "\t.option\tpop\n";
}

void RISCVTargetAsmStreamer::emitDirectiveOptionPIC() {
  OS << "\t.option\tpic\n";
}

void RISCVTargetAsmStreamer::emitDirectiveOptionNoPIC() {
  OS << "\t.option\tnopic\n";
}

void RISCVTargetAsmStreamer::emitDirectiveOptionRVC() {
  OS << "\t.option\trvc\n";
}

void RISCVTargetAsmStreamer::emitDirectiveOptionNoRVC() {
  OS << "\t.option\tnorvc\n";
}

void RISCVTargetAsmStreamer::emitDirectiveOptionRelax() {
  OS << "\t.option\trelax\n";
}

void RISCVTargetAsmStreamer::emitDirectiveOptionNoRelax() {
  OS << "\t.option\tnorelax\n";
}

void RISCVTargetAsmStreamer::emitDirectiveVariantCC(MCSymbol &Symbol) {
  OS << "\t.variant_cc\t" << Symbol.getName() << "\n";
}

void RISCVTargetAsmStreamer::emitAttribute(unsigned Attribute, unsigned Value) {
  OS << "\t.attribute\t" << Attribute << ", " << Twine(Value) << "\n";
}

void RISCVTargetAsmStreamer::emitTextAttribute(unsigned Attribute,
                                               StringRef String) {
  OS << "\t.attribute\t" << Attribute << ", \"" << String << "\"\n";
}

void RISCVTargetAsmStreamer::emitIntTextAttribute(unsigned Attribute,
                                                  unsigned IntValue,
                                                  StringRef StringValue) {}

void RISCVTargetAsmStreamer::finishAttributeSection() {}
