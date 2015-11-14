DEBUG_BUILD="V=1"
PARALLEL_BUILD_N=22


build:
	# Highlights errors and warnings if the initial compilation attempt fails
	@cd ./vmm/ && make ${DEBUG_BUILD} -j ${PARALLEL_BUILD_N} && make install -j ${PARALLEL_BUILD_N}; \
	if [ $$? -ne 0 ] ; then \
	   echo; \
	   echo ==================================; \
	   echo Warnings:; \
	   (make ${DEBUG_BUILD} -j 16 2>&1 && make install -j 16)  | sort | uniq -c | grep   --color=always -i warning; \
	   echo; \
	   echo ==================================; \
	   echo Errors:; \
	   (make ${DEBUG_BUILD} -j 16 2>&1 && make install -j 16)  | grep  -2 --color=always -i 'error\|-o '; \
	   false; \
	fi
	date


tags:
	cd vmm/ && ctags * target-i386/* hw/* tcg/*

grep:
	-cd vmm/ && find . | grep -v ".svn" | grep '\.c\|\.h\|\.cpp' | xargs -n 100 grep -n . > ../grep-all.txt
	-cd vmm/ && find . target-i386/ -maxdepth 1 | grep -v ".svn" | grep '\.c\|\.h\|\.cpp' | xargs -n 100 grep -n . > ../grep-main.txt

