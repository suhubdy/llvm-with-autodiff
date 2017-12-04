//===-- tsan_report.cc ----------------------------------------------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file is a part of ThreadSanitizer (TSan), a race detector.
//
//===----------------------------------------------------------------------===//
#include "tsan_report.h"
#include "tsan_platform.h"
#include "tsan_rtl.h"
#include "sanitizer_common/sanitizer_file.h"
#include "sanitizer_common/sanitizer_placement_new.h"
#include "sanitizer_common/sanitizer_report_decorator.h"
#include "sanitizer_common/sanitizer_stacktrace_printer.h"

namespace __tsan {

ReportStack::ReportStack() : frames(nullptr), suppressable(false) {}

ReportStack *ReportStack::New() {
  void *mem = internal_alloc(MBlockReportStack, sizeof(ReportStack));
  return new(mem) ReportStack();
}

ReportLocation::ReportLocation(ReportLocationType type)
    : type(type), global(), heap_chunk_start(0), heap_chunk_size(0), tid(0),
      fd(0), suppressable(false), stack(nullptr) {}

ReportLocation *ReportLocation::New(ReportLocationType type) {
  void *mem = internal_alloc(MBlockReportStack, sizeof(ReportLocation));
  return new(mem) ReportLocation(type);
}

class Decorator: public __sanitizer::SanitizerCommonDecorator {
 public:
  Decorator() : SanitizerCommonDecorator() { }
  const char *Access()     { return Blue(); }
  const char *ThreadDescription()    { return Cyan(); }
  const char *Location()   { return Green(); }
  const char *Sleep()   { return Yellow(); }
  const char *Mutex()   { return Magenta(); }
};

ReportDesc::ReportDesc()
    : tag(kExternalTagNone)
    , stacks()
    , mops()
    , locs()
    , mutexes()
    , threads()
    , unique_tids()
    , sleep()
    , count() {
}

ReportMop::ReportMop()
    : mset() {
}

ReportDesc::~ReportDesc() {
  // FIXME(dvyukov): it must be leaking a lot of memory.
}

#if !SANITIZER_GO

const int kThreadBufSize = 32;
const char *thread_name(char *buf, int tid) {
  if (tid == 0)
    return "main thread";
  internal_snprintf(buf, kThreadBufSize, "thread T%d", tid);
  return buf;
}

static const char *ReportTypeString(ReportType typ, uptr tag) {
  if (typ == ReportTypeRace)
    return "data race";
  if (typ == ReportTypeVptrRace)
    return "data race on vptr (ctor/dtor vs virtual call)";
  if (typ == ReportTypeUseAfterFree)
    return "heap-use-after-free";
  if (typ == ReportTypeVptrUseAfterFree)
    return "heap-use-after-free (virtual call vs free)";
  if (typ == ReportTypeExternalRace) {
    const char *str = GetReportHeaderFromTag(tag);
    return str ? str : "race on external object";
  }
  if (typ == ReportTypeThreadLeak)
    return "thread leak";
  if (typ == ReportTypeMutexDestroyLocked)
    return "destroy of a locked mutex";
  if (typ == ReportTypeMutexDoubleLock)
    return "double lock of a mutex";
  if (typ == ReportTypeMutexInvalidAccess)
    return "use of an invalid mutex (e.g. uninitialized or destroyed)";
  if (typ == ReportTypeMutexBadUnlock)
    return "unlock of an unlocked mutex (or by a wrong thread)";
  if (typ == ReportTypeMutexBadReadLock)
    return "read lock of a write locked mutex";
  if (typ == ReportTypeMutexBadReadUnlock)
    return "read unlock of a write locked mutex";
  if (typ == ReportTypeSignalUnsafe)
    return "signal-unsafe call inside of a signal";
  if (typ == ReportTypeErrnoInSignal)
    return "signal handler spoils errno";
  if (typ == ReportTypeDeadlock)
    return "lock-order-inversion (potential deadlock)";
  return "";
}

#if SANITIZER_MAC
static const char *const kInterposedFunctionPrefix = "wrap_";
#else
static const char *const kInterposedFunctionPrefix = "__interceptor_";
#endif

void PrintStack(const ReportStack *ent) {
  if (ent == 0 || ent->frames == 0) {
    Printf("    [failed to restore the stack]\n\n");
    return;
  }
  SymbolizedStack *frame = ent->frames;
  for (int i = 0; frame && frame->info.address; frame = frame->next, i++) {
    InternalScopedString res(2 * GetPageSizeCached());
    RenderFrame(&res, common_flags()->stack_trace_format, i, frame->info,
                common_flags()->symbolize_vs_style,
                common_flags()->strip_path_prefix, kInterposedFunctionPrefix);
    Printf("%s\n", res.data());
  }
  Printf("\n");
}

static void PrintMutexSet(Vector<ReportMopMutex> const& mset) {
  for (uptr i = 0; i < mset.Size(); i++) {
    if (i == 0)
      Printf(" (mutexes:");
    const ReportMopMutex m = mset[i];
    Printf(" %s M%llu", m.write ? "write" : "read", m.id);
    Printf(i == mset.Size() - 1 ? ")" : ",");
  }
}

static const char *MopDesc(bool first, bool write, bool atomic) {
  return atomic ? (first ? (write ? "Atomic write" : "Atomic read")
                : (write ? "Previous atomic write" : "Previous atomic read"))
                : (first ? (write ? "Write" : "Read")
                : (write ? "Previous write" : "Previous read"));
}

static const char *ExternalMopDesc(bool first, bool write) {
  return first ? (write ? "Modifying" : "Read-only")
               : (write ? "Previous modifying" : "Previous read-only");
}

static void PrintMop(const ReportMop *mop, bool first) {
  Decorator d;
  char thrbuf[kThreadBufSize];
  Printf("%s", d.Access());
  if (mop->external_tag == kExternalTagNone) {
    Printf("  %s of size %d at %p by %s",
           MopDesc(first, mop->write, mop->atomic), mop->size,
           (void *)mop->addr, thread_name(thrbuf, mop->tid));
  } else {
    const char *object_type = GetObjectTypeFromTag(mop->external_tag);
    if (object_type == nullptr)
        object_type = "external object";
    Printf("  %s access of %s at %p by %s",
           ExternalMopDesc(first, mop->write), object_type,
           (void *)mop->addr, thread_name(thrbuf, mop->tid));
  }
  PrintMutexSet(mop->mset);
  Printf(":\n");
  Printf("%s", d.Default());
  PrintStack(mop->stack);
}

static void PrintLocation(const ReportLocation *loc) {
  Decorator d;
  char thrbuf[kThreadBufSize];
  bool print_stack = false;
  Printf("%s", d.Location());
  if (loc->type == ReportLocationGlobal) {
    const DataInfo &global = loc->global;
    if (global.size != 0)
      Printf("  Location is global '%s' of size %zu at %p (%s+%p)\n\n",
             global.name, global.size, global.start,
             StripModuleName(global.module), global.module_offset);
    else
      Printf("  Location is global '%s' at %p (%s+%p)\n\n", global.name,
             global.start, StripModuleName(global.module),
             global.module_offset);
  } else if (loc->type == ReportLocationHeap) {
    char thrbuf[kThreadBufSize];
    const char *object_type = GetObjectTypeFromTag(loc->external_tag);
    if (!object_type) {
      Printf("  Location is heap block of size %zu at %p allocated by %s:\n",
             loc->heap_chunk_size, loc->heap_chunk_start,
             thread_name(thrbuf, loc->tid));
    } else {
      Printf("  Location is %s of size %zu at %p allocated by %s:\n",
             object_type, loc->heap_chunk_size, loc->heap_chunk_start,
             thread_name(thrbuf, loc->tid));
    }
    print_stack = true;
  } else if (loc->type == ReportLocationStack) {
    Printf("  Location is stack of %s.\n\n", thread_name(thrbuf, loc->tid));
  } else if (loc->type == ReportLocationTLS) {
    Printf("  Location is TLS of %s.\n\n", thread_name(thrbuf, loc->tid));
  } else if (loc->type == ReportLocationFD) {
    Printf("  Location is file descriptor %d created by %s at:\n",
        loc->fd, thread_name(thrbuf, loc->tid));
    print_stack = true;
  }
  Printf("%s", d.Default());
  if (print_stack)
    PrintStack(loc->stack);
}

static void PrintMutexShort(const ReportMutex *rm, const char *after) {
  Decorator d;
  Printf("%sM%zd%s%s", d.Mutex(), rm->id, d.Default(), after);
}

static void PrintMutexShortWithAddress(const ReportMutex *rm,
                                       const char *after) {
  Decorator d;
  Printf("%sM%zd (%p)%s%s", d.Mutex(), rm->id, rm->addr, d.Default(), after);
}

static void PrintMutex(const ReportMutex *rm) {
  Decorator d;
  if (rm->destroyed) {
    Printf("%s", d.Mutex());
    Printf("  Mutex M%llu is already destroyed.\n\n", rm->id);
    Printf("%s", d.Default());
  } else {
    Printf("%s", d.Mutex());
    Printf("  Mutex M%llu (%p) created at:\n", rm->id, rm->addr);
    Printf("%s", d.Default());
    PrintStack(rm->stack);
  }
}

static void PrintThread(const ReportThread *rt) {
  Decorator d;
  if (rt->id == 0)  // Little sense in describing the main thread.
    return;
  Printf("%s", d.ThreadDescription());
  Printf("  Thread T%d", rt->id);
  if (rt->name && rt->name[0] != '\0')
    Printf(" '%s'", rt->name);
  char thrbuf[kThreadBufSize];
  const char *thread_status = rt->running ? "running" : "finished";
  if (rt->workerthread) {
    Printf(" (tid=%zu, %s) is a GCD worker thread\n", rt->os_id, thread_status);
    Printf("\n");
    Printf("%s", d.Default());
    return;
  }
  Printf(" (tid=%zu, %s) created by %s", rt->os_id, thread_status,
         thread_name(thrbuf, rt->parent_tid));
  if (rt->stack)
    Printf(" at:");
  Printf("\n");
  Printf("%s", d.Default());
  PrintStack(rt->stack);
}

static void PrintSleep(const ReportStack *s) {
  Decorator d;
  Printf("%s", d.Sleep());
  Printf("  As if synchronized via sleep:\n");
  Printf("%s", d.Default());
  PrintStack(s);
}

static ReportStack *ChooseSummaryStack(const ReportDesc *rep) {
  if (rep->mops.Size())
    return rep->mops[0]->stack;
  if (rep->stacks.Size())
    return rep->stacks[0];
  if (rep->mutexes.Size())
    return rep->mutexes[0]->stack;
  if (rep->threads.Size())
    return rep->threads[0]->stack;
  return 0;
}

static bool FrameIsInternal(const SymbolizedStack *frame) {
  if (frame == 0)
    return false;
  const char *file = frame->info.file;
  const char *module = frame->info.module;
  if (file != 0 &&
      (internal_strstr(file, "tsan_interceptors.cc") ||
       internal_strstr(file, "sanitizer_common_interceptors.inc") ||
       internal_strstr(file, "tsan_interface_")))
    return true;
  if (module != 0 && (internal_strstr(module, "libclang_rt.tsan_")))
    return true;
  return false;
}

static SymbolizedStack *SkipTsanInternalFrames(SymbolizedStack *frames) {
  while (FrameIsInternal(frames) && frames->next)
    frames = frames->next;
  return frames;
}

void PrintReport(const ReportDesc *rep) {
  Decorator d;
  Printf("==================\n");
  const char *rep_typ_str = ReportTypeString(rep->typ, rep->tag);
  Printf("%s", d.Warning());
  Printf("WARNING: ThreadSanitizer: %s (pid=%d)\n", rep_typ_str,
         (int)internal_getpid());
  Printf("%s", d.Default());

  if (rep->typ == ReportTypeDeadlock) {
    char thrbuf[kThreadBufSize];
    Printf("  Cycle in lock order graph: ");
    for (uptr i = 0; i < rep->mutexes.Size(); i++)
      PrintMutexShortWithAddress(rep->mutexes[i], " => ");
    PrintMutexShort(rep->mutexes[0], "\n\n");
    CHECK_GT(rep->mutexes.Size(), 0U);
    CHECK_EQ(rep->mutexes.Size() * (flags()->second_deadlock_stack ? 2 : 1),
             rep->stacks.Size());
    for (uptr i = 0; i < rep->mutexes.Size(); i++) {
      Printf("  Mutex ");
      PrintMutexShort(rep->mutexes[(i + 1) % rep->mutexes.Size()],
                      " acquired here while holding mutex ");
      PrintMutexShort(rep->mutexes[i], " in ");
      Printf("%s", d.ThreadDescription());
      Printf("%s:\n", thread_name(thrbuf, rep->unique_tids[i]));
      Printf("%s", d.Default());
      if (flags()->second_deadlock_stack) {
        PrintStack(rep->stacks[2*i]);
        Printf("  Mutex ");
        PrintMutexShort(rep->mutexes[i],
                        " previously acquired by the same thread here:\n");
        PrintStack(rep->stacks[2*i+1]);
      } else {
        PrintStack(rep->stacks[i]);
        if (i == 0)
          Printf("    Hint: use TSAN_OPTIONS=second_deadlock_stack=1 "
                 "to get more informative warning message\n\n");
      }
    }
  } else {
    for (uptr i = 0; i < rep->stacks.Size(); i++) {
      if (i)
        Printf("  and:\n");
      PrintStack(rep->stacks[i]);
    }
  }

  for (uptr i = 0; i < rep->mops.Size(); i++)
    PrintMop(rep->mops[i], i == 0);

  if (rep->sleep)
    PrintSleep(rep->sleep);

  for (uptr i = 0; i < rep->locs.Size(); i++)
    PrintLocation(rep->locs[i]);

  if (rep->typ != ReportTypeDeadlock) {
    for (uptr i = 0; i < rep->mutexes.Size(); i++)
      PrintMutex(rep->mutexes[i]);
  }

  for (uptr i = 0; i < rep->threads.Size(); i++)
    PrintThread(rep->threads[i]);

  if (rep->typ == ReportTypeThreadLeak && rep->count > 1)
    Printf("  And %d more similar thread leaks.\n\n", rep->count - 1);

  if (ReportStack *stack = ChooseSummaryStack(rep)) {
    if (SymbolizedStack *frame = SkipTsanInternalFrames(stack->frames))
      ReportErrorSummary(rep_typ_str, frame->info);
  }

  if (common_flags()->print_module_map == 2) PrintModuleMap();

  Printf("==================\n");
}

#else  // #if !SANITIZER_GO

const int kMainThreadId = 1;

void PrintStack(const ReportStack *ent) {
  if (ent == 0 || ent->frames == 0) {
    Printf("  [failed to restore the stack]\n");
    return;
  }
  SymbolizedStack *frame = ent->frames;
  for (int i = 0; frame; frame = frame->next, i++) {
    const AddressInfo &info = frame->info;
    Printf("  %s()\n      %s:%d +0x%zx\n", info.function,
        StripPathPrefix(info.file, common_flags()->strip_path_prefix),
        info.line, (void *)info.module_offset);
  }
}

static void PrintMop(const ReportMop *mop, bool first) {
  Printf("\n");
  Printf("%s at %p by ",
      (first ? (mop->write ? "Write" : "Read")
             : (mop->write ? "Previous write" : "Previous read")), mop->addr);
  if (mop->tid == kMainThreadId)
    Printf("main goroutine:\n");
  else
    Printf("goroutine %d:\n", mop->tid);
  PrintStack(mop->stack);
}

static void PrintLocation(const ReportLocation *loc) {
  switch (loc->type) {
  case ReportLocationHeap: {
    Printf("\n");
    Printf("Heap block of size %zu at %p allocated by ",
        loc->heap_chunk_size, loc->heap_chunk_start);
    if (loc->tid == kMainThreadId)
      Printf("main goroutine:\n");
    else
      Printf("goroutine %d:\n", loc->tid);
    PrintStack(loc->stack);
    break;
  }
  case ReportLocationGlobal: {
    Printf("\n");
    Printf("Global var %s of size %zu at %p declared at %s:%zu\n",
        loc->global.name, loc->global.size, loc->global.start,
        loc->global.file, loc->global.line);
    break;
  }
  default:
    break;
  }
}

static void PrintThread(const ReportThread *rt) {
  if (rt->id == kMainThreadId)
    return;
  Printf("\n");
  Printf("Goroutine %d (%s) created at:\n",
    rt->id, rt->running ? "running" : "finished");
  PrintStack(rt->stack);
}

void PrintReport(const ReportDesc *rep) {
  Printf("==================\n");
  if (rep->typ == ReportTypeRace) {
    Printf("WARNING: DATA RACE");
    for (uptr i = 0; i < rep->mops.Size(); i++)
      PrintMop(rep->mops[i], i == 0);
    for (uptr i = 0; i < rep->locs.Size(); i++)
      PrintLocation(rep->locs[i]);
    for (uptr i = 0; i < rep->threads.Size(); i++)
      PrintThread(rep->threads[i]);
  } else if (rep->typ == ReportTypeDeadlock) {
    Printf("WARNING: DEADLOCK\n");
    for (uptr i = 0; i < rep->mutexes.Size(); i++) {
      Printf("Goroutine %d lock mutex %d while holding mutex %d:\n",
          999, rep->mutexes[i]->id,
          rep->mutexes[(i+1) % rep->mutexes.Size()]->id);
      PrintStack(rep->stacks[2*i]);
      Printf("\n");
      Printf("Mutex %d was previously locked here:\n",
          rep->mutexes[(i+1) % rep->mutexes.Size()]->id);
      PrintStack(rep->stacks[2*i + 1]);
      Printf("\n");
    }
  }
  Printf("==================\n");
}

#endif

}  // namespace __tsan
