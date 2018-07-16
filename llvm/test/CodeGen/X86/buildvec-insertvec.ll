; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc < %s -mtriple=x86_64-unknown-unknown -mattr=+sse2 | FileCheck %s --check-prefix=CHECK --check-prefix=SSE2
; RUN: llc < %s -mtriple=x86_64-unknown-unknown -mattr=+sse4.1 | FileCheck %s --check-prefix=CHECK --check-prefix=SSE41

define void @foo(<3 x float> %in, <4 x i8>* nocapture %out) nounwind {
; SSE2-LABEL: foo:
; SSE2:       # %bb.0:
; SSE2-NEXT:    cvttps2dq %xmm0, %xmm0
; SSE2-NEXT:    movl $255, %eax
; SSE2-NEXT:    movd %eax, %xmm1
; SSE2-NEXT:    shufps {{.*#+}} xmm1 = xmm1[0,0],xmm0[2,0]
; SSE2-NEXT:    shufps {{.*#+}} xmm0 = xmm0[0,1],xmm1[2,0]
; SSE2-NEXT:    andps {{.*}}(%rip), %xmm0
; SSE2-NEXT:    packuswb %xmm0, %xmm0
; SSE2-NEXT:    packuswb %xmm0, %xmm0
; SSE2-NEXT:    movd %xmm0, (%rdi)
; SSE2-NEXT:    retq
;
; SSE41-LABEL: foo:
; SSE41:       # %bb.0:
; SSE41-NEXT:    cvttps2dq %xmm0, %xmm0
; SSE41-NEXT:    movl $255, %eax
; SSE41-NEXT:    pinsrd $3, %eax, %xmm0
; SSE41-NEXT:    pshufb {{.*#+}} xmm0 = xmm0[0,4,8,12,u,u,u,u,u,u,u,u,u,u,u,u]
; SSE41-NEXT:    movd %xmm0, (%rdi)
; SSE41-NEXT:    retq
  %t0 = fptoui <3 x float> %in to <3 x i8>
  %t1 = shufflevector <3 x i8> %t0, <3 x i8> undef, <4 x i32> <i32 0, i32 1, i32 2, i32 undef>
  %t2 = insertelement <4 x i8> %t1, i8 -1, i32 3
  store <4 x i8> %t2, <4 x i8>* %out, align 4
  ret void
}

; Verify that the DAGCombiner doesn't wrongly fold a build_vector into a
; blend with a zero vector if the build_vector contains negative zero.

define <4 x float> @test_negative_zero_1(<4 x float> %A) {
; SSE2-LABEL: test_negative_zero_1:
; SSE2:       # %bb.0: # %entry
; SSE2-NEXT:    movaps %xmm0, %xmm1
; SSE2-NEXT:    movhlps {{.*#+}} xmm1 = xmm0[1],xmm1[1]
; SSE2-NEXT:    xorps %xmm2, %xmm2
; SSE2-NEXT:    movss {{.*#+}} xmm2 = xmm1[0],xmm2[1,2,3]
; SSE2-NEXT:    movss {{.*#+}} xmm1 = mem[0],zero,zero,zero
; SSE2-NEXT:    unpcklps {{.*#+}} xmm0 = xmm0[0],xmm1[0],xmm0[1],xmm1[1]
; SSE2-NEXT:    movlhps {{.*#+}} xmm0 = xmm0[0],xmm2[0]
; SSE2-NEXT:    retq
;
; SSE41-LABEL: test_negative_zero_1:
; SSE41:       # %bb.0: # %entry
; SSE41-NEXT:    insertps {{.*#+}} xmm0 = xmm0[0],mem[0],xmm0[2],zero
; SSE41-NEXT:    retq
entry:
  %0 = extractelement <4 x float> %A, i32 0
  %1 = insertelement <4 x float> undef, float %0, i32 0
  %2 = insertelement <4 x float> %1, float -0.0, i32 1
  %3 = extractelement <4 x float> %A, i32 2
  %4 = insertelement <4 x float> %2, float %3, i32 2
  %5 = insertelement <4 x float> %4, float 0.0, i32 3
  ret <4 x float> %5
}

; FIXME: This could be 'movhpd {{.*#+}} xmm0 = xmm0[0],mem[0]'.

define <2 x double> @test_negative_zero_2(<2 x double> %A) {
; SSE2-LABEL: test_negative_zero_2:
; SSE2:       # %bb.0: # %entry
; SSE2-NEXT:    movapd {{.*#+}} xmm1 = <u,-0>
; SSE2-NEXT:    movsd {{.*#+}} xmm1 = xmm0[0],xmm1[1]
; SSE2-NEXT:    movapd %xmm1, %xmm0
; SSE2-NEXT:    retq
;
; SSE41-LABEL: test_negative_zero_2:
; SSE41:       # %bb.0: # %entry
; SSE41-NEXT:    blendps {{.*#+}} xmm0 = xmm0[0,1],mem[2,3]
; SSE41-NEXT:    retq
entry:
  %0 = extractelement <2 x double> %A, i32 0
  %1 = insertelement <2 x double> undef, double %0, i32 0
  %2 = insertelement <2 x double> %1, double -0.0, i32 1
  ret <2 x double> %2
}

define <4 x float> @test_buildvector_v4f32_register(float %f0, float %f1, float %f2, float %f3) {
; SSE2-LABEL: test_buildvector_v4f32_register:
; SSE2:       # %bb.0:
; SSE2-NEXT:    unpcklps {{.*#+}} xmm2 = xmm2[0],xmm3[0],xmm2[1],xmm3[1]
; SSE2-NEXT:    unpcklps {{.*#+}} xmm0 = xmm0[0],xmm1[0],xmm0[1],xmm1[1]
; SSE2-NEXT:    movlhps {{.*#+}} xmm0 = xmm0[0],xmm2[0]
; SSE2-NEXT:    retq
;
; SSE41-LABEL: test_buildvector_v4f32_register:
; SSE41:       # %bb.0:
; SSE41-NEXT:    insertps {{.*#+}} xmm0 = xmm0[0],xmm1[0],xmm0[2,3]
; SSE41-NEXT:    insertps {{.*#+}} xmm0 = xmm0[0,1],xmm2[0],xmm0[3]
; SSE41-NEXT:    insertps {{.*#+}} xmm0 = xmm0[0,1,2],xmm3[0]
; SSE41-NEXT:    retq
  %ins0 = insertelement <4 x float> undef, float %f0, i32 0
  %ins1 = insertelement <4 x float> %ins0, float %f1, i32 1
  %ins2 = insertelement <4 x float> %ins1, float %f2, i32 2
  %ins3 = insertelement <4 x float> %ins2, float %f3, i32 3
  ret <4 x float> %ins3
}

define <4 x float> @test_buildvector_v4f32_load(float* %p0, float* %p1, float* %p2, float* %p3) {
; SSE2-LABEL: test_buildvector_v4f32_load:
; SSE2:       # %bb.0:
; SSE2-NEXT:    movss {{.*#+}} xmm0 = mem[0],zero,zero,zero
; SSE2-NEXT:    movss {{.*#+}} xmm1 = mem[0],zero,zero,zero
; SSE2-NEXT:    unpcklps {{.*#+}} xmm0 = xmm0[0],xmm1[0],xmm0[1],xmm1[1]
; SSE2-NEXT:    movss {{.*#+}} xmm1 = mem[0],zero,zero,zero
; SSE2-NEXT:    movss {{.*#+}} xmm2 = mem[0],zero,zero,zero
; SSE2-NEXT:    unpcklps {{.*#+}} xmm1 = xmm1[0],xmm2[0],xmm1[1],xmm2[1]
; SSE2-NEXT:    movlhps {{.*#+}} xmm0 = xmm0[0],xmm1[0]
; SSE2-NEXT:    retq
;
; SSE41-LABEL: test_buildvector_v4f32_load:
; SSE41:       # %bb.0:
; SSE41-NEXT:    movss {{.*#+}} xmm0 = mem[0],zero,zero,zero
; SSE41-NEXT:    insertps {{.*#+}} xmm0 = xmm0[0],mem[0],xmm0[2,3]
; SSE41-NEXT:    insertps {{.*#+}} xmm0 = xmm0[0,1],mem[0],xmm0[3]
; SSE41-NEXT:    insertps {{.*#+}} xmm0 = xmm0[0,1,2],mem[0]
; SSE41-NEXT:    retq
  %f0 = load float, float* %p0, align 4
  %f1 = load float, float* %p1, align 4
  %f2 = load float, float* %p2, align 4
  %f3 = load float, float* %p3, align 4
  %ins0 = insertelement <4 x float> undef, float %f0, i32 0
  %ins1 = insertelement <4 x float> %ins0, float %f1, i32 1
  %ins2 = insertelement <4 x float> %ins1, float %f2, i32 2
  %ins3 = insertelement <4 x float> %ins2, float %f3, i32 3
  ret <4 x float> %ins3
}

define <4 x float> @test_buildvector_v4f32_partial_load(float %f0, float %f1, float %f2, float* %p3) {
; SSE2-LABEL: test_buildvector_v4f32_partial_load:
; SSE2:       # %bb.0:
; SSE2-NEXT:    movss {{.*#+}} xmm3 = mem[0],zero,zero,zero
; SSE2-NEXT:    unpcklps {{.*#+}} xmm0 = xmm0[0],xmm1[0],xmm0[1],xmm1[1]
; SSE2-NEXT:    unpcklps {{.*#+}} xmm2 = xmm2[0],xmm3[0],xmm2[1],xmm3[1]
; SSE2-NEXT:    movlhps {{.*#+}} xmm0 = xmm0[0],xmm2[0]
; SSE2-NEXT:    retq
;
; SSE41-LABEL: test_buildvector_v4f32_partial_load:
; SSE41:       # %bb.0:
; SSE41-NEXT:    insertps {{.*#+}} xmm0 = xmm0[0],xmm1[0],xmm0[2,3]
; SSE41-NEXT:    insertps {{.*#+}} xmm0 = xmm0[0,1],xmm2[0],xmm0[3]
; SSE41-NEXT:    insertps {{.*#+}} xmm0 = xmm0[0,1,2],mem[0]
; SSE41-NEXT:    retq
  %f3 = load float, float* %p3, align 4
  %ins0 = insertelement <4 x float> undef, float %f0, i32 0
  %ins1 = insertelement <4 x float> %ins0, float %f1, i32 1
  %ins2 = insertelement <4 x float> %ins1, float %f2, i32 2
  %ins3 = insertelement <4 x float> %ins2, float %f3, i32 3
  ret <4 x float> %ins3
}

define <4 x i32> @test_buildvector_v4i32_register(i32 %a0, i32 %a1, i32 %a2, i32 %a3) {
; SSE2-LABEL: test_buildvector_v4i32_register:
; SSE2:       # %bb.0:
; SSE2-NEXT:    movd %ecx, %xmm0
; SSE2-NEXT:    movd %edx, %xmm1
; SSE2-NEXT:    punpckldq {{.*#+}} xmm1 = xmm1[0],xmm0[0],xmm1[1],xmm0[1]
; SSE2-NEXT:    movd %esi, %xmm2
; SSE2-NEXT:    movd %edi, %xmm0
; SSE2-NEXT:    punpckldq {{.*#+}} xmm0 = xmm0[0],xmm2[0],xmm0[1],xmm2[1]
; SSE2-NEXT:    punpcklqdq {{.*#+}} xmm0 = xmm0[0],xmm1[0]
; SSE2-NEXT:    retq
;
; SSE41-LABEL: test_buildvector_v4i32_register:
; SSE41:       # %bb.0:
; SSE41-NEXT:    movd %edi, %xmm0
; SSE41-NEXT:    pinsrd $1, %esi, %xmm0
; SSE41-NEXT:    pinsrd $2, %edx, %xmm0
; SSE41-NEXT:    pinsrd $3, %ecx, %xmm0
; SSE41-NEXT:    retq
  %ins0 = insertelement <4 x i32> undef, i32 %a0, i32 0
  %ins1 = insertelement <4 x i32> %ins0, i32 %a1, i32 1
  %ins2 = insertelement <4 x i32> %ins1, i32 %a2, i32 2
  %ins3 = insertelement <4 x i32> %ins2, i32 %a3, i32 3
  ret <4 x i32> %ins3
}

define <4 x i32> @test_buildvector_v4i32_partial(i32 %a0, i32 %a3) {
; SSE2-LABEL: test_buildvector_v4i32_partial:
; SSE2:       # %bb.0:
; SSE2-NEXT:    movd %edi, %xmm0
; SSE2-NEXT:    movd %esi, %xmm1
; SSE2-NEXT:    pshufd {{.*#+}} xmm1 = xmm1[0,0,1,1]
; SSE2-NEXT:    punpcklqdq {{.*#+}} xmm0 = xmm0[0],xmm1[0]
; SSE2-NEXT:    retq
;
; SSE41-LABEL: test_buildvector_v4i32_partial:
; SSE41:       # %bb.0:
; SSE41-NEXT:    movd %edi, %xmm0
; SSE41-NEXT:    pinsrd $3, %esi, %xmm0
; SSE41-NEXT:    retq
  %ins0 = insertelement <4 x i32> undef, i32   %a0, i32 0
  %ins1 = insertelement <4 x i32> %ins0, i32 undef, i32 1
  %ins2 = insertelement <4 x i32> %ins1, i32 undef, i32 2
  %ins3 = insertelement <4 x i32> %ins2, i32   %a3, i32 3
  ret <4 x i32> %ins3
}

define <4 x i32> @test_buildvector_v4i32_register_zero(i32 %a0, i32 %a2, i32 %a3) {
; CHECK-LABEL: test_buildvector_v4i32_register_zero:
; CHECK:       # %bb.0:
; CHECK-NEXT:    movd %edx, %xmm0
; CHECK-NEXT:    movd %esi, %xmm1
; CHECK-NEXT:    punpckldq {{.*#+}} xmm1 = xmm1[0],xmm0[0],xmm1[1],xmm0[1]
; CHECK-NEXT:    movd %edi, %xmm0
; CHECK-NEXT:    punpcklqdq {{.*#+}} xmm0 = xmm0[0],xmm1[0]
; CHECK-NEXT:    retq
  %ins0 = insertelement <4 x i32> undef, i32 %a0, i32 0
  %ins1 = insertelement <4 x i32> %ins0, i32   0, i32 1
  %ins2 = insertelement <4 x i32> %ins1, i32 %a2, i32 2
  %ins3 = insertelement <4 x i32> %ins2, i32 %a3, i32 3
  ret <4 x i32> %ins3
}

define <4 x i32> @test_buildvector_v4i32_register_zero_2(i32 %a1, i32 %a2, i32 %a3) {
; CHECK-LABEL: test_buildvector_v4i32_register_zero_2:
; CHECK:       # %bb.0:
; CHECK-NEXT:    movd %edx, %xmm0
; CHECK-NEXT:    movd %esi, %xmm1
; CHECK-NEXT:    punpckldq {{.*#+}} xmm1 = xmm1[0],xmm0[0],xmm1[1],xmm0[1]
; CHECK-NEXT:    movd %edi, %xmm0
; CHECK-NEXT:    shufps {{.*#+}} xmm0 = xmm0[1,0],xmm1[0,1]
; CHECK-NEXT:    retq
  %ins0 = insertelement <4 x i32> undef, i32   0, i32 0
  %ins1 = insertelement <4 x i32> %ins0, i32 %a1, i32 1
  %ins2 = insertelement <4 x i32> %ins1, i32 %a2, i32 2
  %ins3 = insertelement <4 x i32> %ins2, i32 %a3, i32 3
  ret <4 x i32> %ins3
}

define <8 x i16> @test_buildvector_v8i16_register(i16 %a0, i16 %a1, i16 %a2, i16 %a3, i16 %a4, i16 %a5, i16 %a6, i16 %a7) {
; SSE2-LABEL: test_buildvector_v8i16_register:
; SSE2:       # %bb.0:
; SSE2-NEXT:    movd {{.*#+}} xmm0 = mem[0],zero,zero,zero
; SSE2-NEXT:    movd {{.*#+}} xmm1 = mem[0],zero,zero,zero
; SSE2-NEXT:    punpcklwd {{.*#+}} xmm1 = xmm1[0],xmm0[0],xmm1[1],xmm0[1],xmm1[2],xmm0[2],xmm1[3],xmm0[3]
; SSE2-NEXT:    movd %r9d, %xmm0
; SSE2-NEXT:    movd %r8d, %xmm2
; SSE2-NEXT:    punpcklwd {{.*#+}} xmm2 = xmm2[0],xmm0[0],xmm2[1],xmm0[1],xmm2[2],xmm0[2],xmm2[3],xmm0[3]
; SSE2-NEXT:    punpckldq {{.*#+}} xmm2 = xmm2[0],xmm1[0],xmm2[1],xmm1[1]
; SSE2-NEXT:    movd %ecx, %xmm0
; SSE2-NEXT:    movd %edx, %xmm1
; SSE2-NEXT:    punpcklwd {{.*#+}} xmm1 = xmm1[0],xmm0[0],xmm1[1],xmm0[1],xmm1[2],xmm0[2],xmm1[3],xmm0[3]
; SSE2-NEXT:    movd %esi, %xmm3
; SSE2-NEXT:    movd %edi, %xmm0
; SSE2-NEXT:    punpcklwd {{.*#+}} xmm0 = xmm0[0],xmm3[0],xmm0[1],xmm3[1],xmm0[2],xmm3[2],xmm0[3],xmm3[3]
; SSE2-NEXT:    punpckldq {{.*#+}} xmm0 = xmm0[0],xmm1[0],xmm0[1],xmm1[1]
; SSE2-NEXT:    punpcklqdq {{.*#+}} xmm0 = xmm0[0],xmm2[0]
; SSE2-NEXT:    retq
;
; SSE41-LABEL: test_buildvector_v8i16_register:
; SSE41:       # %bb.0:
; SSE41-NEXT:    movd %edi, %xmm0
; SSE41-NEXT:    pinsrw $1, %esi, %xmm0
; SSE41-NEXT:    pinsrw $2, %edx, %xmm0
; SSE41-NEXT:    pinsrw $3, %ecx, %xmm0
; SSE41-NEXT:    pinsrw $4, %r8d, %xmm0
; SSE41-NEXT:    pinsrw $5, %r9d, %xmm0
; SSE41-NEXT:    pinsrw $6, {{[0-9]+}}(%rsp), %xmm0
; SSE41-NEXT:    pinsrw $7, {{[0-9]+}}(%rsp), %xmm0
; SSE41-NEXT:    retq
  %ins0 = insertelement <8 x i16> undef, i16 %a0, i32 0
  %ins1 = insertelement <8 x i16> %ins0, i16 %a1, i32 1
  %ins2 = insertelement <8 x i16> %ins1, i16 %a2, i32 2
  %ins3 = insertelement <8 x i16> %ins2, i16 %a3, i32 3
  %ins4 = insertelement <8 x i16> %ins3, i16 %a4, i32 4
  %ins5 = insertelement <8 x i16> %ins4, i16 %a5, i32 5
  %ins6 = insertelement <8 x i16> %ins5, i16 %a6, i32 6
  %ins7 = insertelement <8 x i16> %ins6, i16 %a7, i32 7
  ret <8 x i16> %ins7
}

define <8 x i16> @test_buildvector_v8i16_partial(i16 %a1, i16 %a3, i16 %a4, i16 %a5) {
; CHECK-LABEL: test_buildvector_v8i16_partial:
; CHECK:       # %bb.0:
; CHECK-NEXT:    pxor %xmm0, %xmm0
; CHECK-NEXT:    pinsrw $1, %edi, %xmm0
; CHECK-NEXT:    pinsrw $3, %esi, %xmm0
; CHECK-NEXT:    pinsrw $4, %edx, %xmm0
; CHECK-NEXT:    pinsrw $5, %ecx, %xmm0
; CHECK-NEXT:    retq
  %ins0 = insertelement <8 x i16> undef, i16 undef, i32 0
  %ins1 = insertelement <8 x i16> %ins0, i16   %a1, i32 1
  %ins2 = insertelement <8 x i16> %ins1, i16 undef, i32 2
  %ins3 = insertelement <8 x i16> %ins2, i16   %a3, i32 3
  %ins4 = insertelement <8 x i16> %ins3, i16   %a4, i32 4
  %ins5 = insertelement <8 x i16> %ins4, i16   %a5, i32 5
  %ins6 = insertelement <8 x i16> %ins5, i16 undef, i32 6
  %ins7 = insertelement <8 x i16> %ins6, i16 undef, i32 7
  ret <8 x i16> %ins7
}

define <8 x i16> @test_buildvector_v8i16_register_zero(i16 %a0, i16 %a3, i16 %a4, i16 %a5) {
; CHECK-LABEL: test_buildvector_v8i16_register_zero:
; CHECK:       # %bb.0:
; CHECK-NEXT:    pxor %xmm0, %xmm0
; CHECK-NEXT:    pinsrw $0, %edi, %xmm0
; CHECK-NEXT:    pinsrw $3, %esi, %xmm0
; CHECK-NEXT:    pinsrw $4, %edx, %xmm0
; CHECK-NEXT:    pinsrw $5, %ecx, %xmm0
; CHECK-NEXT:    retq
  %ins0 = insertelement <8 x i16> undef, i16   %a0, i32 0
  %ins1 = insertelement <8 x i16> %ins0, i16     0, i32 1
  %ins2 = insertelement <8 x i16> %ins1, i16     0, i32 2
  %ins3 = insertelement <8 x i16> %ins2, i16   %a3, i32 3
  %ins4 = insertelement <8 x i16> %ins3, i16   %a4, i32 4
  %ins5 = insertelement <8 x i16> %ins4, i16   %a5, i32 5
  %ins6 = insertelement <8 x i16> %ins5, i16     0, i32 6
  %ins7 = insertelement <8 x i16> %ins6, i16     0, i32 7
  ret <8 x i16> %ins7
}

define <8 x i16> @test_buildvector_v8i16_register_zero_2(i16 %a1, i16 %a3, i16 %a4, i16 %a5) {
; CHECK-LABEL: test_buildvector_v8i16_register_zero_2:
; CHECK:       # %bb.0:
; CHECK-NEXT:    pxor %xmm0, %xmm0
; CHECK-NEXT:    pinsrw $1, %edi, %xmm0
; CHECK-NEXT:    pinsrw $3, %esi, %xmm0
; CHECK-NEXT:    pinsrw $4, %edx, %xmm0
; CHECK-NEXT:    pinsrw $5, %ecx, %xmm0
; CHECK-NEXT:    retq
  %ins0 = insertelement <8 x i16> undef, i16     0, i32 0
  %ins1 = insertelement <8 x i16> %ins0, i16   %a1, i32 1
  %ins2 = insertelement <8 x i16> %ins1, i16     0, i32 2
  %ins3 = insertelement <8 x i16> %ins2, i16   %a3, i32 3
  %ins4 = insertelement <8 x i16> %ins3, i16   %a4, i32 4
  %ins5 = insertelement <8 x i16> %ins4, i16   %a5, i32 5
  %ins6 = insertelement <8 x i16> %ins5, i16     0, i32 6
  %ins7 = insertelement <8 x i16> %ins6, i16     0, i32 7
  ret <8 x i16> %ins7
}

define <16 x i8> @test_buildvector_v16i8_register(i8 %a0, i8 %a1, i8 %a2, i8 %a3, i8 %a4, i8 %a5, i8 %a6, i8 %a7, i8 %a8, i8 %a9, i8 %a10, i8 %a11, i8 %a12, i8 %a13, i8 %a14, i8 %a15) {
; SSE2-LABEL: test_buildvector_v16i8_register:
; SSE2:       # %bb.0:
; SSE2-NEXT:    movd {{.*#+}} xmm0 = mem[0],zero,zero,zero
; SSE2-NEXT:    movd {{.*#+}} xmm1 = mem[0],zero,zero,zero
; SSE2-NEXT:    punpcklbw {{.*#+}} xmm1 = xmm1[0],xmm0[0],xmm1[1],xmm0[1],xmm1[2],xmm0[2],xmm1[3],xmm0[3],xmm1[4],xmm0[4],xmm1[5],xmm0[5],xmm1[6],xmm0[6],xmm1[7],xmm0[7]
; SSE2-NEXT:    movd {{.*#+}} xmm0 = mem[0],zero,zero,zero
; SSE2-NEXT:    movd {{.*#+}} xmm2 = mem[0],zero,zero,zero
; SSE2-NEXT:    punpcklbw {{.*#+}} xmm2 = xmm2[0],xmm0[0],xmm2[1],xmm0[1],xmm2[2],xmm0[2],xmm2[3],xmm0[3],xmm2[4],xmm0[4],xmm2[5],xmm0[5],xmm2[6],xmm0[6],xmm2[7],xmm0[7]
; SSE2-NEXT:    punpcklwd {{.*#+}} xmm2 = xmm2[0],xmm1[0],xmm2[1],xmm1[1],xmm2[2],xmm1[2],xmm2[3],xmm1[3]
; SSE2-NEXT:    movd {{.*#+}} xmm0 = mem[0],zero,zero,zero
; SSE2-NEXT:    movd {{.*#+}} xmm1 = mem[0],zero,zero,zero
; SSE2-NEXT:    punpcklbw {{.*#+}} xmm1 = xmm1[0],xmm0[0],xmm1[1],xmm0[1],xmm1[2],xmm0[2],xmm1[3],xmm0[3],xmm1[4],xmm0[4],xmm1[5],xmm0[5],xmm1[6],xmm0[6],xmm1[7],xmm0[7]
; SSE2-NEXT:    movd {{.*#+}} xmm0 = mem[0],zero,zero,zero
; SSE2-NEXT:    movd {{.*#+}} xmm3 = mem[0],zero,zero,zero
; SSE2-NEXT:    punpcklbw {{.*#+}} xmm3 = xmm3[0],xmm0[0],xmm3[1],xmm0[1],xmm3[2],xmm0[2],xmm3[3],xmm0[3],xmm3[4],xmm0[4],xmm3[5],xmm0[5],xmm3[6],xmm0[6],xmm3[7],xmm0[7]
; SSE2-NEXT:    punpcklwd {{.*#+}} xmm3 = xmm3[0],xmm1[0],xmm3[1],xmm1[1],xmm3[2],xmm1[2],xmm3[3],xmm1[3]
; SSE2-NEXT:    punpckldq {{.*#+}} xmm3 = xmm3[0],xmm2[0],xmm3[1],xmm2[1]
; SSE2-NEXT:    movd {{.*#+}} xmm0 = mem[0],zero,zero,zero
; SSE2-NEXT:    movd {{.*#+}} xmm1 = mem[0],zero,zero,zero
; SSE2-NEXT:    punpcklbw {{.*#+}} xmm1 = xmm1[0],xmm0[0],xmm1[1],xmm0[1],xmm1[2],xmm0[2],xmm1[3],xmm0[3],xmm1[4],xmm0[4],xmm1[5],xmm0[5],xmm1[6],xmm0[6],xmm1[7],xmm0[7]
; SSE2-NEXT:    movd %r9d, %xmm0
; SSE2-NEXT:    movd %r8d, %xmm2
; SSE2-NEXT:    punpcklbw {{.*#+}} xmm2 = xmm2[0],xmm0[0],xmm2[1],xmm0[1],xmm2[2],xmm0[2],xmm2[3],xmm0[3],xmm2[4],xmm0[4],xmm2[5],xmm0[5],xmm2[6],xmm0[6],xmm2[7],xmm0[7]
; SSE2-NEXT:    punpcklwd {{.*#+}} xmm2 = xmm2[0],xmm1[0],xmm2[1],xmm1[1],xmm2[2],xmm1[2],xmm2[3],xmm1[3]
; SSE2-NEXT:    movd %ecx, %xmm0
; SSE2-NEXT:    movd %edx, %xmm1
; SSE2-NEXT:    punpcklbw {{.*#+}} xmm1 = xmm1[0],xmm0[0],xmm1[1],xmm0[1],xmm1[2],xmm0[2],xmm1[3],xmm0[3],xmm1[4],xmm0[4],xmm1[5],xmm0[5],xmm1[6],xmm0[6],xmm1[7],xmm0[7]
; SSE2-NEXT:    movd %esi, %xmm4
; SSE2-NEXT:    movd %edi, %xmm0
; SSE2-NEXT:    punpcklbw {{.*#+}} xmm0 = xmm0[0],xmm4[0],xmm0[1],xmm4[1],xmm0[2],xmm4[2],xmm0[3],xmm4[3],xmm0[4],xmm4[4],xmm0[5],xmm4[5],xmm0[6],xmm4[6],xmm0[7],xmm4[7]
; SSE2-NEXT:    punpcklwd {{.*#+}} xmm0 = xmm0[0],xmm1[0],xmm0[1],xmm1[1],xmm0[2],xmm1[2],xmm0[3],xmm1[3]
; SSE2-NEXT:    punpckldq {{.*#+}} xmm0 = xmm0[0],xmm2[0],xmm0[1],xmm2[1]
; SSE2-NEXT:    punpcklqdq {{.*#+}} xmm0 = xmm0[0],xmm3[0]
; SSE2-NEXT:    retq
;
; SSE41-LABEL: test_buildvector_v16i8_register:
; SSE41:       # %bb.0:
; SSE41-NEXT:    movd %edi, %xmm0
; SSE41-NEXT:    pinsrb $1, %esi, %xmm0
; SSE41-NEXT:    pinsrb $2, %edx, %xmm0
; SSE41-NEXT:    pinsrb $3, %ecx, %xmm0
; SSE41-NEXT:    pinsrb $4, %r8d, %xmm0
; SSE41-NEXT:    pinsrb $5, %r9d, %xmm0
; SSE41-NEXT:    pinsrb $6, {{[0-9]+}}(%rsp), %xmm0
; SSE41-NEXT:    pinsrb $7, {{[0-9]+}}(%rsp), %xmm0
; SSE41-NEXT:    pinsrb $8, {{[0-9]+}}(%rsp), %xmm0
; SSE41-NEXT:    pinsrb $9, {{[0-9]+}}(%rsp), %xmm0
; SSE41-NEXT:    pinsrb $10, {{[0-9]+}}(%rsp), %xmm0
; SSE41-NEXT:    pinsrb $11, {{[0-9]+}}(%rsp), %xmm0
; SSE41-NEXT:    pinsrb $12, {{[0-9]+}}(%rsp), %xmm0
; SSE41-NEXT:    pinsrb $13, {{[0-9]+}}(%rsp), %xmm0
; SSE41-NEXT:    pinsrb $14, {{[0-9]+}}(%rsp), %xmm0
; SSE41-NEXT:    pinsrb $15, {{[0-9]+}}(%rsp), %xmm0
; SSE41-NEXT:    retq
  %ins0  = insertelement <16 x i8> undef,  i8 %a0,  i32 0
  %ins1  = insertelement <16 x i8> %ins0,  i8 %a1,  i32 1
  %ins2  = insertelement <16 x i8> %ins1,  i8 %a2,  i32 2
  %ins3  = insertelement <16 x i8> %ins2,  i8 %a3,  i32 3
  %ins4  = insertelement <16 x i8> %ins3,  i8 %a4,  i32 4
  %ins5  = insertelement <16 x i8> %ins4,  i8 %a5,  i32 5
  %ins6  = insertelement <16 x i8> %ins5,  i8 %a6,  i32 6
  %ins7  = insertelement <16 x i8> %ins6,  i8 %a7,  i32 7
  %ins8  = insertelement <16 x i8> %ins7,  i8 %a8,  i32 8
  %ins9  = insertelement <16 x i8> %ins8,  i8 %a9,  i32 9
  %ins10 = insertelement <16 x i8> %ins9,  i8 %a10, i32 10
  %ins11 = insertelement <16 x i8> %ins10, i8 %a11, i32 11
  %ins12 = insertelement <16 x i8> %ins11, i8 %a12, i32 12
  %ins13 = insertelement <16 x i8> %ins12, i8 %a13, i32 13
  %ins14 = insertelement <16 x i8> %ins13, i8 %a14, i32 14
  %ins15 = insertelement <16 x i8> %ins14, i8 %a15, i32 15
  ret <16 x i8> %ins15
}

define <16 x i8> @test_buildvector_v16i8_partial(i8 %a2, i8 %a6, i8 %a8, i8 %a11, i8 %a12, i8 %a15) {
; SSE2-LABEL: test_buildvector_v16i8_partial:
; SSE2:       # %bb.0:
; SSE2-NEXT:    movzbl %dil, %eax
; SSE2-NEXT:    pinsrw $1, %eax, %xmm0
; SSE2-NEXT:    movzbl %sil, %eax
; SSE2-NEXT:    pinsrw $3, %eax, %xmm0
; SSE2-NEXT:    movzbl %dl, %eax
; SSE2-NEXT:    pinsrw $4, %eax, %xmm0
; SSE2-NEXT:    shll $8, %ecx
; SSE2-NEXT:    pinsrw $5, %ecx, %xmm0
; SSE2-NEXT:    movzbl %r8b, %eax
; SSE2-NEXT:    pinsrw $6, %eax, %xmm0
; SSE2-NEXT:    shll $8, %r9d
; SSE2-NEXT:    pinsrw $7, %r9d, %xmm0
; SSE2-NEXT:    retq
;
; SSE41-LABEL: test_buildvector_v16i8_partial:
; SSE41:       # %bb.0:
; SSE41-NEXT:    pxor %xmm0, %xmm0
; SSE41-NEXT:    pinsrb $2, %edi, %xmm0
; SSE41-NEXT:    pinsrb $6, %esi, %xmm0
; SSE41-NEXT:    pinsrb $8, %edx, %xmm0
; SSE41-NEXT:    pinsrb $11, %ecx, %xmm0
; SSE41-NEXT:    pinsrb $12, %r8d, %xmm0
; SSE41-NEXT:    pinsrb $15, %r9d, %xmm0
; SSE41-NEXT:    retq
  %ins0  = insertelement <16 x i8> undef,  i8 undef, i32 0
  %ins1  = insertelement <16 x i8> %ins0,  i8 undef, i32 1
  %ins2  = insertelement <16 x i8> %ins1,  i8   %a2, i32 2
  %ins3  = insertelement <16 x i8> %ins2,  i8 undef, i32 3
  %ins4  = insertelement <16 x i8> %ins3,  i8 undef, i32 4
  %ins5  = insertelement <16 x i8> %ins4,  i8 undef, i32 5
  %ins6  = insertelement <16 x i8> %ins5,  i8   %a6, i32 6
  %ins7  = insertelement <16 x i8> %ins6,  i8 undef, i32 7
  %ins8  = insertelement <16 x i8> %ins7,  i8   %a8, i32 8
  %ins9  = insertelement <16 x i8> %ins8,  i8 undef, i32 9
  %ins10 = insertelement <16 x i8> %ins9,  i8 undef, i32 10
  %ins11 = insertelement <16 x i8> %ins10, i8  %a11, i32 11
  %ins12 = insertelement <16 x i8> %ins11, i8  %a12, i32 12
  %ins13 = insertelement <16 x i8> %ins12, i8 undef, i32 13
  %ins14 = insertelement <16 x i8> %ins13, i8 undef, i32 14
  %ins15 = insertelement <16 x i8> %ins14, i8  %a15, i32 15
  ret <16 x i8> %ins15
}

define <16 x i8> @test_buildvector_v16i8_register_zero(i8 %a0, i8 %a4, i8 %a6, i8 %a8, i8 %a11, i8 %a12, i8 %a15) {
; SSE2-LABEL: test_buildvector_v16i8_register_zero:
; SSE2:       # %bb.0:
; SSE2-NEXT:    movzbl %sil, %eax
; SSE2-NEXT:    movzbl %dil, %esi
; SSE2-NEXT:    movd %esi, %xmm0
; SSE2-NEXT:    pinsrw $2, %eax, %xmm0
; SSE2-NEXT:    movzbl %dl, %eax
; SSE2-NEXT:    pinsrw $3, %eax, %xmm0
; SSE2-NEXT:    movzbl %cl, %eax
; SSE2-NEXT:    pinsrw $4, %eax, %xmm0
; SSE2-NEXT:    shll $8, %r8d
; SSE2-NEXT:    pinsrw $5, %r8d, %xmm0
; SSE2-NEXT:    movzbl %r9b, %eax
; SSE2-NEXT:    pinsrw $6, %eax, %xmm0
; SSE2-NEXT:    movl {{[0-9]+}}(%rsp), %eax
; SSE2-NEXT:    shll $8, %eax
; SSE2-NEXT:    pinsrw $7, %eax, %xmm0
; SSE2-NEXT:    retq
;
; SSE41-LABEL: test_buildvector_v16i8_register_zero:
; SSE41:       # %bb.0:
; SSE41-NEXT:    pxor %xmm0, %xmm0
; SSE41-NEXT:    pinsrb $0, %edi, %xmm0
; SSE41-NEXT:    pinsrb $4, %esi, %xmm0
; SSE41-NEXT:    pinsrb $6, %edx, %xmm0
; SSE41-NEXT:    pinsrb $8, %ecx, %xmm0
; SSE41-NEXT:    pinsrb $11, %r8d, %xmm0
; SSE41-NEXT:    pinsrb $12, %r9d, %xmm0
; SSE41-NEXT:    pinsrb $15, {{[0-9]+}}(%rsp), %xmm0
; SSE41-NEXT:    retq
  %ins0  = insertelement <16 x i8> undef,  i8   %a0, i32 0
  %ins1  = insertelement <16 x i8> %ins0,  i8     0, i32 1
  %ins2  = insertelement <16 x i8> %ins1,  i8     0, i32 2
  %ins3  = insertelement <16 x i8> %ins2,  i8     0, i32 3
  %ins4  = insertelement <16 x i8> %ins3,  i8   %a4, i32 4
  %ins5  = insertelement <16 x i8> %ins4,  i8     0, i32 5
  %ins6  = insertelement <16 x i8> %ins5,  i8   %a6, i32 6
  %ins7  = insertelement <16 x i8> %ins6,  i8     0, i32 7
  %ins8  = insertelement <16 x i8> %ins7,  i8   %a8, i32 8
  %ins9  = insertelement <16 x i8> %ins8,  i8     0, i32 9
  %ins10 = insertelement <16 x i8> %ins9,  i8     0, i32 10
  %ins11 = insertelement <16 x i8> %ins10, i8  %a11, i32 11
  %ins12 = insertelement <16 x i8> %ins11, i8  %a12, i32 12
  %ins13 = insertelement <16 x i8> %ins12, i8     0, i32 13
  %ins14 = insertelement <16 x i8> %ins13, i8     0, i32 14
  %ins15 = insertelement <16 x i8> %ins14, i8  %a15, i32 15
  ret <16 x i8> %ins15
}

define <16 x i8> @test_buildvector_v16i8_register_zero_2(i8 %a2, i8 %a3, i8 %a6, i8 %a8, i8 %a11, i8 %a12, i8 %a15) {
; SSE2-LABEL: test_buildvector_v16i8_register_zero_2:
; SSE2:       # %bb.0:
; SSE2-NEXT:    shll $8, %esi
; SSE2-NEXT:    movzbl %dil, %eax
; SSE2-NEXT:    orl %esi, %eax
; SSE2-NEXT:    pxor %xmm0, %xmm0
; SSE2-NEXT:    pinsrw $1, %eax, %xmm0
; SSE2-NEXT:    movzbl %dl, %eax
; SSE2-NEXT:    pinsrw $3, %eax, %xmm0
; SSE2-NEXT:    movzbl %cl, %eax
; SSE2-NEXT:    pinsrw $4, %eax, %xmm0
; SSE2-NEXT:    shll $8, %r8d
; SSE2-NEXT:    pinsrw $5, %r8d, %xmm0
; SSE2-NEXT:    movzbl %r9b, %eax
; SSE2-NEXT:    pinsrw $6, %eax, %xmm0
; SSE2-NEXT:    movl {{[0-9]+}}(%rsp), %eax
; SSE2-NEXT:    shll $8, %eax
; SSE2-NEXT:    pinsrw $7, %eax, %xmm0
; SSE2-NEXT:    retq
;
; SSE41-LABEL: test_buildvector_v16i8_register_zero_2:
; SSE41:       # %bb.0:
; SSE41-NEXT:    pxor %xmm0, %xmm0
; SSE41-NEXT:    pinsrb $2, %edi, %xmm0
; SSE41-NEXT:    pinsrb $3, %esi, %xmm0
; SSE41-NEXT:    pinsrb $6, %edx, %xmm0
; SSE41-NEXT:    pinsrb $8, %ecx, %xmm0
; SSE41-NEXT:    pinsrb $11, %r8d, %xmm0
; SSE41-NEXT:    pinsrb $12, %r9d, %xmm0
; SSE41-NEXT:    pinsrb $15, {{[0-9]+}}(%rsp), %xmm0
; SSE41-NEXT:    retq
  %ins0  = insertelement <16 x i8> undef,  i8     0, i32 0
  %ins1  = insertelement <16 x i8> %ins0,  i8     0, i32 1
  %ins2  = insertelement <16 x i8> %ins1,  i8   %a2, i32 2
  %ins3  = insertelement <16 x i8> %ins2,  i8   %a3, i32 3
  %ins4  = insertelement <16 x i8> %ins3,  i8     0, i32 4
  %ins5  = insertelement <16 x i8> %ins4,  i8     0, i32 5
  %ins6  = insertelement <16 x i8> %ins5,  i8   %a6, i32 6
  %ins7  = insertelement <16 x i8> %ins6,  i8     0, i32 7
  %ins8  = insertelement <16 x i8> %ins7,  i8   %a8, i32 8
  %ins9  = insertelement <16 x i8> %ins8,  i8     0, i32 9
  %ins10 = insertelement <16 x i8> %ins9,  i8     0, i32 10
  %ins11 = insertelement <16 x i8> %ins10, i8  %a11, i32 11
  %ins12 = insertelement <16 x i8> %ins11, i8  %a12, i32 12
  %ins13 = insertelement <16 x i8> %ins12, i8     0, i32 13
  %ins14 = insertelement <16 x i8> %ins13, i8     0, i32 14
  %ins15 = insertelement <16 x i8> %ins14, i8  %a15, i32 15
  ret <16 x i8> %ins15
}

; OSS-Fuzz #5688
; https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=5688
define <4 x i32> @ossfuzz5688(i32 %a0) {
; CHECK-LABEL: ossfuzz5688:
; CHECK:       # %bb.0:
; CHECK-NEXT:    retq
  %1 = insertelement <4 x i32> zeroinitializer, i32 -2147483648, i32 %a0
  %2 = extractelement <4 x i32> %1, i32 %a0
  %3 = extractelement <4 x i32> <i32 30, i32 53, i32 42, i32 12>, i32 %2
  %4 = extractelement <4 x i32> zeroinitializer, i32 %2
  %5 = insertelement <4 x i32> undef, i32 %3, i32 undef
  store i32 %4, i32* undef
  ret <4 x i32> %5
}
