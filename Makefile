ARCH=cortex_a72
TRIPLE=aarch64-elf
# CC:=$(TRIPLE)-gcc
ZIG=./zig-macos-aarch64-0.14.0-dev.2643+fb43e91b2/zig
CC:=$(ZIG) cc -target aarch64-freestanding-none
OBJCOPY:=$(TRIPLE)-objcopy
OBJDUMP:=$(TRIPLE)-objdump

# COMPILE OPTIONS
WARNINGS=-Wall -Wextra -Wpedantic -Wno-unused-const-variable
CFLAGS:=-O2 -pipe -static -mstrict-align -ffreestanding -mgeneral-regs-only \
	-mcpu=$(ARCH)-neon-fp_armv8-fullfp16 $(WARNINGS) -fno-stack-protector -nostdlib

# -Wl,option tells g++ to pass 'option' to the linker with commas replaced by spaces
# doing this rather than calling the linker directly simplifies the compilation procedure
LDFLAGS:=-Wl,-T,linker.ld -nostartfiles

BUILD=./build/
# Source files and include dirs
SOURCES := $(wildcard *.c) $(wildcard *.S)
# Create .o and .d files for every .cc and .S (hand-written assembly) file
# OBJECTS := $(patsubst %.c, $(BUILD)/%.o, $(patsubst %.S, $(BUILD)/%.o, $(patsubst %.zig, $(BUILD)/%.o, $(SOURCES))))
OBJECTS := $(patsubst %.c, $(BUILD)/%.o, $(patsubst %.S, $(BUILD)/%.o, $(SOURCES))) $(BUILD)/main.o
DEPENDS := $(patsubst %.c, %.d, $(patsubst %.S, %.d, $(SOURCES))) $(BUILD)/main.d

# The first rule is the default, ie. "make", "make all" and "make kernal8.img" mean the same
all: iotest.img

clean:
	-rm -f $(BUILD)/*

iotest.img: $(BUILD)/iotest.elf
	$(OBJCOPY) $< -O binary $(BUILD)/$@

$(BUILD)/iotest.elf: $(OBJECTS) linker.ld
	$(CC) $(CFLAGS) $(filter-out %.ld, $^) -o $@ $(LDFLAGS)
	@$(OBJDUMP) -d $@ | grep -Fq q0 && printf "\n***** WARNING: SIMD DETECTED! *****\n\n" || true

$(BUILD)/%.o: %.c Makefile
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

$(BUILD)/%.o: %.S Makefile
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

$(BUILD)/main.o: main.zig Makefile
	$(ZIG) build-obj \
		-target aarch64-freestanding-none \
		-mcpu=$(ARCH)-neon-fp_armv8-fullfp16 \
		-static \
		-O Debug \
		-I . \
		$< -femit-bin=$@

-include $(DEPENDS)
