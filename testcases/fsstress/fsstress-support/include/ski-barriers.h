#ifndef BARRIERS_H
#define BARRIERS_H

typedef struct {
    volatile int needed;
    volatile int called;
    pthread_mutex_t mutex;
    pthread_cond_t cond;
} barrier_t;


int barrier_init(barrier_t *barrier,int needed);
int barrier_destroy(barrier_t *barrier);
int barrier_wait(barrier_t *barrier);

#endif

