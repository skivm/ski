#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

int STD_SKI_ENABLED = 0;   // Default disabled
int STD_SKI_FORK_ENABLED = -1;
int STD_SKI_CPU_AFFINITY = -1;
int STD_SKI_HYPERCALLS = -1;
int STD_SKI_SOFT_EXIT_BARRIER = -1;
int STD_SKI_USER_BARRIER = -1;
int STD_SKI_TOTAL_CPUS = -1;
int STD_SKI_TEST_NUMBER = -1;
int STD_SKI_PROFILE_ENABLED = 0;  //Default disabled
int STD_SKI_WAIT_FOR_RESULTS = 1;

int SKI_TEST_COUNTER = 0;

int ski_parse_debug = 1; 


int ski_tests_init(int current_cpu, int total_cpus);


// default_value == -1 means that there is no default_value (and it's an invalid value for the variable)
void ski_parse_int_env_variable(const char *variable_name, int* variable, int defaul_value){
	int i;
	int using_default = 1;
	char *ptr;

	*variable = defaul_value;

    if ((ptr = getenv(variable_name)) != NULL) {
        if (sscanf(ptr, "%d", &i) == 1 && i >= 0){
            *variable = i;
			using_default = 0;
        }else{
            printf("Error: Unable to parse the value of the variable. Exiting");
			exit(-1);
		}
	}
	

	if(ski_parse_debug){
		printf("Spark: env variable %s = %d (using default %d)\n", variable_name, *variable, using_default );
	}
	assert(*variable != -1 );
}


char* ski_parse_env(){
	ski_parse_int_env_variable("USC_SKI_ENABLED", &STD_SKI_ENABLED, 1);
	ski_parse_int_env_variable("USC_SKI_FORK_ENABLED", &STD_SKI_FORK_ENABLED, -1);
	ski_parse_int_env_variable("USC_SKI_CPU_AFFINITY", &STD_SKI_CPU_AFFINITY, -1);
	ski_parse_int_env_variable("USC_SKI_TOTAL_CPUS", &STD_SKI_TOTAL_CPUS, -1);
	ski_parse_int_env_variable("USC_SKI_HYPERCALLS", &STD_SKI_HYPERCALLS, -1);
	ski_parse_int_env_variable("USC_SKI_SOFT_EXIT_BARRIER", &STD_SKI_SOFT_EXIT_BARRIER, -1);
	ski_parse_int_env_variable("USC_SKI_USER_BARRIER", &STD_SKI_USER_BARRIER, -1);
	ski_parse_int_env_variable("USC_SKI_TEST_NUMBER", &STD_SKI_TEST_NUMBER, -1);
	ski_parse_int_env_variable("USC_SKI_PROFILE_ENABLED", &STD_SKI_PROFILE_ENABLED, 0);
	ski_parse_int_env_variable("USC_SKI_WAIT_FOR_RESULTS", &STD_SKI_WAIT_FOR_RESULTS, 1);


    if(STD_SKI_ENABLED && !((STD_SKI_CPU_AFFINITY>=0) && (STD_SKI_TOTAL_CPUS>=1) && (STD_SKI_TEST_NUMBER>=0) && (STD_SKI_HYPERCALLS>=0))){
        printf("STD_SKI_CPU_AFFINITY=%d STD_SKI_TOTAL_CPUS=%d STD_SKI_TEST_NUMBER=%d STD_SKI_HYPERCALLS=%d\n",
               STD_SKI_CPU_AFFINITY, STD_SKI_TOTAL_CPUS, STD_SKI_TEST_NUMBER, STD_SKI_HYPERCALLS);
        return "SKI ERROR: ((STD_SKI_CPU_AFFINITY>=0) && (STD_SKI_TOTAL_CPUS>=1) && (STD_SKI_TEST_NUMBER>=0) && (STD_SKI_HYPERCALLS>=0))";
    }

	ski_tests_init(STD_SKI_CPU_AFFINITY, STD_SKI_TOTAL_CPUS);
	return "";
}

