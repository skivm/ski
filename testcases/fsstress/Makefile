#
#    kernel/fs/fsstress testcases Makefile.
#
#    Copyright (C) 2009, Cisco Systems Inc.
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Garrett Cooper, July 2009
#

top_srcdir			?= ./fsstress-support/
include $(top_srcdir)/include/mk/env_pre.mk


###############################

# Comment this line to run POSIX ops only
CPPFLAGS += -DBTRFS_ENABLED


################################


CPPFLAGS			+= -DNO_XFS -I$(abs_srcdir) \
				   -D_LARGEFILE64_SOURCE -D_GNU_SOURCE

# if removed -DNO_XFS, you should unmask the following line
#LDLIBS				+= -lattr
LDLIBS				+= -lpthread -lrt
LDLIBS              += -m32

# XXX (garrcoop): not -Wuninitialized clean.
CPPFLAGS			+= -Wno-error
CPPFLAGS			+= -O0

btrfs_libs = -luuid -lblkid -lm -lz -llzo2
btrfs_convert_libs = -lext2fs -lcom_err
btrfs_image_libs = -lpthread
#btrfs_fragment_libs = -lgd -lpng -ljpeg -lfreetype


btrfs_progs_objects = ctree.o disk-io.o radix-tree.o extent-tree.o print-tree.o \
      root-tree.o dir-item.o file-item.o inode-item.o inode-map.o \
      extent-cache.o extent_io.o volumes.o utils.o repair.o \
      qgroup.o raid6.o free-space-cache.o
      
btrfs_progs_cmds_objects = cmds-subvolume.o cmds-filesystem.o cmds-device.o cmds-scrub.o \
           cmds-inspect.o cmds-balance.o cmds-send.o cmds-receive.o \
           cmds-quota.o cmds-qgroup.o cmds-replace.o cmds-check.o \
           cmds-restore.o cmds-chunk.o

btrfs_progs_utils_objects = help.o btrfs_nomain.o send-stream.o send-utils.o rbtree.o btrfs-list.o crc32c.o



btrfs_objects_basename = $(basename $(btrfs_progs_objects) $(btrfs_progs_cmds_objects) $(btrfs_progs_utils_objects))

#mkfile_path2 := $(abspath $(lastword $(MAKEFILE_LIST)))
#current_dir2 := $(notdir $(patsubst %/,%,$(dir $(mkfile_path2))))

current_dir2 = $(shell pwd)

DIR_BTRFS_OBJ := $(current_dir2)/git-btrfs-progs/btrfs-progs/
DIR_BTRFS_INCLUDE := $(current_dir2)/git-btrfs-progs/include/
DIR_BTRFS_LIB := $(current_dir2)/git-btrfs-progs/lib/


CPPFLAGS_BTRFS=-D_FILE_OFFSET_BITS=64 -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2 -DBTRFS_FLAT_INCLUDES -fPIC -g -m32 

CPPFLAGS += -I$(DIR_BTRFS_INCLUDE) $(CPPFLAGS_BTRFS)
LDLIBS += -static -L$(DIR_BTRFS_LIB) $(btrfs_libs) $(btrfs_convert_libs) $(btrfs_image_libs)



FILTER_OUT_MAKE_TARGETS     := Makefile ski-barriers ski-hyper ski-params ski-test sync-test $(btrfs_objects_basename)

include $(top_srcdir)/include/mk/generic_leaf_target.mk

$(MAKE_TARGETS): %: %.o  ski-barriers.o ski-hyper.o ski-params.o ski-test.o $(addprefix $(DIR_BTRFS_OBJ), $(btrfs_progs_objects) $(btrfs_progs_cmds_objects) $(btrfs_progs_utils_objects))

fsstress.o: Makefile
