**************
** OVERVIEW **
**************

SKI is an experimental virtual machine monitor, modified from QEMU, that allows developers to test 
operating system kernels for concurrency bugs. 

SKI has several key features that make it useful when compared with "stress testing":
- SKI takes full control over the interleavings explored and uses heuristics to chose the interleavings explored first 
- SKI starts the execution of each test from the same initial state
- (Near-)deterministic execution 
- Convenient support for different types of bug detectors (data races, panics, asserts, warnings, ...)

The level of control provided by SKI and its heuristics increase can increase the probability and speed of exposing 
concurrency bugs. Additionally, SKI's control combined with its tracing capability allows developers to
compare different execution paths caused by different interleavings to diagnose more complex concurrency bugs. 

SKI implements several optimizations to make testing efficient, even though, as expected, the testing speed is still 
lower than native bare-metal executions.

At this point SKI is a research prototype that lacks the maturity and documentation of other tools. This 
document provides only a very high-level idea of SKI -- so, for the time being, please consider the source 
code to be the main source of documentation ;). Some additional information can be obtained by reading 
the original research paper that proposed SKI (ski.mpi-sws.org/docs/osdi14.pdf):

	"SKI: Exposing Kernel Concurrency Bugs through Systematic Schedule Exploration"
	Pedro Fonseca, Rodrigo Rodrigues, and Björn Brandenburg.
	In the 11th USENIX Symposium on Operating Systems Design and Implementation (OSDI 2014)


At a high level, using SKI requires three steps that the following sections describe in more detail:
 1. Building SKI
 2. Creating SKI tests
 3. Executing SKI tests



*********************
** 1. BUILDING SKI **
*********************

SKI is based on QEMU 1.0.1 and both have the same building dependencies (see vmm/README for QEMU's original 
dependencies). However, SKI should be configured with the following options: 
   "--disable-strip --target-list="i386-softmmu" --disable-pie --disable-smartcard"  

The following commands should build SKI: 
  $ cd /NS/home-0/ski-user/ski/vmm
  $ ./configure --prefix=/NS/home-0/ski-user/ski/vmm-install --disable-strip --target-list="i386-softmmu" --disable-pie --disable-smartcard
  $ make V=1 or make -j 4
  $ make install



***************************
** 2. CREATING SKI TESTS **
***************************

A SKI test requires three components: 
  - Tested kernel
  - Virtual Machine image
  - User-mode test case

Currently, the implementation of SKI only supports i386 (32-bit) guests. Also note that, although the VMM of SKI 
supports any type of kernel, the included auxiliary scripts presume the tested kernel is Linux-based for the purpose 
of automatically building the kernel and for the purpose of easily loading the kernel into the VM (by taking advantage 
of QEMU's external mechanism). No other requirements apply to the tested kernel, nevertheless, it's practical to 
build the kernel with the following configuration:
   - Without the need for an initram. This eases the process of switching between tested kernels. 
   - With minimal compiler optimizations. This facilitates the interpretation of the assembly traces.
   - With the tested functionalities statically compiled. This allows instructions addresses to be more easily mapped to the source code.

A Linux kernel can be automatically built using the following command from this package:
  $ SKI_KERNEL_PACKAGE_URL=https://www.kernel.org/pub/linux/kernel/v4.x/linux-4.0.5.tar.gz SKI_KERNEL_PATCH_FILENAME=~/ski/config/linux.optimization.patch SKI_KERNEL_CONFIG_FILENAME=~/ski/config/linux.config SKI_KERNEL_TAGNAME=test1-4.0.5 ./build-linux-kernel.sh

The virtual machine only needs to include the tested kernel if it's not a Linux kernel loaded externally. The 
virtual machine image should include all the tools necessary to run the test case. Ideally, for performance 
reasons unnecessary services should be disabled to speed up booting -- because, given the current scripts, 
diagnosing problems during the development of the test cases may require several booting operations. Furthermore 
given the current scripts and samples of test cases the VM image should:
   - Have the hypercall application installed in "/root/usermode/simple-app/debug". The sample test cases rely 
     on it to send diagnosis information.
   - Report using hypercalls when the machine finishes booting. This allows "create-snapshot.sh" to know when 
     to upload the test case. 
   - Have network access configured and root SSH access enabled with the keys in the SKI package. This is allows 
     "create-snapshot.sh" to automatically upload the test case.

The test case is simply a directory in the host that is uploaded to the VM during testing and is responsible for steering the 
kernel execution during testing, e.g., issuing concurrent system calls. It can also provide diagnosis information. 

The test case directory must contain two executable scripts in the root: "ski-testcase-pack.sh" and "ski-testcase-run.sh". 
Both scripts are executed by "create-snapshot.sh" during the tests, however "ski-testcase-pack.sh" is executed on 
the host -- possibly to cross compile the test or perform other tasks -- while "ski-testcase-run.sh" is executed 
inside the VM and is responsible for initialing the test. Apart from performing any test-specific initialization 
procedures (e.g., formatting a file system), the test cases are expected to perform the following tasks:
   1 - Fork two threads or processes 
   2 - Each of the threads or processes issues an hypercall to signal to SKI the beginning of the concurrent 
       phase (e.g., "ski_test_start()")
   3 - Each of the threads or processes drives the kernel by issuing system calls. (The value returned by 
       ski_test_start() is usually leveraged to control the system calls selected and/or its parameters, i.e., 
	   the returned value is interpreted as an testing input specifier.) 
   4 - Each of the threads or processes issues an hypercall to signal the end of the tests ("ski_test_finish()")
   5 - Optionally one or more of the threads performs diagnosis tasks or bug detection tasks (e.g., running  fsck)

The test case can conveniently (and efficiently) send out diagnosis ASCII strings of text to the VMM through hypercalls.




****************************
** 3. EXECUTING SKI TESTS **
****************************


Test execution is divided into two phases. The first phase creates a snapshot of the VM immediately after both 
threads issue hypercall that start the test ("ski_test_start()"). While the second phase is responsible for 
resuming from the stored snapshot and executing many different interleavings until the end of the tests (e.g., 
both threads call "ski_test_stop()"). The first phase can be considered an (important) optimization that allows 
SKI to avoid having to boot and initialize the tests (e.g., initialize the file system) for each interleaving 
explored. However, this mechanism also has the advantage of enabling SKI to start the execution of all the 
interleavings from the exact same VM state. 

With an appropriately constructed test case, it is expected that nearly all of the testing resources (CPU time) 
will be spent on the second phase, which explains why several optimizations have been implemented for this case. 

Running the tests requires the following configuration steps to be performed:
   - SKI_DIR should point to the SKI root directory 
   - SKI_TMP should point to a temporary location with space for at least a few GB (preferably on a tmpfs for 
     faster accesses)
   - Ensure that the shared segment limits are sufficiently high 
     /sbin/sysctl kernel.shmmax=23355443200 && /sbin/sysctl kernel.shmall=8097152
 

** Phase 1: Creating a snapshot:
   $ SKI_TRACE_INSTRUCTIONS_ENABLED=0 SKI_TRACE_MEMORY_ACCESSES_ENABLED=0 SKI_KERNEL_FILENAME=/dev/shm/ski-user/kernels/3.13.5_bzImage SKI_VM_FILENAME=/dev/shm/ski-user/kernels/debian6.img SKI_TESTCASE_DIR=~/ski/testcases/fsstress/ SKI_OUTPUT_DIR=/local/ski-user/ski/results/test1-snapshot ./create-snapshot.sh | tee -a test1-snapshot.log

This step should generate a VM image, which contains a snapshot, that is meant to be used by the second phase.


** Phase 2: Exploring interleavings:
   $ SKI_INPUT1_RANGE=1-25 SKI_INPUT2_RANGE=+0-1 SKI_INTERLEAVING_RANGE=1-200 SKI_FORKALL_CONCURRENCY=1 SKI_RACE_DETECTOR_ENABLED=1 SKI_TRACE_INSTRUCTIONS_ENABLED=0 SKI_TRACE_MEMORY_ACCESSES_ENABLED=0 SKI_KERNEL_FILENAME=/dev/shm/ski-user/kernels/3.13.5_bzImage SKI_VM_FILENAME=/dev/shm/ski-user/snapshots/test1-snapshot/vm-image.img SKI_OUTPUT_DIR=/local/ski-user/ski/results/test1-a/ ./run-ski.sh


Other notes regarding the execution of tests:
  - Both scripts create a copy of the VM machine (and the copy produced may not remain consistent as it's 
    meant to be discarded in this version of SKI)
  - SKI_INPUT1_RANGE and SKI_INPUT2_RANGE control the range of inputs values provided; the same applies 
    for SKI_INTERLEAVING_RANGE regarding the interleavings explored. The total number of interleavings 
	executed is equal to: size("input1 range") * size("input2 range") * size("interleavings range")
  - For reasons of flexibility some ranges can be specified in complex ways but the basic form is "MIN_VALUE-MAX_VALUE"
  - Both of these scripts presume Linux is being tested and pass a parameter to the kernel during booting to 
    redirect the console to the serial output, which is stored by SKI in a file. This information can be 
	quite useful to diagnose booting problems and also diagnose and detect bugs (e.g. kernel panics reports 
	are usually written to the console).
  - Avoid storing multiple snapshots in the same VM-image as this negatively increases the VM image size 
    and may confuse run-ski.sh





