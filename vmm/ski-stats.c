/*
 * SKI - Systematic Kernel Interleaving explorer (http://ski.mpi-sws.org)
 *
 * Copyright (c) 2013-2015 Pedro Fonseca
 *
 *
 * This work is licensed under the terms of the GNU GPL, version 3.  See
 * the GPL3 file in SKI's top-level directory.
 *
 */




#include "ski-stats.h"
#include "ski-ipfilter.h"
#include "ski-race-detector.h"
#include "ski-memory-detector.h"
#include "ski-selective-trace.h"
#include <pthread.h>

// Private private stats
ski_stats* ski_stats_all;
ski_stats* ski_stats_self = 0;
static int ski_stats_all_max_slots = 0;

//int ski_eipfilter_add_entry(unsigned int eip);

extern int ski_init_options_input_number[SKI_CPUS_MAX];

#define SKI_STATS_MAGIC_BEGIN 0x12345678
#define SKI_STATS_MAGIC_END 0x12345678

// Based on http://www.makelinux.net/alp/035
void* ski_stats_allocate_shared(size_t size){
	char *shared_memory;
	long long segment_size;

	printf("[SKI] [STATS] Trying to allocate with size: %lld\n", size);
	/* Allocate a shared memory segment.  */ 
	int segment_id = shmget(IPC_PRIVATE, size, IPC_CREAT | IPC_EXCL | S_IRUSR | S_IWUSR);
	if(segment_id == -1){

		perror("[SKI] [STATS] Segment id error (maybe need to \"/sbin/sysctl kernel.shmmax=23355443200\" && \"/sbin/sysctl kernel.shmall=8097152\"");
	}
 	assert(segment_id != -1);


	/* Attach the shared memory segment.  */ 
	shared_memory = (char*) shmat (segment_id, 0, 0); 
	printf("[SKI] [STATS] Shared memory attached at address %p\n", shared_memory); 

	assert(shared_memory != -1);

	struct shmid_ds shmbuffer; 	
	/* Determine the segment's size. */ 
	shmctl(segment_id, IPC_STAT, &shmbuffer); 
	segment_size = shmbuffer.shm_segsz; 
	printf("[SKI] [STATS] Segment size: %lld\n", segment_size); 

	printf("[SKI] [STATS] Trying to set auto delete flag\n");
	int res = shmctl(segment_id, IPC_RMID, 0);
	assert(res == 0);

	return shared_memory;
}

void ski_stats_init_slot(int slot){
	ski_stats * s = &ski_stats_all[slot];
	memset(s, 0, sizeof(ski_stats));

	ski_race_detector_init(&s->rd);

	ski_instruction_detector_load(&s->id);
#ifdef SKI_SELECTIVE_TRACE_ENABLED
	ski_selective_trace_load(&s->st);
#endif

#ifdef SKI_MEMORY_DETECTOR_ENABLED
	ski_memory_detector_init(&s->md);
#endif

	s->magic_begin = SKI_STATS_MAGIC_BEGIN;
	s->magic_end = SKI_STATS_MAGIC_END;
	s->slot = slot;
}

void ski_stats_init_all(int n_slots){
	int i;

	printf("[SKI] [STATS] ski_stats_init: setting up %d slots\n", n_slots);
	ski_stats_all = (ski_stats*) ski_stats_allocate_shared(sizeof(ski_stats)*n_slots);
	assert(ski_stats_all);
	ski_stats_all_max_slots = n_slots;
	for(i=0;i<n_slots;i++){
		ski_stats_init_slot(i);
	}
}

void ski_stats_reset_slot(int slot){
	ski_stats * s = &ski_stats_all[slot];

    s->pid = 0;
    s->seed = 0;

	s->input_number[0] = 0;
	s->input_number[1] = 0;

	s->instructions_n = 0;
	s->instructions_hash = 0;
	s->data_n = 0;
	s->data_hash = 0;
	s->data_instructions_n = 0;

    s->trace_filename[0] = 0;
    s->trace_filename_full[0] = 0;
    s->preemption_points_executed = 0;
    s->preemption_list_size = 0;

    s->preemptions_len = 0;

	s->communication_eips = 0;
	s->communication_data = 0;

	s->instructions_executed = 0;

	s->exit_code = 0;
	s->exit_location[0] = 0;
    s->exit_reason[0] = 0;

	s->communication_instructions_n = 0;
	s->communication_instructions_hash = 0;

	ski_race_detector_init(&s->rd);

	ski_instruction_detector_reset_count(&s->id);

#ifdef SKI_MEMORY_DETECTOR_ENABLED
	ski_memory_detector_reset(&s->md);
#endif

	s->magic_begin = SKI_STATS_MAGIC_BEGIN;
	s->magic_end = SKI_STATS_MAGIC_END;
	s->slot = slot;
}

void ski_stats_set_self_slot(int slot){
	assert(slot < ski_stats_all_max_slots);
	ski_stats_self = &ski_stats_all[slot];
	assert(ski_stats_self->slot == slot);	
}

ski_stats *ski_stats_get_self(){
	assert(ski_stats_self);
	return ski_stats_self;
}

ski_stats *ski_stats_get_from_pid(int pid){
	int i;

	for(i=0;i<ski_stats_all_max_slots;i++){
		ski_stats * s = &ski_stats_all[i];
		if(s->pid == pid){
			return s;
		}
	}
	assert(0);
	return 0;
}

void ski_stats_start(void){
	assert(ski_stats_self);
	gettimeofday(&ski_stats_self->start, 0);
	
	ski_stats_self->input_number[0] = ski_init_options_input_number[0];
	ski_stats_self->input_number[1] = ski_init_options_input_number[1];
}

void ski_stats_finish(){
	assert(ski_stats_self);

	//ski_stats_self->previous_preemption_points = previous_preemption_points;
	//printf("[SKI] [STATS] previous_preemption_points = %d\n", previous_preemption_points);
	gettimeofday(&ski_stats_self->finish, 0);
}

/*
void ski_stats_add_round(int round){

	ski_stats_self->round = round;
}
*/

void ski_stats_add_seed(int seed){
	ski_stats_self->seed = seed;
}

void ski_stats_add_preemption_list_size(int size){
	//printf("ski_stats_add_preemption_list_size: adding to seed %d preemption with size %d\n", ski_stats_self->seed, size);
	ski_stats_self->preemption_list_size = size;
}


void ski_stats_add_trace(char* trace_filename, char *trace_filename_full){
	strcpy(ski_stats_self->trace_filename, trace_filename);
	strcpy(ski_stats_self->trace_filename_full, trace_filename_full);
}


/* Moved in from vl.c to make it inline */
extern ski_ipfilter_hash_entry * ski_ipfilter_hash;


inline static int ski_stats_add_communication_instruction(unsigned int eip){
	ski_stats *stats = ski_stats_self;
    ski_stats_instruction* entry = 0;

    HASH_FIND_INT(stats->communication_instructions_hash, &eip, entry);

    if(entry == 0){
        assert(stats->communication_instructions_n<MAX_IPFILTER_HASH);
        entry = &stats->communication_instructions[stats->communication_instructions_n];
        stats->communication_instructions_n++;

        entry->eip_address = eip;
        HASH_ADD_INT(stats->communication_instructions_hash, eip_address, entry);
        return 1;
    }
    return 0;
}


int ski_stats_input_is_running(ski_stats *stats){
	if((stats->input_number[0] == ski_init_options_input_number[0]) &&
		(stats->input_number[1] == ski_init_options_input_number[1])){
		return 1;
	}
	return 0;
}


extern int ski_sched_instructions_total;
extern int ski_exec_instruction_counter_total;
extern int ski_init_options_preemptions[SKI_MAX_PREEMPTION_POINTS];
extern int ski_init_options_preemptions_len;

void ski_stats_input_set_preemptions(){
	int i;
	ski_stats *stats = ski_stats_self;

	stats->preemptions_len = ski_init_options_preemptions_len;; 
	assert(stats->preemptions_len < SKI_MAX_PREEMPTION_POINTS);
	for(i=0;i<stats->preemptions_len ;i++){
	    stats->preemptions[i] = ski_init_options_preemptions[i];
	}
}


static void ski_stats_once_only(){
	static pthread_mutex_t invocation_counter_mutex = PTHREAD_MUTEX_INITIALIZER;
	static int invocation_counter = 0;

	pthread_mutex_lock(&invocation_counter_mutex);
	if(invocation_counter == 1){
		pthread_mutex_unlock(&invocation_counter_mutex);
		// Hang the subsequent thread invocations
		while(1){
			sleep(1);
		}
	}
	invocation_counter++;
	pthread_mutex_unlock(&invocation_counter_mutex);
}

// Called automatically from SKI_ASSERT_MSG
void ski_stats_compute_communication_instructions(){
	ski_stats *stats = ski_stats_self;
	int i;
	int added_eips = 0;
	int communication_eips = 0;
	int communication_data = 0;

	ski_stats_once_only();
	// Only the first thread passes here

	if(ski_stats_input_is_running(stats)){
		// If our input is still being explored, then compute the communcation points for subsequent executions

		//printf("[SKI] Communication points:\n");
		for(i=0; i < stats->data_n; i++){
			int cpu_no;
			ski_stats_data_accesses *da = &stats->data[i];
			int write_exists = 0;
			int n_cpus_accessing = 0;

			// TODO: We're ignoring the length for now...

			for(cpu_no=0; cpu_no<SKI_STATS_MAX_CPU; cpu_no++){
				/*
				if(da->w_cpu[cpu_no] > 0){
					write_exists = 1;
				}
				if((da->w_cpu[cpu_no] > 0) || (da->r_cpu[cpu_no] > 0)){
					n_cpus_accessing++;
				}
				*/
				if(SKI_STATS_GET_W_CPU(da, cpu_no) != 0){
					write_exists = 1;
				}
				if((SKI_STATS_GET_W_CPU(da, cpu_no) != 0) || (SKI_STATS_GET_R_CPU(da, cpu_no) != 0)){
					n_cpus_accessing++;
				}

			}

			if(write_exists && (n_cpus_accessing>1)){
				// This data_address is a communication point.
				// => Add all data_instructions to the list of pontential communication points
				ski_stats_instruction *di = da->data_instructions_hash;
				//printf("Communication point: %08x n_cpus_accessing: %d da->rw_cpu_size_flag: %08x ", da->data_address, n_cpus_accessing, da->rw_cpu_size_flag);
				while(di){
					//printf("0x%08x ", di->eip_address);

					int was_added;
					was_added = ski_stats_add_communication_instruction(di->eip_address);
					if(was_added){
						added_eips++;
					}
					communication_eips++;
					di = di->hh.next;
				}
				//printf("\n");
				communication_data++;
			}
	}
	}else{
		printf("ski_stats_compute_communication: not adding the communication points because inputs don't match (seed %d) [%d %d %d %d] \n", 
			stats->seed, stats->input_number[0], ski_init_options_input_number[0], stats->input_number[1], ski_init_options_input_number[1]);
	}

	stats->communication_eips = communication_eips;
	stats->communication_data = communication_data;


	stats->preemption_points_executed = ski_sched_instructions_total;
	stats->instructions_executed = ski_exec_instruction_counter_total; // XXX: ski_exec_instruction_counter_total should probably be made long long  

	printf("[SKI] [STATS] Added %d new communication eip points (found a total of %d data and %d eips)\n", added_eips, communication_data, communication_eips);
	return;
}


void ski_stats_dump_all(void){
	int i;

	printf("[SKI] [STATS] Start time: %ld.%ld Finish time: %ld.%.ld\n", ski_stats_self->start.tv_sec, ski_stats_self->start.tv_usec, ski_stats_self->finish.tv_sec, ski_stats_self->finish.tv_usec);
	printf("[SKI] [STATS] Total distinct data addresses: %lld\n", ski_stats_self->data_n);
	for(i=0; i < ski_stats_self->data_n; i++){
		int j;
		ski_stats_data_accesses *da = &ski_stats_self->data[i];
		
		printf("[SKI] [STATS] %d Address 0x%08x  Rw_cpu_size_flag: %08x Total accesses: %lld IPs: ", i, da->data_address, da->rw_cpu_size_flag, da->total_accesses);
		/*
		printf("%d Address 0x%08x  Sizes = [ ", i, da->data_address);
		
		for(j=0;j<SKI_STATS_MAX_ACCESS_SIZE;j++){
			printf("%2lld ", da->size_bytes[j]);
		}
		printf("]  R = [ ");
		for(j=0;j<SKI_STATS_MAX_CPU;j++){
			printf("%2lld ", da->r_cpu[j]);
		}
		printf("]  W = [ ");
		for(j=0;j<SKI_STATS_MAX_CPU;j++){
			printf("%2lld ", da->w_cpu[j]);
		}
		printf("] ");
		*/

		ski_stats_instruction *di = da->data_instructions_hash;

		while(di){
			printf("0x%08x ", di->eip_address);
			di = di->hh.next;
		}
		printf("\n");
	}
}




void ski_stats_dump_all_slots(){
	int slot;

	for(slot=0;slot<ski_stats_all_max_slots;slot++){
		ski_stats_dump_slot(slot);
	}
}

void ski_stats_dump_slot(int slot){
	ski_stats * stats = &ski_stats_all[slot];

    char *trace_filename = stats->trace_filename[0] ? stats->trace_filename : "???";
    char *exit_reason = stats->exit_reason[0] ? stats->exit_reason : "???";
    char exit_location[128];
    char *exit_location_basename;

    sprintf(exit_location, "%s", stats->exit_location);
    exit_location_basename = basename(exit_location);

    printf( "T: %s Seed: %d Input1: %d Input2: %d Slot: %d Pid: %d P_list: %d P_exec: %d C_data: %d C_eips: %d TI: %lld #I: %lld #D: %lld Res: %s Exit_loc: %s END\n",
        trace_filename,
        stats->seed, stats->input_number[0], stats->input_number[1], stats->slot, stats->pid, stats->preemption_list_size, stats->preemption_points_executed, stats->communication_data, stats->communication_eips,
		stats->instructions_executed,
        stats->instructions_n, stats->data_n,
        exit_reason, exit_location_basename);
}


