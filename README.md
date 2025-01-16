Building (linux.student.cs.uwaterloo.ca)
========================================

cp -a /u/cs452/public/iotest <dest>
cd <dest>
make

This should produce iotest.elf and iotest.img. You can inspect the .elf file
(e.g., using readelf) to understand the structure of your compiled code. The
.img file is a memory image of your program (generated from the .elf file),
which can be deployed to the RPi and run. See the course web page for
deployment instructions.

# qemu
Custom patch applied to enable access to uart3.

# zig
version `0.14.0-dev.2643+fb43e91b2`
A development version of `0.14.0` is required for proper handling of flags to disable simd.
Custom patch applied to zig standard library to fix default integer formatting miscompile in `std.fmt`.


# reference documents

1. DDI0487C_a_armv8_arm-1.pdf