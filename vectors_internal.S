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
.macro save_context
    stp x30, xzr, [sp, #-0x10]!
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

    stp x0,  x1,  [sp, #-0x10]!
    stp x2,  x3,  [sp, #-0x10]!
.endm

.macro restore_context
    add sp,  sp,  #16
    // x0 = spsr_el1
    // x1 = elr_el1
    ldp x0, x1, [sp], #16
    msr spsr_el1, x0
    msr elr_el1,  x1
    ldp x0,  x1,  [sp], #16
    ldp x2,  x3,  [sp], #16
    ldp x4,  x5,  [sp], #16
    ldp x6,  x7,  [sp], #16
    ldp x8,  x9,  [sp], #16
    ldp x10, x11, [sp], #16
    ldp x12, x13, [sp], #16
    ldp x14, x15, [sp], #16
    ldp x16, x17, [sp], #16
    ldp x18, x19, [sp], #16
    ldp x20, x21, [sp], #16
    ldp x22, x23, [sp], #16
    ldp x24, x25, [sp], #16
    ldp x26, x27, [sp], #16
    ldp x28, x29, [sp], #16
    ldr x0,  [sp, #8]
    ldp x30, xzr, [sp], #16
    mov sp,  x0
.endm

.macro generic_handler index
    .align 7
    save_context
    mov x1, \index
    mov x0, sp
    bl generic_vector_handler
    restore_context
    eret
.endm

// Bits 10-0 inclusive of vbar_el1 are reserved and must be 0.
// Each exception is 0x80 apart and is allowed to contain arbitrary code.
// .align  [n] aligns the code to 2^n
// .balign [n] aligns the code to n

    .align 11
__vector_table:
    generic_handler 0
    generic_handler 1
    generic_handler 2
    generic_handler 3
    generic_handler 4
    generic_handler 5
    generic_handler 6
    generic_handler 7
