#include <strings.h>
#include <string.h>
#include <stdio.h>
#include <time.h>
#include "ski-hyper.h"
#include <assert.h>
#include <stdarg.h>

//extern int with_hypercall;
extern int STD_SKI_HYPERCALLS;

void shared_printf(char *format,...);

void hypercall_io_clear(hypercall_io *hio){
    bzero(hio,sizeof(hypercall_io));
}

void hypercall_io_init(hypercall_io *hio){
    hypercall_io_clear(hio);
    hio->size = sizeof(hypercall_io);
    hio->magic_start = HYPERCALL_IO_MAGIC_START;
    hio->magic_end = HYPERCALL_IO_MAGIC_END;
}


// Calling hypercall_debug_quiet() 
void hypercall_debug_quiet(int current_cpu, char *format, ...)
{
	hypercall_io hio;
	int len;
	int max = sizeof(hio.p.hio_debug.gh_msg) - 1;

	va_list list;
    va_start(list,format);

	hypercall_io_init(&hio);

	vsnprintf(hio.p.hio_debug.gh_msg, max, format, list);
	hio.hypercall_type = HYPERCALL_IO_TYPE_DEBUG;
	len = strlen(hio.p.hio_debug.gh_msg);

	// Remove newline if exists at the end of the string
	if((len>0) && (hio.p.hio_debug.gh_msg[len-1]=='\n'))
		hio.p.hio_debug.gh_msg[len-1] = 0;
	len = strlen(hio.p.hio_debug.gh_msg);
	if(len>max-3){
		strcpy(hio.p.hio_debug.gh_msg + max - 3, "...");
	}
	if(STD_SKI_HYPERCALLS){
		hypercall(&hio);
		hypercall_io_clear(&hio);
	}else{
		printf("[%d] Would have issued msg: %s (hypercall disabled)\n", current_cpu, hio.p.hio_debug.gh_msg);
	}
	va_end(list);
}


void hypercall_debug(int current_cpu, char *format, ...)
{
	hypercall_io hio;
	int len;
	int max = sizeof(hio.p.hio_debug.gh_msg) - 1;

	shared_printf_init(current_cpu);

	va_list list;
    va_start(list,format);

	hypercall_io_init(&hio);

	vsnprintf(hio.p.hio_debug.gh_msg, max, format, list);
	hio.hypercall_type = HYPERCALL_IO_TYPE_DEBUG;
	//strncpy(hio.p.hio_debug.gh_msg,msg,max);
	len = strlen(hio.p.hio_debug.gh_msg);

	// Remove newline if exists at the end of the string
	if((len>0) && (hio.p.hio_debug.gh_msg[len-1]=='\n'))
		hio.p.hio_debug.gh_msg[len-1] = 0;
	len = strlen(hio.p.hio_debug.gh_msg);
	if(len>max-3){
		strcpy(hio.p.hio_debug.gh_msg + max - 3, "...");
	}
	if(STD_SKI_HYPERCALLS){
		shared_printf("[%d] Issuing debug message: %s\n", current_cpu, hio.p.hio_debug.gh_msg);
		hypercall(&hio);
		hypercall_io_clear(&hio);
	}else{
		shared_printf("[%d] Would have issued msg: %s (hypercall disabled)\n", current_cpu, hio.p.hio_debug.gh_msg);
	}
	va_end(list);
}

void hypercall_export_dmesg(int current_cpu){
	char str[128];
	char str2[200];

	FILE *fd_mesg;

	fd_mesg = fopen("/var/log/dmesg","r");
	while(fgets(str,128,fd_mesg)){
		sprintf(str2,"/var/log/dmesg: %s", str);
		hypercall_debug(current_cpu, str2);
	}
	fclose(fd_mesg);
}

void hypercall_export_dmesg_fast(int current_cpu, char* buffer, int buffer_size){
	FILE *fd_mesg;
	int i;
	int start_str = 0;

	assert(buffer_size > 16*1024);

	fd_mesg = fopen("/var/log/dmesg","r");
	assert(fd_mesg);

	int res = fread(buffer, 1, buffer_size-1, fd_mesg);
	buffer[res+1] = 0;

	for(i=0;i<=res + 1;i++){
//		printf("i=%d res=%d buffer[i]=%c\n",i,res,buffer[i]);
		if(buffer[i]=='\n' || buffer[i] == '\0'){
			buffer[i] = 0;
//			printf("%s\n",buffer+start_str);
			hypercall_debug(current_cpu, buffer + start_str);
			start_str = i + 1;
		}
		if(start_str>=res){
			break;
		}
	}

/*	while(fgets(str,128,fd_mesg)){
		sprintf(str2,"/var/log/dmesg: %s", str);
		hypercall_debug(str2);
	}
*/
	fclose(fd_mesg);
}


void hypercall_export_time(int current_cpu){
	time_t sec;
	char str[128];

	sec = time(NULL);

	sprintf(str, "Seconds since January 1, 1970: %ld", sec);
	hypercall_debug(current_cpu, str);

	sprintf(str, ctime(&sec));
	hypercall_debug(current_cpu, str);
}

/*
inline void hypercall(hypercall_io *hio){
    __asm__ volatile (
             "int $0x4"
             :
             : "a" (HYPERCALL_EAX_MAGIC), "c" (hio)
    );
}
*/

