#include <pthread.h>
#include <stdlib.h>
#include <stdio.h>

#include "ski-barriers.h"

// From http://www.howforge.com/implementing-barrier-in-pthreads

extern int with_fork;

int barrier_init(barrier_t *barrier,int needed)
{
    barrier->needed = needed;
    barrier->called = 0;

	if(with_fork){
		pthread_condattr_t cattr;
		pthread_mutexattr_t mattr;

		pthread_mutexattr_init(&mattr);
		if(pthread_mutexattr_setpshared(&mattr, PTHREAD_PROCESS_SHARED)){
			perror("Mutex PTHREAD_PROCESS_SHARED");
			exit(1);
		}

	    pthread_condattr_init(&cattr);
		if(pthread_condattr_setpshared(&cattr, PTHREAD_PROCESS_SHARED)){
			perror("Cond PTHREAD_PROCESS_SHARED");
			exit(1);
		}

		pthread_mutex_init(&barrier->mutex,&mattr);
	    pthread_cond_init(&barrier->cond, &cattr);
	}else{
	    pthread_mutex_init(&barrier->mutex,NULL);
	    pthread_cond_init(&barrier->cond,NULL);
	}
    return 0;
}


int barrier_destroy(barrier_t *barrier)
{
    pthread_mutex_destroy(&barrier->mutex);
    pthread_cond_destroy(&barrier->cond);
    return 0;
}


int barrier_wait(barrier_t *barrier)
{
    pthread_mutex_lock(&barrier->mutex);
    barrier->called++;
    if (barrier->called == barrier->needed) {
        barrier->called = 0;
        pthread_cond_broadcast(&barrier->cond);
    } else {
        pthread_cond_wait(&barrier->cond,&barrier->mutex);
    }
    pthread_mutex_unlock(&barrier->mutex);
    return 0;
}

