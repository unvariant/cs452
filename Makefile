ARCH=cortex_a72
TRIPLE=aarch64-elf
# CC:=$(TRIPLE)-gcc
ZIG=./zig-macos-aarch64-0.14.0-dev.2643+fb43e91b2/zig
CC:=$(ZIG) cc -target aarch64-freestanding-none
OBJCOPY:=$(TRIPLE)-objcopy
OBJDUMP:=$(TRIPLE)-objdump

# COMPILE OPTIONS
BUILD_DIR=./build/
SOURCE_DIR=./src/
WARNINGS=-Wall -Wextra -Wpedantic -Wno-unused-const-variable
CFLAGS:=-O2 -pipe -static -mstrict-align -ffreestanding -mgeneral-regs-only \
	-mcpu=$(ARCH)-neon-fp_armv8-fullfp16 $(WARNINGS) -fno-stack-protector -nostdlib

# -Wl,option tells g++ to pass 'option' to the linker with commas replaced by spaces
# doing this rather than calling the linker directly simplifies the compilation procedure
LDFLAGS:=-Wl,-T,$(SOURCE_DIR)/linker.ld -nostartfiles

# Root zig source file
ZIG_SOURCE_ROOT=$(SOURCE_DIR)/bootstrap
# Source files and include dirs
SOURCES := $(wildcard $(SOURCE_DIR)/*.c) $(wildcard $(SOURCE_DIR)/*.S)
# Create .o and .d files for every .cc and .S (hand-written assembly) file
# OBJECTS := $(patsubst %.c, $(BUILD_DIR)/%.o, $(patsubst %.S, $(BUILD_DIR)/%.o, $(patsubst %.zig, $(BUILD_DIR)/%.o, $(SOURCES))))
OBJECTS := $(patsubst %.c, $(BUILD_DIR)/%.o, $(patsubst %.S, $(BUILD_DIR)/%.o, $(SOURCES))) $(BUILD_DIR)/$(ZIG_SOURCE_ROOT).o
DEPENDS := $(patsubst %.c, %.d, $(patsubst %.S, %.d, $(SOURCES))) $(BUILD_DIR)/$(ZIG_SOURCE_ROOT).d

# The first rule is the default, ie. "make", "make all" and "make kernal8.img" mean the same
all: build $(BUILD_DIR)/iotest.img

build:
	mkdir -p build/src
	mkdir -p build/src/kernel

clean:
	-rm -rf $(BUILD_DIR)

$(BUILD_DIR)/iotest.img: $(BUILD_DIR)/iotest.elf
	$(OBJCOPY) $< -O binary $@

$(BUILD_DIR)/iotest.elf: $(OBJECTS) $(SOURCE_DIR)/linker.ld
	$(CC) $(CFLAGS) $(filter-out %.ld, $^) -o $@ $(LDFLAGS)
	@$(OBJDUMP) -d $@ | grep -Fq q0 && printf "\n***** WARNING: SIMD DETECTED! *****\n\n" || true

$(BUILD_DIR)/%.o: %.c Makefile
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

$(BUILD_DIR)/%.o: %.S Makefile
	$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

$(BUILD_DIR)/$(ZIG_SOURCE_ROOT).o: $(ZIG_SOURCE_ROOT).zig Makefile
	$(ZIG) build-obj \
		-target aarch64-freestanding-none \
		-mcpu=$(ARCH)-neon-fp_armv8-fullfp16 \
		-static \
		-O ReleaseSafe \
		-I ./src \
		$< -femit-bin=$@

-include $(DEPENDS)
