; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt < %s -instcombine -S | FileCheck %s

define void @idom_sign_bit_check_edge_dominates(i64 %a) {
; CHECK-LABEL: @idom_sign_bit_check_edge_dominates(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[CMP:%.*]] = icmp slt i64 [[A:%.*]], 0
; CHECK-NEXT:    br i1 [[CMP]], label [[LAND_LHS_TRUE:%.*]], label [[LOR_RHS:%.*]]
; CHECK:       land.lhs.true:
; CHECK-NEXT:    br label [[LOR_END:%.*]]
; CHECK:       lor.rhs:
; CHECK-NEXT:    [[CMP2:%.*]] = icmp eq i64 [[A]], 0
; CHECK-NEXT:    br i1 [[CMP2]], label [[LOR_END]], label [[LAND_RHS:%.*]]
; CHECK:       land.rhs:
; CHECK-NEXT:    br label [[LOR_END]]
; CHECK:       lor.end:
; CHECK-NEXT:    ret void
;
entry:
  %cmp = icmp slt i64 %a, 0
  br i1 %cmp, label %land.lhs.true, label %lor.rhs

land.lhs.true:
  br label %lor.end

lor.rhs:
  %cmp2 = icmp sgt i64 %a, 0
  br i1 %cmp2, label %land.rhs, label %lor.end

land.rhs:
  br label %lor.end

lor.end:
  ret void
}

define void @idom_sign_bit_check_edge_not_dominates(i64 %a) {
; CHECK-LABEL: @idom_sign_bit_check_edge_not_dominates(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[CMP:%.*]] = icmp slt i64 [[A:%.*]], 0
; CHECK-NEXT:    br i1 [[CMP]], label [[LAND_LHS_TRUE:%.*]], label [[LOR_RHS:%.*]]
; CHECK:       land.lhs.true:
; CHECK-NEXT:    br i1 undef, label [[LOR_END:%.*]], label [[LOR_RHS]]
; CHECK:       lor.rhs:
; CHECK-NEXT:    [[CMP2:%.*]] = icmp sgt i64 [[A]], 0
; CHECK-NEXT:    br i1 [[CMP2]], label [[LAND_RHS:%.*]], label [[LOR_END]]
; CHECK:       land.rhs:
; CHECK-NEXT:    br label [[LOR_END]]
; CHECK:       lor.end:
; CHECK-NEXT:    ret void
;
entry:
  %cmp = icmp slt i64 %a, 0
  br i1 %cmp, label %land.lhs.true, label %lor.rhs

land.lhs.true:
  br i1 undef, label %lor.end, label %lor.rhs

lor.rhs:
  %cmp2 = icmp sgt i64 %a, 0
  br i1 %cmp2, label %land.rhs, label %lor.end

land.rhs:
  br label %lor.end

lor.end:
  ret void
}

define void @idom_sign_bit_check_edge_dominates_select(i64 %a, i64 %b) {
; CHECK-LABEL: @idom_sign_bit_check_edge_dominates_select(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[CMP:%.*]] = icmp slt i64 [[A:%.*]], 5
; CHECK-NEXT:    br i1 [[CMP]], label [[LAND_LHS_TRUE:%.*]], label [[LOR_RHS:%.*]]
; CHECK:       land.lhs.true:
; CHECK-NEXT:    br label [[LOR_END:%.*]]
; CHECK:       lor.rhs:
; CHECK-NEXT:    [[CMP3:%.*]] = icmp eq i64 [[A]], [[B:%.*]]
; CHECK-NEXT:    br i1 [[CMP3]], label [[LOR_END]], label [[LAND_RHS:%.*]]
; CHECK:       land.rhs:
; CHECK-NEXT:    br label [[LOR_END]]
; CHECK:       lor.end:
; CHECK-NEXT:    ret void
;
entry:
  %cmp = icmp slt i64 %a, 5
  br i1 %cmp, label %land.lhs.true, label %lor.rhs

land.lhs.true:
  br label %lor.end

lor.rhs:
  %cmp2 = icmp sgt i64 %a, 5
  %select = select i1 %cmp2, i64 %a, i64 5
  %cmp3 = icmp ne i64 %select, %b
  br i1 %cmp3, label %land.rhs, label %lor.end

land.rhs:
  br label %lor.end

lor.end:
  ret void
}

define void @idom_zbranch(i64 %a) {
; CHECK-LABEL: @idom_zbranch(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[CMP:%.*]] = icmp sgt i64 [[A:%.*]], 0
; CHECK-NEXT:    br i1 [[CMP]], label [[LOR_END:%.*]], label [[LOR_RHS:%.*]]
; CHECK:       lor.rhs:
; CHECK-NEXT:    [[CMP2:%.*]] = icmp slt i64 [[A]], 0
; CHECK-NEXT:    br i1 [[CMP2]], label [[LAND_RHS:%.*]], label [[LOR_END]]
; CHECK:       land.rhs:
; CHECK-NEXT:    br label [[LOR_END]]
; CHECK:       lor.end:
; CHECK-NEXT:    ret void
;
entry:
  %cmp = icmp sgt i64 %a, 0
  br i1 %cmp, label %lor.end, label %lor.rhs

lor.rhs:
  %cmp2 = icmp slt i64 %a, 0
  br i1 %cmp2, label %land.rhs, label %lor.end

land.rhs:
  br label %lor.end

lor.end:
  ret void
}

define void @idom_not_zbranch(i32 %a, i32 %b) {
; CHECK-LABEL: @idom_not_zbranch(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[CMP:%.*]] = icmp sgt i32 [[A:%.*]], 0
; CHECK-NEXT:    br i1 [[CMP]], label [[RETURN:%.*]], label [[IF_END:%.*]]
; CHECK:       if.end:
; CHECK-NEXT:    [[CMP2:%.*]] = icmp eq i32 [[A]], [[B:%.*]]
; CHECK-NEXT:    br i1 [[CMP2]], label [[RETURN]], label [[IF_THEN3:%.*]]
; CHECK:       if.then3:
; CHECK-NEXT:    br label [[RETURN]]
; CHECK:       return:
; CHECK-NEXT:    ret void
;
entry:
  %cmp = icmp sgt i32 %a, 0
  br i1 %cmp, label %return, label %if.end

if.end:
  %cmp1 = icmp slt i32 %a, 0
  %a. = select i1 %cmp1, i32 %a, i32 0
  %cmp2 = icmp ne i32 %a., %b
  br i1 %cmp2, label %if.then3, label %return

if.then3:
  br label %return

return:
  ret void
}

