//===-- main.cpp ------------------------------------------------*- C++ -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

// This test is intended to create a situation in which one thread will exit
// while the debugger is stepping in another thread.

#include <pthread.h>
#include <unistd.h>

// Note that although hogging the CPU while waiting for a variable to change
// would be terrible in production code, it's great for testing since it
// avoids a lot of messy context switching to get multiple threads synchronized.
#define do_nothing()

#define pseudo_barrier_wait(bar) \
    --bar;                       \
    while (bar > 0)              \
        do_nothing();

#define pseudo_barrier_init(bar, count) (bar = count)

// A barrier to synchronize thread start.
volatile int g_barrier;

volatile int g_thread_exited = 0;

volatile int g_test = 0;

void *
step_thread_func (void *input)
{
    // Wait until both threads are started.
    pseudo_barrier_wait(g_barrier);

    g_test = 0;         // Set breakpoint here

    while (!g_thread_exited)
        g_test++;

    // One more time to provide a continue point
    g_test++;           // Continue from here

    // Return
    return NULL;
}

void *
exit_thread_func (void *input)
{
    // Wait until both threads are started.
    pseudo_barrier_wait(g_barrier);

    // Wait until the other thread is stepping.
    while (g_test == 0)
      do_nothing();

    // Return
    return NULL;
}

int main ()
{
    pthread_t thread_1;
    pthread_t thread_2;

    // Synchronize thread start so that doesn't happen during stepping.
    pseudo_barrier_init(g_barrier, 2);

    // Create a thread to hit the breakpoint.
    pthread_create (&thread_1, NULL, step_thread_func, NULL);

    // Create a thread to exit while we're stepping.
    pthread_create (&thread_2, NULL, exit_thread_func, NULL);

    // Wait for the exit thread to finish.
    pthread_join(thread_2, NULL);

    // Let the stepping thread know the other thread is gone.
    g_thread_exited = 1;

    // Wait for the stepping thread to finish.
    pthread_join(thread_1, NULL);

    return 0;
}
