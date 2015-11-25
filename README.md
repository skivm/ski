# SKI: Systematic Kernel Interleaving Explorer


SKI is an experimental virtual machine monitor, based on QEMU, that allows developers to test 
operating system kernels for concurrency bugs. 

SKI has several key features that makes it useful when compared with the _stress testing_ approach:
- SKI takes full control over the interleavings explored and uses heuristics to chose the interleavings to explore first
- SKI starts the execution of each test from the same initial state
- SKI executes tests (nearly-)deterministically
- SKI supports several types of bug detectors and is able to detect, for example, data races, panics, asserts, warnings.

The level of control provided by SKI and the heuristics implemented by SKI increase the probability and speed of exposing 
concurrency bugs. Additionally, the control achieved by SKI together with its tracing ability 
allows developers to easily compare different execution paths caused by different 
interleavings -- this can be particularly useful to diagnose the more complex concurrency bugs.

SKI implements several optimizations to make testing efficient, even though, as expected, the speed of execution of each interleavings is still lower than native bare-metal executions.

At this point SKI is a research prototype that lacks the maturity and documentation of other tools. This 
document provides only a very high-level idea of SKI so, for the time being, please consider the source 
code to be the main source of documentation ;). Some additional information can be obtained by reading 
the [original research paper](http://ski.mpi-sws.org/docs/osdi14.pdf) that proposed SKI:

	SKI: Exposing Kernel Concurrency Bugs through Systematic Schedule Exploration
	Pedro Fonseca, Rodrigo Rodrigues, and Björn Brandenburg.
	In the 11th USENIX Symposium on Operating Systems Design and Implementation (OSDI 2014)


At a high level, using SKI requires 1) *building SKI*, 2) *creating SKI tests*, and 3) *executing SKI 
tests*. The following sections describe in more detail each of these steps.



## 1. BUILDING SKI 

SKI was implemented on a fork of QEMU 1.0.1 and has the same building dependencies 
(see `vmm/README` for QEMU's original dependencies). However, SKI requires the following 
configured options passed to `./configure`: 
```bash
--disable-strip --target-list="i386-softmmu" --disable-pie --disable-smartcard
```

Assuming the dependencies are satisfied, the following commands should be sufficient to build SKI: 
```bash
  $ cd /home/ski-user/ski/vmm
  $ ./configure --prefix=/home/ski-user/ski/vmm-install --disable-strip --target-list="i386-softmmu" --disable-pie --disable-smartcard
  $ make V=1 or make -j 4
  $ make install
```


## 2. CREATING SKI TESTS 

A SKI test requires three components: 
 1. Target kernel
 2. Virtual Machine image
 3. User-mode test case

The following subsections explain the requirements regarding each of these components.

### Target kernel

The current implementation of SKI **requires i386 (32-bit) guests** (kernel and VM image). 

Although SKI's virtual machine monitor supports any type of kernel, the included auxiliary scripts 
presume the target kernel is Linux-based. This assumption is made both by the scripts that automatically 
build the kernel and by the scripts that externally load the kernel into the VM (by taking advantage 
of QEMU's loading mechanism). 

No additional requirements apply to the target kernel, however, it's convenient to 
build the target kernel with the following configuration:
 - Without the need for an initram. This eases the process of switching between tested kernels. 
 - With minimal compiler optimizations. This makes the analysis of the assembly traces easier.
 - With the tested functionalities (kernel modules) statically compiled. This allows instruction addresses to be more easily mapped to source code during manual inspection.

A Linux kernel suitable for SKI tests can be automatically built using the `./build-linux-kernel.sh` command:
```bash
  $ SKI_KERNEL_PACKAGE_URL=https://www.kernel.org/pub/linux/kernel/v4.x/linux-4.0.5.tar.gz SKI_KERNEL_PATCH_FILENAME=~/ski/config/linux.optimization.patch SKI_KERNEL_CONFIG_FILENAME=~/ski/config/linux.config SKI_KERNEL_TAGNAME=test1-4.0.5 ./build-linux-kernel.sh
```

### Virtual machine image

The virtual machine image should include all the tools necessary to run the test case. Ideally, for performance 
reasons unnecessary services should be disabled to speed up booting.
However, the virtual machine image does not need to include the target kernel if it 
is a Linux-based kernel (see previous subsection). 

Given the current scripts and samples of test cases the VM image should, a few other requirements apply:
 - Have the hypercall application installed in `/root/usermode/simple-app/debug`. The sample test cases rely on it to send diagnosis information.
 - At the very end of the booting process, the VM booting scripts should invoke `/root/usermode/simple-app/debug "Guest finished booting"`.  This allows `create-snapshot.sh` to know when to upload the test case. 
 - Have network access configured and root SSH access enabled with the keys in the SKI package. This allows `create-snapshot.sh` to automatically upload the test case. 
 *Security note: to prevent unauthorized access, please ensure that the VM is not externally acessible or alternative regenerate the keys*

### User-mode test case
The test case is responsible for steering the kernel execution during testing, typically by issuing 
concurrent system calls, and it can additionally provide diagnosis information. 

The test case is simply a directory in the host that is uploaded, through SSH, to the VM during testing. 
The test case directory must contain two executable scripts in the root: `ski-testcase-pack.sh` and `ski-testcase-run.sh`. 
Both scripts are executed by `create-snapshot.sh` during the tests, however `ski-testcase-pack.sh` is executed on 
the host -- possibly to cross compile the test or perform other tasks -- while `ski-testcase-run.sh` is executed 
inside the VM and is responsible for initialing the test. 

Apart from performing test-specific initialization 
procedures (e.g., formatting a file system, creating initial files), a test case
is expected to perform the following tasks:
 1. Fork two threads or processes 
 2. Each of the threads or processes issues an hypercall to signal to SKI the beginning of the concurrent phase (e.g., `ski_test_start()`)
 3. Each of the threads or processes drives the kernel by issuing system calls. (The value returned by `ski_test_start()` is usually leveraged to control the system calls selected and/or its parameters, in other words, the returned value is interpreted as a testing input specifier.) 
 4. Each of the threads or processes issues an hypercall to signal the end of the tests (`ski_test_finish()`)
 5. Optionally one or more of the threads performs diagnosis tasks or bug detection tasks, for example run fsck on the file system.

The test case can easily send diagnosis messages to the VMM through hypercalls (`hypercall_debug_quiet()`).



## 3. EXECUTING SKI TESTS


Test execution is divided into two phases. The first phase creates a snapshot of the VM immediately after both 
threads issue the hypercall that starts the test (`ski_test_start()`). Subsequently, the second phase is responsible for 
resuming from the stored snapshot and executing different interleavings until the end of the test (e.g., 
both threads call `ski_test_stop()`). 

The first phase can be considered an __important__ optimization that allows 
SKI to avoid booting the machine and initializing the test for every single interleaving 
explored. In addition, this phase also ensures that the execution of all  
interleavings start from the __exact same VM state__. 

With an appropriately constructed test case, it is expected that nearly all of the testing resources (CPU time) 
will be spent on the second phase. This is typically achieved by pushing all the test initialization 
steps to the first phase when writing test cases. 

Running SKI tests requires the following configuration steps to be performed:
 - `SKI_DIR` should point to the SKI root directory 
 - `SKI_TMP` should point to a temporary location with space for at least a few GB, preferably on a tmpfs mount for 
   faster access
 - The shared segment limits should be sufficiently high. For example:  
   `/sbin/sysctl kernel.shmmax=23355443200` and `/sbin/sysctl kernel.shmall=8097152`
 

### Phase 1: Creating a snapshot:

The script `./create-snapshot.sh` is used to create a test snapshot. Here is the basic format for this command:

```bash
   $ SKI_TRACE_INSTRUCTIONS_ENABLED=0 SKI_TRACE_MEMORY_ACCESSES_ENABLED=0 SKI_KERNEL_FILENAME=/dev/shm/ski-user/kernels/3.13.5_bzImage SKI_VM_FILENAME=/dev/shm/ski-user/kernels/debian6.img SKI_TESTCASE_DIR=~/ski/testcases/fsstress/ SKI_OUTPUT_DIR=/local/ski-user/ski/results/test1-snapshot ./create-snapshot.sh | tee -a test1-snapshot.log
```

This command should generate a VM image (.img) which contains a VM snapshot. The generated VM image is meant to be used during the second execution phase by `./run-ski.sh`.


### Phase 2: Exploring interleavings:

The script `./run-ski.sh` is used to run SKI tests from a snapshot. Here is the basic format for this command:

```bash
   $ SKI_INPUT1_RANGE=1-25 SKI_INPUT2_RANGE=+0-1 SKI_INTERLEAVING_RANGE=1-200 SKI_FORKALL_CONCURRENCY=1 SKI_RACE_DETECTOR_ENABLED=1 SKI_TRACE_INSTRUCTIONS_ENABLED=0 SKI_TRACE_MEMORY_ACCESSES_ENABLED=0 SKI_KERNEL_FILENAME=/dev/shm/ski-user/kernels/3.13.5_bzImage SKI_VM_FILENAME=/dev/shm/ski-user/snapshots/test1-snapshot/vm-image.img SKI_OUTPUT_DIR=/local/ski-user/ski/results/test1-a/ ./run-ski.sh
```

This command resumes from the snapshot contained in the VM image (`VM_FILENAME`) 
and spawns several VM executions with different intereavlings. Each VM execution 
runs till the end of the test. SKI supports multiple 
VM executions running in parallel, through the use of the `SKI_FORKALL_CONCURRENCY` variable.

`SKI_INPUT1_RANGE` and `SKI_INPUT2_RANGE` control the range of input values that are explored. Similarly, 
`SKI_INTERLEAVING_RANGE` controls the range of interleavings explored for each input. The total number of interleavings 
executed is equal to `size("input1 range") * size("input2 range") * size("interleavings range")`. 
For the three variables specifying ranges, the basic format is `<MIN_VALUE>-<MAX_VALUE>`.

Other notes regarding the execution of tests:
  - Both scripts (`./create-snapshot.sh` and `./run-ski.sh`) create a copy of the VM machine but 
note that the copy produced may not remain consistent because it is meant to be discarded
  - Both of scripts presume Linux is being tested and pass a parameter to the kernel during booting to 
    redirect the console to the serial output, which is stored by SKI in a file. This information can be 
	quite useful to diagnose booting problems and also diagnose and detect bugs (e.g. kernel panics reports 
	are usually written to the console).
  - Avoid storing multiple snapshots in the same VM-image as this negatively increases the VM image size 
    and may confuse `run-ski.sh`





