#
# Makefile for linux.
# If you don't have '-mstring-insns' in your gcc (and nobody but me has :-)
# remove them from the CFLAGS defines.
#

AS86	=as -0 -a
CC86	=cc -0
LD86	=ld -0

AS	=as
ASFLAGS =--32
# AS = gas
LD	=gld
LDFLAGS	=-s -x -M
CC	=gcc
# CFLAGS	=-Wall -O -fstrength-reduce -fomit-frame-pointer -fcombine-regs -D32_BIT
#pterror gcc: error: unrecognized command line option ‘-fcombine-regs’; did you mean ‘-Wcompare-reals’?
#pterror <command-line>:0:1: error: macro names must be identifiers (-D32_BIT)
CFLAGS	=-Wall -O -fstrength-reduce -fomit-frame-pointer -Wcompare-reals -m32
CPP	=gcc -E -nostdinc -Iinclude

ARCHIVES=kernel/kernel.o mm/mm.o fs/fs.o
LIBS	=lib/lib.a

.c.s:
	$(CC) $(CFLAGS) \
	-nostdinc -Iinclude -S -o $*.s $<
.s.o:
	$(AS) $(ASFLAGS) -c -o $*.o $<
.c.o:
	$(CC) $(CFLAGS) \
	-nostdinc -Iinclude -c -o $*.o $<


all:	Image

Image: boot/boot tools/system tools/build
	tools/build boot/boot tools/system > Image
	sync

tools/build: tools/build.c
	$(CC) $(CFLAGS) \
	-o tools/build tools/build.c
	chmem +65000 tools/build

boot/head.o: boot/head.s
 
tools/system:	boot/head.o init/main.o \
		$(ARCHIVES) $(LIBS)
	$(LD) $(LDFLAGS) boot/head.o init/main.o \
	$(ARCHIVES) \
	$(LIBS) \
	-o tools/system > System.map

kernel/kernel.o:
	(cd kernel; make)

mm/mm.o:
	(cd mm; make)

fs/fs.o:
	(cd fs; make)

lib/lib.a:
	(cd lib; make)

boot/boot:	boot/boot.s tools/system
	(echo -n "SYSSIZE = (";ls -l tools/system | grep system \
		| cut -c25-31 | tr '\012' ' '; echo "+ 15 ) / 16") > tmp.s
	cat boot/boot.s >> tmp.s
	$(AS86) -o boot/boot.o tmp.s
	rm -f tmp.s
	$(LD86) -s -o boot/boot boot/boot.o

clean:
	rm -f Image System.map tmp_make boot/boot core
	rm -f init/*.o boot/*.o tools/system tools/build
	(cd mm;make clean)
	(cd fs;make clean)
	(cd kernel;make clean)
	(cd lib;make clean)

backup: clean
	(cd .. ; tar cf - linux | compress16 - > backup.Z)
	sync

dep:
	sed '/\#\#\# Dependencies/q' < Makefile > tmp_make
	(for i in init/*.c;do echo -n "init/";$(CPP) -M $$i;done) >> tmp_make
	cp tmp_make Makefile
	(cd fs; make dep)
	(cd kernel; make dep)
	(cd mm; make dep)

### Dependencies:
init/main.o : init/main.c include/unistd.h include/sys/stat.h \
  include/sys/types.h include/sys/times.h include/sys/utsname.h \
  include/utime.h include/time.h include/linux/tty.h include/termios.h \
  include/linux/sched.h include/linux/head.h include/linux/fs.h \
  include/linux/mm.h include/asm/system.h include/asm/io.h include/stddef.h \
  include/stdarg.h include/fcntl.h
# echo 'init/main.o recipe'



# notes:
# 1. 需要建立tools/build tools/system boot/boot 三种image, 然后打包到Image？
# 2. tools/system 是依赖init/main.o 的, 所以需要先编译出init/main.o
# 3. .c.s 意思是比如一个recipe是 A: xx.s但是A使用默认规则, 所以会自动应用.c.s规则先编译出xx.s ?
# 4. make 4.1 编译失败 
#	 gcc ... init/main.o init/main.c
#     但是显然这种命令不是所期望的，头文件完全没有编译近来

# 编译文件顺序:
# boot/head.s -> boot/head.o
# init/main.c xxxs.h -> init/main.o