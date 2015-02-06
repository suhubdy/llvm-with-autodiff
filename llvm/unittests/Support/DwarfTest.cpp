//===- unittest/Support/DwarfTest.cpp - Dwarf support tests ---------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "llvm/Support/Dwarf.h"
#include "gtest/gtest.h"

using namespace llvm;
using namespace llvm::dwarf;

namespace {

TEST(DwarfTest, TagStringOnInvalid) {
  // This is invalid, so it shouldn't be stringified.
  EXPECT_EQ(nullptr, TagString(DW_TAG_invalid));

  // These aren't really tags: they describe ranges within tags.  They
  // shouldn't be stringified either.
  EXPECT_EQ(nullptr, TagString(DW_TAG_lo_user));
  EXPECT_EQ(nullptr, TagString(DW_TAG_hi_user));
  EXPECT_EQ(nullptr, TagString(DW_TAG_user_base));
}

TEST(DwarfTest, getTag) {
  // A couple of valid tags.
  EXPECT_EQ(DW_TAG_array_type, getTag("DW_TAG_array_type"));
  EXPECT_EQ(DW_TAG_module, getTag("DW_TAG_module"));

  // Invalid tags.
  EXPECT_EQ(DW_TAG_invalid, getTag("DW_TAG_invalid"));
  EXPECT_EQ(DW_TAG_invalid, getTag("DW_TAG_madeuptag"));
  EXPECT_EQ(DW_TAG_invalid, getTag("something else"));

  // Tag range markers should not be recognized.
  EXPECT_EQ(DW_TAG_invalid, getTag("DW_TAG_lo_user"));
  EXPECT_EQ(DW_TAG_invalid, getTag("DW_TAG_hi_user"));
  EXPECT_EQ(DW_TAG_invalid, getTag("DW_TAG_user_base"));
}

TEST(DwarfTest, LanguageStringOnInvalid) {
  // This is invalid, so it shouldn't be stringified.
  EXPECT_EQ(nullptr, LanguageString(0));

  // These aren't really tags: they describe ranges within tags.  They
  // shouldn't be stringified either.
  EXPECT_EQ(nullptr, LanguageString(DW_LANG_lo_user));
  EXPECT_EQ(nullptr, LanguageString(DW_LANG_hi_user));
}

TEST(DwarfTest, getLanguage) {
  // A couple of valid languages.
  EXPECT_EQ(DW_LANG_C89, getLanguage("DW_LANG_C89"));
  EXPECT_EQ(DW_LANG_C_plus_plus_11, getLanguage("DW_LANG_C_plus_plus_11"));
  EXPECT_EQ(DW_LANG_OCaml, getLanguage("DW_LANG_OCaml"));
  EXPECT_EQ(DW_LANG_Mips_Assembler, getLanguage("DW_LANG_Mips_Assembler"));

  // Invalid languages.
  EXPECT_EQ(0u, getLanguage("DW_LANG_invalid"));
  EXPECT_EQ(0u, getLanguage("DW_TAG_array_type"));
  EXPECT_EQ(0u, getLanguage("something else"));

  // Language range markers should not be recognized.
  EXPECT_EQ(0u, getLanguage("DW_LANG_lo_user"));
  EXPECT_EQ(0u, getLanguage("DW_LANG_hi_user"));
}

TEST(DwarfTest, AttributeEncodingStringOnInvalid) {
  // This is invalid, so it shouldn't be stringified.
  EXPECT_EQ(nullptr, AttributeEncodingString(0));

  // These aren't really tags: they describe ranges within tags.  They
  // shouldn't be stringified either.
  EXPECT_EQ(nullptr, AttributeEncodingString(DW_ATE_lo_user));
  EXPECT_EQ(nullptr, AttributeEncodingString(DW_ATE_hi_user));
}

} // end namespace
