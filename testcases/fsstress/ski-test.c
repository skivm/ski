
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <stdio.h>
#include <stdlib.h>
#include <sched.h>
#include <pthread.h>
#include <unistd.h>
#include <string.h>
#include <sys/syscall.h>
#include <sys/mman.h>
#include <fcntl.h>
#include "ski-hyper.h"
#include "ski-barriers.h"
#include <assert.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/wait.h>

#define MAX_SAFE_STACK 2*1024
#define MAX_CPUS 16


//int with_hypercall = 0; Replaced by STD_SKI_HYPERCALLS
extern int STD_SKI_HYPERCALLS;
extern int STD_SKI_SOFT_EXIT_BARRIER;

//int with_soft_exit_barrier = 0;
int with_barriers = 1;
int with_info = 1;
int with_stack_prefault = 1;
int with_mlock_prefault = 0;
int with_fork = 1;
int mlock_parametrs = MCL_CURRENT| MCL_FUTURE;
int max_instructions = 1;  // Can be overwritten at the command line

barrier_t *usermode_barrier;
pthread_mutex_t * volatile printf_mutex = NULL;

static void * shared_malloc(int size, char* name, int current_cpu) {
	int fd = shm_open(name, O_RDWR | O_CREAT, 0777);
	assert(fd >= 0);

	int ft = ftruncate(fd, size);
	assert(ft == 0);

    void *ptr=mmap(0,size,
        PROT_READ+PROT_WRITE,
        MAP_SHARED,
        //MAP_SHARED+MAP_ANONYMOUS,
        fd,0);
    assert(ptr);
    return ptr;
}

void shared_printf_init(int current_cpu){
	
    pthread_mutexattr_t attr;
	static int is_init = 0;
	
	if (is_init){
		return;
	}
	is_init = 1;

    if(with_fork){
        printf_mutex = shared_malloc(sizeof(pthread_mutex_t), "SKI_shared_printf", current_cpu);
        if(current_cpu==0){
			pthread_mutexattr_init(&attr);
		    if(pthread_mutexattr_setpshared(&attr, PTHREAD_PROCESS_SHARED)){
			    perror("Mutex PTHREAD_PROCESS_SHARED");
				exit(1);
	        }
	
		    pthread_mutex_init(printf_mutex, &attr);
		}
    }
}

void shared_printf(char *format,...)
{
    va_list args;
    va_start(args, format);

    if(with_fork){
        pthread_mutex_lock(printf_mutex);
		printf("[SKI] ");
        vprintf(format, args);
        fflush(stdout);
        pthread_mutex_unlock(printf_mutex);
    }else{
		printf("[SKI] ");
        vprintf(format, args);
    }
    va_end(args);
    return;
}


static void stack_prefault(void) {
    unsigned char dummy[MAX_SAFE_STACK];

    memset(dummy, 0, MAX_SAFE_STACK);
    return;
}

hypercall_io hio_enter;
hypercall_io hio_exit;

static int ski_thread_start(int thread_num, int total_cpus, int dry_run){
    char str[256];
    pid_t tid;

    pthread_attr_t attr;
    cpu_set_t cpuset;
    pthread_t self;

    memset(str, 0, sizeof(str));

    if(with_stack_prefault){
        stack_prefault();
    }

	if(dry_run){
		return 0;
	}

    tid = syscall(SYS_gettid);
    shared_printf("[%d] Thread id: %d\n", thread_num, tid);

    self = pthread_self();
    pthread_getattr_np(self, &attr);
    int ret = pthread_attr_getaffinity_np(&attr, sizeof(cpuset), &cpuset);
    if (ret){
        shared_printf("[%d] Error: Unable get thread attributes!\n", thread_num);
        exit(1);
    }

    // initialize the hypercall parameters
    hypercall_io_init(&hio_enter);
    hypercall_io_init(&hio_exit);
    hio_enter.hypercall_type = HYPERCALL_IO_TYPE_TEST_ENTER;
    hio_exit.hypercall_type = HYPERCALL_IO_TYPE_TEST_EXIT;
    hio_enter.p.hio_test_enter.gh_nr_instr = max_instructions;
    hio_enter.p.hio_test_enter.gh_nr_cpus = total_cpus;
    hio_enter.p.hio_test_enter.gh_disable_interrupts = 1;

    if(with_barriers){
		shared_printf("[%d] Going into usermode barrier\n", thread_num );
        barrier_wait(usermode_barrier);
		shared_printf("[%d] Passed the usermode barrier\n", thread_num ); //XXX: Should take this out...
    }else{
		shared_printf("[%d] Usermode barrier disabled\n", thread_num );
	}
	
	int hypercall_ret = 0;

    if(STD_SKI_HYPERCALLS){
        hypercall(&hio_enter);
		hypercall_ret = hio_enter.p.hio_test_enter.hg_res;
    }
	return hypercall_ret;
	// Actual test run just after this
}

static void ski_thread_finish(int thread_num, int dry_run){
	// Actual test ran just before this

	if(dry_run){
		// Mostly meant to just pre fault the data with the function code
		return;
	}

	if(STD_SKI_SOFT_EXIT_BARRIER){
		barrier_wait(usermode_barrier);
	}


    if(STD_SKI_HYPERCALLS){
        hypercall(&hio_exit);
        shared_printf("[%d] Finished (hypercall enabled)\n", thread_num );
    }else{
        shared_printf("[%d] Finished (hypercall disabled)\n", thread_num );
    }

    if(with_barriers){
        barrier_wait(usermode_barrier);
    }
}


void ski_tests_init(int current_cpu, int total_cpus){
    shared_printf_init(current_cpu);

    if(with_barriers || STD_SKI_SOFT_EXIT_BARRIER){
        usermode_barrier = shared_malloc(sizeof(barrier_t), "SKI_barrier", current_cpu);
        if(current_cpu == 0){
			barrier_init(usermode_barrier, total_cpus);
		}
		printf("Sleeping for 5 seconds.\n");
		sleep(5);
    }
}


int ski_test_start(int current_cpu, int total_cpus, int dry_run){
	cpu_set_t  cpuset_process;
	int ret;

	if(dry_run){
		ret  = ski_thread_start(current_cpu, total_cpus, dry_run);
		return ret;
	}

/*    shared_printf_init(current_cpu);
*/

/*
    if(with_barriers){
        usermode_barrier = shared_malloc(sizeof(barrier_t), "SKI_barrier", current_cpu);
        if(current_cpu == 0){
			barrier_init(usermode_barrier, total_cpus);
		}
    }
*/
    if(with_mlock_prefault){
        if(mlockall(mlock_parametrs) == -1) {
            perror("SKI: mlockall failed");
            exit(-2);
        }
    }

/*	XXX: What was this for???
    if(signal(SIGINT, sig_handler)== SIG_ERR){
        perror("SKI: Signal SIGINT error");
        exit(1);
    }
    if(signal(SIGSEGV , sig_handler) == SIG_ERR){
        perror("SKI: Signal SIGINT error");
        exit(1);
    }
*/

	// Avoid having unflushed disk before the test begins...
	// XXX: but this could potentially interfere with tests
    fflush(0);
    sync();

	//shared_printf("We are process %d\n", current_cpu);

	CPU_ZERO(&cpuset_process);
	CPU_SET(current_cpu, &cpuset_process);
	ret = sched_setaffinity(0,sizeof(cpuset_process),&cpuset_process);
	if (ret) {
		shared_printf("SKI: Error: Failed to set up the affinity for thread 3!\n");
		perror("SKI: sched_setaffinity");
		exit(1);
	}

	ret = ski_thread_start(current_cpu, total_cpus, dry_run);
	return ret;

	// Test runs afterwards
}


void ski_test_finish(int current_cpu, int dry_run){
	
	if(dry_run){
		ski_thread_finish(current_cpu, dry_run);
		return;
	}

	// Test ran before
	ski_thread_finish(current_cpu, dry_run);

	// Printf: waiting on the barrier
	// Should have a barrier here for all the tests
	// Printf: finished the test

    if(with_barriers || STD_SKI_SOFT_EXIT_BARRIER){
        //barrier_destroy(usermode_barrier);
    }


}


