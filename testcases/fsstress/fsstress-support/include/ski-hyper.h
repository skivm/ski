#ifndef HYPER_H
#define HYPER_H

#include <stdarg.h>

#define HYPERCALL_INT                   4
#define HYPERCALL_EAX_MAGIC             0x01020304

#define HYPERCALL_IO_MAGIC_START        0x33556677
#define HYPERCALL_IO_MAGIC_END          0x12345678

#define HYPERCALL_IO_TYPE_TEST_ENTER    1
#define HYPERCALL_IO_TYPE_TEST_EXIT     2
#define HYPERCALL_IO_TYPE_DEBUG         3
#define HYPERCALL_IO_TYPE_TRACE_START   4
#define HYPERCALL_IO_TYPE_TRACE_STOP    5

// PF: 

typedef struct hypercall_io {
    int magic_start;
    int size;
    int hypercall_type;
    union {
        struct hio_test_enter {
            int gh_nr_instr;
            int gh_nr_cpus;
            int gh_disable_interrupts;
            int hg_res;
        } hio_test_enter;
        struct hio_test_exit {
            int hg_nr_syscalls_self;
            int hg_nr_interrupts_self;
            int hg_nr_syscalls_other;
            int hg_nr_interrupts_other;
            int hg_nr_instr_executed;
            int hg_nr_instr_executed_other;

            int hg_cpu_id;
            int hg_res;
        } hio_test_exit;
        struct hio_debug {
			char gh_msg[128];
        } hio_debug;
    } p;
    int magic_end;
} hypercall_io;

void hypercall_io_clear(hypercall_io *hio);
void hypercall_io_init(hypercall_io *hio);
inline static void hypercall(hypercall_io *hio) __attribute__((always_inline));

inline static void hypercall(hypercall_io *hio){
    __asm__ volatile (
             "int $0x4"
             :
             : "a" (HYPERCALL_EAX_MAGIC), "c" (hio)
    );
}

void hypercall_debug(int current_cpu, char *format,...);

void hypercall_export_dmesg(int current_cpu); 
void hypercall_export_time(int current_cpu);


#endif
