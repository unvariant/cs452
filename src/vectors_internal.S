    .section .text
    .global __vector_table

    .extern synchronous_handler
    .extern irq_handler
    .extern fiq_handler
    .extern serror_handler

    // I have no clue what the zig calling convention is,
    // so just save all the gprs.
    // storing 32 general purpose registers
    //  - x0 .. x30
    //  - sp
    //  - LR is x30
    // storing spsr_el1
    //  - stores program flag states and some other information
    // storing esr_el1
    //  - stores the reason for the exception
    // storing far_el1
    //  - stores the virtual address for data abort, pc alignment faults, or watchpoint exceptions
asm_exception_handler:
    // yes there is actually a register called CurrentEL
    // mrs x30, CurrentEL

    str x30, [sp, #8]
    stp x28, x29, [sp, #-0x10]!
    stp x26, x27, [sp, #-0x10]!
    stp x24, x25, [sp, #-0x10]!
    stp x22, x23, [sp, #-0x10]!
    stp x20, x21, [sp, #-0x10]!
    stp x18, x19, [sp, #-0x10]!
    stp x16, x17, [sp, #-0x10]!
    stp x14, x15, [sp, #-0x10]!
    stp x12, x13, [sp, #-0x10]!
    stp x10, x11, [sp, #-0x10]!
    stp x8,  x9,  [sp, #-0x10]!
    stp x6,  x7,  [sp, #-0x10]!
    stp x4,  x5,  [sp, #-0x10]!
    stp x2,  x3,  [sp, #-0x10]!
    stp x0,  x1,  [sp, #-0x10]!

    mrs x0,  spsr_el1
    mrs x1,  elr_el1
    mrs x2,  esr_el1
    mrs x3,  far_el1
    mrs x4,  sp_el0

    stp x0,  x1,  [sp, #-0x10]!
    stp x2,  x3,  [sp, #-0x10]!
    stp x4,  xzr,  [sp, #-0x10]!

    mov x0,  sp

    bl  zig_exception_handler

    ldp x1,  x2,  [sp], #0x10

    msr sp_el0,   x1

    add sp,  sp,  #0x10

    // x0 = spsr_el1
    // x1 = elr_el1
    ldp x1,  x2,  [sp], #0x10

    msr spsr_el1, x1
    msr elr_el1,  x2

    ldp x0,  x1,  [sp], #0x10
    ldp x2,  x3,  [sp], #0x10
    ldp x4,  x5,  [sp], #0x10
    ldp x6,  x7,  [sp], #0x10
    ldp x8,  x9,  [sp], #0x10
    ldp x10, x11, [sp], #0x10
    ldp x12, x13, [sp], #0x10
    ldp x14, x15, [sp], #0x10
    ldp x16, x17, [sp], #0x10
    ldp x18, x19, [sp], #0x10
    ldp x20, x21, [sp], #0x10
    ldp x22, x23, [sp], #0x10
    ldp x24, x25, [sp], #0x10
    ldp x26, x27, [sp], #0x10
    ldp x28, x29, [sp], #0x10
    ldp x30, xzr, [sp], #0x10
    eret

.macro define_exception_handler index
    .align 7
    stp lr,  xzr, [sp, #-0x10]!
    bl asm_exception_handler
.endm

// Bits 10-0 inclusive of vbar_el1 are reserved and must be 0.
// Each exception is 0x80 apart and is allowed to contain arbitrary code.
// .align  [n] aligns the code to 2^n
// .balign [n] aligns the code to n

    .align 11
__vector_table:
    define_exception_handler 0
    define_exception_handler 1
    define_exception_handler 2
    define_exception_handler 3
    define_exception_handler 4
    define_exception_handler 5
    define_exception_handler 6
    define_exception_handler 7
    define_exception_handler 8
    define_exception_handler 9
    define_exception_handler 10
    define_exception_handler 11
