#include <stdio.h>
#include <stdlib.h>

#include <sys/mman.h>

extern int STD_SKI_ENABLED, STD_SKI_WAIT_FOR_RESULTS, STD_SKI_CPU_AFFINITY, STD_SKI_HYPERCALLS, STD_SKI_SOFT_EXIT_BARRIER, STD_SKI_USER_BARRIER, STD_SKI_TOTAL_CPUS, STD_SKI_TEST_NUMBER, STD_SKI_PROFILE_ENABLED;
extern int SKI_TEST_COUNTER;
int ski_test_start(int current_cpu, int total_cpus, int dry_run);
void ski_test_finish(int current_cpu, int dry_run);
void hypercall_debug(int current_cpu, char *format, ...);
void hypercall_debug_quiet(int current_cpu, char *format, ...);


int main(){
	
	printf("Empty for fsstress\n");

	ski_parse_env();

	// To avoid page fault
	//hypercall_debug(STD_SKI_CPU_AFFINITY, (char*)"About to start test [TEST] - CPU: %d Op: %s Op_seed: %d Op_no: %d Op_max: %d Test_seed: %d ",
 	//			STD_SKI_CPU_AFFINITY, "empty", -1, -1, 0, test_seed);

	int mlock_parametrs = MCL_CURRENT; //| MCL_FUTURE;
	if(mlockall(mlock_parametrs) == -1) {
		perror("mlockall failed");
		exit(-2);
	}

	hypercall_debug_quiet(STD_SKI_CPU_AFFINITY, (char*)"First call");


    ski_test_start(STD_SKI_CPU_AFFINITY, STD_SKI_TOTAL_CPUS, 1);


    // Actual run
    int ret = ski_test_start(STD_SKI_CPU_AFFINITY, STD_SKI_TOTAL_CPUS, 0);
    int test_seed = ret + STD_SKI_CPU_AFFINITY;

	hypercall_debug_quiet(STD_SKI_CPU_AFFINITY, (char*)"Start test [TEST] - CPU: %d Op: %s Op_seed: %d Op_no: %d Op_max: %d Test_seed: %d ",
			STD_SKI_CPU_AFFINITY, "empty", -1, -1, 0, test_seed);


    ski_test_finish(STD_SKI_CPU_AFFINITY,0);
	if (STD_SKI_CPU_AFFINITY==0){
		hypercall_debug_quiet(STD_SKI_CPU_AFFINITY, (char*)"END INFO");
	}

	return 0;
}

