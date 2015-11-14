#ifndef SKI_HYPER_BTRFS_H
#define SKI_HYPER_BTRFS_H


extern int STD_SKI_CPU_AFFINITY;

void hypercall_debug_quiet(int current_cpu, char *format, ...);

#define printf(...)\
    hypercall_debug_quiet(STD_SKI_CPU_AFFINITY,  __VA_ARGS__)

#define fprintf(fd,...)\
    hypercall_debug_quiet(STD_SKI_CPU_AFFINITY,  __VA_ARGS__)


#endif
