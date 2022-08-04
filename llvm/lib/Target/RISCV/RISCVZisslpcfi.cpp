//===---- RISCVZisslpcfi.cpp - Enables Control-Flow Integrity -----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// TODO(gkm):
// This file defines a pass that enables Indirect Branch Tracking (IBT) as part
// of Control-Flow Enforcement Technology (CET).
// The pass adds ENDBR (End Branch) machine instructions at the beginning of
// each basic block or function that is referenced by an indrect jump/call
// instruction.
// The ENDBR instructions have a NOP encoding and as such are ignored in
// targets that do not support CET IBT mechanism.
//===----------------------------------------------------------------------===//

#include "RISCV.h"
#include "RISCVInstrInfo.h"
#include "RISCVSubtarget.h"
#include "RISCVTargetMachine.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineJumpTableInfo.h"
#include "llvm/CodeGen/MachineModuleInfo.h"

using namespace llvm;

#define DEBUG_TYPE "riscv-forward-cfi-landing-pads"

STATISTIC(NumLandingPadsAdded, "Number of landing-pad instructions added");

namespace {
class RISCVForwardCFIPass : public MachineFunctionPass {
public:
  RISCVForwardCFIPass() : MachineFunctionPass(ID) {}

  StringRef getPassName() const override {
    return "RISCV Forward-CFI Landing Pads";
  }

  bool runOnMachineFunction(MachineFunction &MF) override;

private:
  static char ID;

  /// Machine instruction info used throughout the class.
  const RISCVInstrInfo *TII = nullptr;

  /// Adds a new landing-pad instruction to the beginning of the MBB.
  /// The function will not add it if already exists.
  /// \returns true if the landing pad was added and false otherwise.
  bool addLandingPad(MachineBasicBlock &MBB, MachineBasicBlock::iterator MBBI,
                     bool forCall = false) const;
};

} // end anonymous namespace

char RISCVForwardCFIPass::ID = 0;

FunctionPass *llvm::createRISCVForwardCFIPass() {
  return new RISCVForwardCFIPass();
}

bool RISCVForwardCFIPass::addLandingPad(MachineBasicBlock &MBB,
                                        MachineBasicBlock::iterator MBBI,
                                        bool forCall) const {
  assert(TII && "Target instruction info was not initialized");

  // If the MBB/MBBI is empty or the current instruction is not a landing pad,
  // insert a landing pad instruction to the location of MBBI.
  if (MBBI == MBB.end() || MBBI->getOpcode() != RISCV::LPCLL) {
    BuildMI(MBB, MBBI, MBB.findDebugLoc(MBBI), TII->get(RISCV::LPCLL))
        .addImm(0); // TODO: label
    ++NumLandingPadsAdded;
    return true;
  }
  return false;
}

static bool isCallReturnTwice(MachineBasicBlock::iterator &MBBI) {
  if (!MBBI->isCall() || MBBI->getNumOperands() == 0)
    return false;
  llvm::MachineOperand &MOp = MBBI->getOperand(0);
  if (!MOp.isGlobal())
    return false;
  auto *CalleeFn = dyn_cast<Function>(MOp.getGlobal());
  if (!CalleeFn)
    return false;
  AttributeList Attrs = CalleeFn->getAttributes();
  return Attrs.hasFnAttr(Attribute::ReturnsTwice);
}

bool RISCVForwardCFIPass::runOnMachineFunction(MachineFunction &MF) {
  const RISCVSubtarget &SubTarget = MF.getSubtarget<RISCVSubtarget>();

  const Module *M = MF.getMMI().getModule();
  // Check that the cf-protection-branch is enabled.
  Metadata *isCFProtectionSupported = M->getModuleFlag("cf-protection-branch");

  if (!isCFProtectionSupported)
    return false;

  TII = SubTarget.getInstrInfo();

  bool Changed = false;

  // If function is reachable indirectly (its address is taken or it has
  // external visiblibility) mark the prologue BB with a landing pad.
  Function &F = MF.getFunction();
  if (F.hasAddressTaken() || !F.hasLocalLinkage()) {
    MachineBasicBlock &MBB = *MF.begin();
    Changed |= addLandingPad(MBB, MBB.begin(), true);
  }

  // LLVM does not consider basic blocks which are the targets of jump tables
  // to be address-taken (the address can't escape anywhere else), but they are
  // used for indirect branches, so need BTI instructions.
  SmallPtrSet<MachineBasicBlock *, 8> JumpTableTargets;
  if (auto *JTI = MF.getJumpTableInfo())
    for (auto &JTE : JTI->getJumpTables())
      for (auto *MBB : JTE.MBBs)
        JumpTableTargets.insert(MBB);

  for (MachineBasicBlock &MBB : MF) {
    // Add a landing pad to all basic blocks whose address is taken (e.g., for
    // an indirect jump)
    if (MBB.hasAddressTaken() || JumpTableTargets.count(&MBB))
      Changed |= addLandingPad(MBB, MBB.begin());

    for (MachineBasicBlock::iterator MBBI : MBB)
      if (isCallReturnTwice(MBBI))
        Changed |= addLandingPad(MBB, std::next(MBBI));

    // Exception handler may indirectly jump to catch pad, so we should add a
    // landing pad before catch pad instructions. For SjLj exception model, it
    // will create a new BB(new landing pad) to indirectly jump to the old
    // landing pad.
    const RISCVTargetMachine *TM =
        static_cast<const RISCVTargetMachine *>(&MF.getTarget());
    if (TM->Options.ExceptionModel == ExceptionHandling::SjLj) {
      for (MachineBasicBlock::iterator MBBI : MBB) {
        // New Landingpad BB without EHLabel.
        if (MBB.isEHPad()) {
          if (MBBI->isDebugInstr())
            continue;
          Changed |= addLandingPad(MBB, MBBI);
          break;
        } else if (MBBI->isEHLabel()) {
          // Old Landingpad BB (is not Landingpad now) with
          // the the old "callee" EHLabel.
          MCSymbol *Sym = MBBI->getOperand(0).getMCSymbol();
          if (!MF.hasCallSiteLandingPad(Sym))
            continue;
          Changed |= addLandingPad(MBB, std::next(MBBI));
          break;
        }
      }
    } else if (MBB.isEHPad()) {
      for (MachineBasicBlock::iterator MBBI : MBB) {
        if (!MBBI->isEHLabel())
          continue;
        Changed |= addLandingPad(MBB, std::next(MBBI));
        break;
      }
    }
  }
  return Changed;
}
