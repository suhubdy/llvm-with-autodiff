; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc < %s -mtriple=i686-apple-darwin9 -mattr=+mmx,+sse4.2 | FileCheck %s --check-prefix=X32
; RUN: llc < %s -mtriple=x86_64-apple-darwin9 -mattr=+mmx,+sse4.2 | FileCheck %s --check-prefix=X64

; MMX insertelement is not available; these are promoted to xmm.
; (Without SSE they are split to two ints, and the code is much better.)

define x86_mmx @mmx_movzl(x86_mmx %x) nounwind {
; X32-LABEL: mmx_movzl:
; X32:       ## %bb.0:
; X32-NEXT:    subl $20, %esp
; X32-NEXT:    movl $32, %eax
; X32-NEXT:    movd %eax, %xmm0
; X32-NEXT:    movq %xmm0, (%esp)
; X32-NEXT:    movq (%esp), %mm0
; X32-NEXT:    addl $20, %esp
; X32-NEXT:    retl
;
; X64-LABEL: mmx_movzl:
; X64:       ## %bb.0:
; X64-NEXT:    movl $32, %eax
; X64-NEXT:    movd %eax, %xmm0
; X64-NEXT:    retq
  %tmp = bitcast x86_mmx %x to <2 x i32>
  %tmp3 = insertelement <2 x i32> %tmp, i32 32, i32 0
  %tmp8 = insertelement <2 x i32> %tmp3, i32 0, i32 1
  %tmp9 = bitcast <2 x i32> %tmp8 to x86_mmx
  ret x86_mmx %tmp9
}
