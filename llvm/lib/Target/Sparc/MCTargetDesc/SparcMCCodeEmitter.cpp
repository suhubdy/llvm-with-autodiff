//===-- SparcMCCodeEmitter.cpp - Convert Sparc code to machine code -------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file implements the SparcMCCodeEmitter class.
//
//===----------------------------------------------------------------------===//

#define DEBUG_TYPE "mccodeemitter"
#include "SparcMCExpr.h"
#include "MCTargetDesc/SparcFixupKinds.h"
#include "SparcMCTargetDesc.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/MC/MCCodeEmitter.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

STATISTIC(MCNumEmitted, "Number of MC instructions emitted");

namespace {
class SparcMCCodeEmitter : public MCCodeEmitter {
  SparcMCCodeEmitter(const SparcMCCodeEmitter &) LLVM_DELETED_FUNCTION;
  void operator=(const SparcMCCodeEmitter &) LLVM_DELETED_FUNCTION;
  MCContext &Ctx;

public:
  SparcMCCodeEmitter(MCContext &ctx): Ctx(ctx) {}

  ~SparcMCCodeEmitter() {}

  void EncodeInstruction(const MCInst &MI, raw_ostream &OS,
                         SmallVectorImpl<MCFixup> &Fixups,
                         const MCSubtargetInfo &STI) const;

  // getBinaryCodeForInstr - TableGen'erated function for getting the
  // binary encoding for an instruction.
  uint64_t getBinaryCodeForInstr(const MCInst &MI,
                                 SmallVectorImpl<MCFixup> &Fixups,
                                 const MCSubtargetInfo &STI) const;

  /// getMachineOpValue - Return binary encoding of operand. If the machine
  /// operand requires relocation, record the relocation and return zero.
  unsigned getMachineOpValue(const MCInst &MI, const MCOperand &MO,
                             SmallVectorImpl<MCFixup> &Fixups,
                             const MCSubtargetInfo &STI) const;

  unsigned getCallTargetOpValue(const MCInst &MI, unsigned OpNo,
                             SmallVectorImpl<MCFixup> &Fixups,
                             const MCSubtargetInfo &STI) const;
  unsigned getBranchTargetOpValue(const MCInst &MI, unsigned OpNo,
                             SmallVectorImpl<MCFixup> &Fixups,
                             const MCSubtargetInfo &STI) const;

};
} // end anonymous namespace

MCCodeEmitter *llvm::createSparcMCCodeEmitter(const MCInstrInfo &MCII,
                                              const MCRegisterInfo &MRI,
                                              const MCSubtargetInfo &STI,
                                              MCContext &Ctx) {
  return new SparcMCCodeEmitter(Ctx);
}

void SparcMCCodeEmitter::
EncodeInstruction(const MCInst &MI, raw_ostream &OS,
                  SmallVectorImpl<MCFixup> &Fixups,
                  const MCSubtargetInfo &STI) const {
  unsigned Bits = getBinaryCodeForInstr(MI, Fixups, STI);

  // Output the constant in big endian byte order.
  for (unsigned i = 0; i != 4; ++i) {
    OS << (char)(Bits >> 24);
    Bits <<= 8;
  }

  ++MCNumEmitted;  // Keep track of the # of mi's emitted.
}


unsigned SparcMCCodeEmitter::
getMachineOpValue(const MCInst &MI, const MCOperand &MO,
                  SmallVectorImpl<MCFixup> &Fixups,
                  const MCSubtargetInfo &STI) const {

  if (MO.isReg())
    return Ctx.getRegisterInfo()->getEncodingValue(MO.getReg());

  if (MO.isImm())
    return MO.getImm();

  assert(MO.isExpr());
  const MCExpr *Expr = MO.getExpr();
  if (const SparcMCExpr *SExpr = dyn_cast<SparcMCExpr>(Expr)) {
    MCFixupKind Kind = (MCFixupKind)SExpr->getFixupKind();
    Fixups.push_back(MCFixup::Create(0, Expr, Kind));
    return 0;
  }

  int64_t Res;
  if (Expr->EvaluateAsAbsolute(Res))
    return Res;

  assert(0 && "Unhandled expression!");
  return 0;
}

unsigned SparcMCCodeEmitter::
getCallTargetOpValue(const MCInst &MI, unsigned OpNo,
                     SmallVectorImpl<MCFixup> &Fixups,
                     const MCSubtargetInfo &STI) const {
  const MCOperand &MO = MI.getOperand(OpNo);
  if (MO.isReg() || MO.isImm())
    return getMachineOpValue(MI, MO, Fixups, STI);

  MCFixupKind fixupKind = (MCFixupKind)Sparc::fixup_sparc_call30;

  if (const SparcMCExpr *SExpr = dyn_cast<SparcMCExpr>(MO.getExpr())) {
    if (SExpr->getKind() == SparcMCExpr::VK_Sparc_WPLT30)
      fixupKind = (MCFixupKind)Sparc::fixup_sparc_wplt30;
  }

  Fixups.push_back(MCFixup::Create(0, MO.getExpr(), fixupKind));

  return 0;
}

unsigned SparcMCCodeEmitter::
getBranchTargetOpValue(const MCInst &MI, unsigned OpNo,
                  SmallVectorImpl<MCFixup> &Fixups,
                  const MCSubtargetInfo &STI) const {
  const MCOperand &MO = MI.getOperand(OpNo);
  if (MO.isReg() || MO.isImm())
    return getMachineOpValue(MI, MO, Fixups, STI);

  Sparc::Fixups fixup = Sparc::fixup_sparc_br22;
  if (MI.getOpcode() == SP::BPXCC)
    fixup = Sparc::fixup_sparc_br19;

  Fixups.push_back(MCFixup::Create(0, MO.getExpr(),
                                   (MCFixupKind)fixup));
  return 0;
}

#include "SparcGenMCCodeEmitter.inc"
