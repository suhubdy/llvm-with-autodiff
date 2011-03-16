; RUN: llc -asm-verbose=true -O1 %s -o - | FileCheck %s

; // The variable 'x' live on both R0 and R1, so they need an entry in .debug_loc table
; // For that, the DW_AT_location needs to have relocation to that section
; extern int g(int, int);
; extern int a;
; 
; void f(void) {
;   int x;
;   a = g(0, 0);
;   x = 1;
;   while (x & 1) { x *= a; }
;   a = g(x, 0);
;   x = 2;
;   while (x & 2) { x *= a; }
;   a = g(0, x);
; }

; // The 'x' variable and its symbol reference location
; CHECK: @ Abbrev [{{.*}}] 0x{{.*}}:0x{{.*}} DW_TAG_variable
; CHECK-NEXT: @ DW_AT_name
; CHECK-NEXT: .byte 0
; CHECK-NEXT: @ DW_AT_decl_file
; CHECK-NEXT: @ DW_AT_decl_line
; CHECK-NEXT: @ DW_AT_type
; CHECK-NEXT: .long .Ldebug_loc0            @ DW_AT_location
; CHECK-NEXT: .byte 0                       @ End Of Children Mark

; // The .debug_loc entry, with the two registers
; CHECK: .Ldebug_loc0:
; CHECK:  .long .Ltmp{{.*}}
; CHECK:  .long .Ltmp{{.*}}
; CHECK:  .short 1                     @ Loc expr size
; CHECK:  .byte 80                      @ DW_OP_reg0
; CHECK:  .long .Ltmp{{.*}}
; CHECK:  .long .Lfunc_end0
; CHECK:  .short 1                     @ Loc expr size
; CHECK:  .byte 81                      @ DW_OP_reg1
; CHECK:  .long 0
; CHECK:  .long 0


; ModuleID = 'simple.c'
target datalayout = "e-p:32:32:32-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-n32"
target triple = "armv7-none--eabi"

@a = external global i32

define void @f() nounwind {
entry:
  %call = tail call i32 @g(i32 0, i32 0) nounwind, !dbg !8
  store i32 %call, i32* @a, align 4, !dbg !8, !tbaa !9
  tail call void @llvm.dbg.value(metadata !12, i64 0, metadata !5), !dbg !13
  br label %while.body

while.body:                                       ; preds = %entry, %while.body
  %x.017 = phi i32 [ 1, %entry ], [ %mul, %while.body ]
  %mul = mul nsw i32 %call, %x.017, !dbg !14
  %and = and i32 %mul, 1, !dbg !14
  %tobool = icmp eq i32 %and, 0, !dbg !14
  br i1 %tobool, label %while.end, label %while.body, !dbg !14

while.end:                                        ; preds = %while.body
  tail call void @llvm.dbg.value(metadata !{i32 %mul}, i64 0, metadata !5), !dbg !14
  %call4 = tail call i32 @g(i32 %mul, i32 0) nounwind, !dbg !15
  store i32 %call4, i32* @a, align 4, !dbg !15, !tbaa !9
  tail call void @llvm.dbg.value(metadata !16, i64 0, metadata !5), !dbg !17
  br label %while.body9

while.body9:                                      ; preds = %while.end, %while.body9
  %x.116 = phi i32 [ 2, %while.end ], [ %mul12, %while.body9 ]
  %mul12 = mul nsw i32 %call4, %x.116, !dbg !18
  %and7 = and i32 %mul12, 2, !dbg !18
  %tobool8 = icmp eq i32 %and7, 0, !dbg !18
  br i1 %tobool8, label %while.end13, label %while.body9, !dbg !18

while.end13:                                      ; preds = %while.body9
  tail call void @llvm.dbg.value(metadata !{i32 %mul12}, i64 0, metadata !5), !dbg !18
  %call15 = tail call i32 @g(i32 0, i32 %mul12) nounwind, !dbg !19
  store i32 %call15, i32* @a, align 4, !dbg !19, !tbaa !9
  ret void, !dbg !20
}

declare i32 @g(i32, i32)

declare void @llvm.dbg.value(metadata, i64, metadata) nounwind readnone

!llvm.dbg.sp = !{!0}
!llvm.dbg.lv.f = !{!5}

!0 = metadata !{i32 589870, i32 0, metadata !1, metadata !"f", metadata !"f", metadata !"", metadata !1, i32 4, metadata !3, i1 false, i1 true, i32 0, i32 0, i32 0, i32 256, i1 true, void ()* @f} ; [ DW_TAG_subprogram ]
!1 = metadata !{i32 589865, metadata !"simple.c", metadata !"/home/rengol01/temp/tests/dwarf/relocation", metadata !2} ; [ DW_TAG_file_type ]
!2 = metadata !{i32 589841, i32 0, i32 12, metadata !"simple.c", metadata !"/home/rengol01/temp/tests/dwarf/relocation", metadata !"clang version 3.0 (trunk)", i1 true, i1 true, metadata !"", i32 0} ; [ DW_TAG_compile_unit ]
!3 = metadata !{i32 589845, metadata !1, metadata !"", metadata !1, i32 0, i64 0, i64 0, i32 0, i32 0, i32 0, metadata !4, i32 0, i32 0} ; [ DW_TAG_subroutine_type ]
!4 = metadata !{null}
!5 = metadata !{i32 590080, metadata !6, metadata !"x", metadata !1, i32 5, metadata !7, i32 0} ; [ DW_TAG_auto_variable ]
!6 = metadata !{i32 589835, metadata !0, i32 4, i32 14, metadata !1, i32 0} ; [ DW_TAG_lexical_block ]
!7 = metadata !{i32 589860, metadata !2, metadata !"int", null, i32 0, i64 32, i64 32, i64 0, i32 0, i32 5} ; [ DW_TAG_base_type ]
!8 = metadata !{i32 6, i32 3, metadata !6, null}
!9 = metadata !{metadata !"int", metadata !10}
!10 = metadata !{metadata !"omnipotent char", metadata !11}
!11 = metadata !{metadata !"Simple C/C++ TBAA", null}
!12 = metadata !{i32 1}
!13 = metadata !{i32 7, i32 3, metadata !6, null}
!14 = metadata !{i32 8, i32 3, metadata !6, null}
!15 = metadata !{i32 9, i32 3, metadata !6, null}
!16 = metadata !{i32 2}
!17 = metadata !{i32 10, i32 3, metadata !6, null}
!18 = metadata !{i32 11, i32 3, metadata !6, null}
!19 = metadata !{i32 12, i32 3, metadata !6, null}
!20 = metadata !{i32 13, i32 1, metadata !6, null}
