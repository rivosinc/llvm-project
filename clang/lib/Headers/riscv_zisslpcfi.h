/*===------ riscv_zisslpcfi.h -Control-flow Integrity feature --------------===
 * Add RISCV Zisslpcfi extension with landing pads (forward) and shadow stack
 * (backward) CFI bits to ELF program property if they are enabled. Otherwise,
 * contents in this header file are unused. This file is mainly design for
 * assembly source code which want to enable CFI.
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */
#ifndef __RISCV_ZISSLPCFI_H
#define __RISCV_ZISSLPCFI_H

#ifdef __ASSEMBLER__
# ifdef __RISCV_ZISSLPCFI__

#  if __RISCV_ZISSLPCFI__ & 1
#   define _LPCLL(lower_label) lpcll lower_label
#   define _LPCML(middle_label) lpcml middle_label
#   define _LPCUL(upper_label) lpcul upper_label
#  endif
#  if __RISCV_ZISSLPCFI__ & 2
#   define _SSPUSH(link_reg) sspush link_reg
#   define _SSPOP(link_reg) sspop link_reg
#   define _SSCHKRA sschkra
#  endif

#  ifdef __LP64__
#   define __PROPERTY_ALIGN 3
#  else
#   define __PROPERTY_ALIGN 2
#  endif

	.pushsection ".note.gnu.property", "a"
	.p2align __PROPERTY_ALIGN
	.word 4			/* name length.  */
	.word 8+(1<<__PROPERTY_ALIGN) /* data length.  */
	/* NT_GNU_PROPERTY_TYPE_0.   */
	.word 5			/* note type.  */
	.asciz "GNU"		/* vendor name.  */
	.p2align __PROPERTY_ALIGN
	/* GNU_PROPERTY_RISCV_FEATURE_1_AND.  */
	.word 0xc0000003	/* pr_type.  */
	.word 4			/* pr_datasz.  */
	/* GNU_PROPERTY_RISCV_FEATURE_1_XXX.  */
	.word __RISCV_ZISSLPCFI__
	.p2align __PROPERTY_ALIGN
	.popsection

# endif // __RISCV_ZISSLPCFI__

# ifndef _LPCLL
#  define _LPCLL(lower_label)
# endif
# ifndef _LPCML
#  define _LPCML(middle_label)
# endif
# ifndef _LPCUL
#  define _LPCUL(upper_label)
# endif
# ifndef _SSPUSH
#  define _SSPUSH(link_reg)
# endif
# ifndef _SSPOP
#  define _SSPOP(link_reg)
# endif
# ifndef _SSCHKRA
#  define _SSCHKRA
# endif

#endif // __ASSEMBLER__
#endif // __RISCV_ZISSLPCFI_H
