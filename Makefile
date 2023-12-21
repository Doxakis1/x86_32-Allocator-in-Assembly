NAME = reserve.o
AS=nasm
LD=ld
ASFLAGS=-f elf32
LDFLAGS=-m elf_i386

all: $(NAME)

SOURCE_FILES := $(wildcard *.asm)


$(NAME): $(SOURCE_FILES)
	$(AS) $(ASFLAGS) -o $@ $<

clean:
	rm -f *.o
