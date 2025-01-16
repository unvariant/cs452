const std = @import("std");
const uart = @import("uart.zig");
const tasks = @import("tasks.zig");
const sys = @import("sys.zig");

pub const Context = extern struct {
    // exception syndrome register (esr)
    exception_reason: u64,
    // fault address register (far)
    fault_address: u64,
    // saved program status register (spsr)
    // restored on task switch
    program_status: u64,
    // exception link register
    // restored on task switch
    exception_return: u64,
    // general purpose registers
    // restored on task switch
    general: [31]u64,
    // saved stack pointer
    // restored on task switch
    exception_stack: u64,
};

// zig fmt: off
const ExceptionClass = enum(u6) {
    Unknown                             = 0b000000,
    TrappedWaitFor                      = 0b000001,
    TrappedCoprocessorMoveSingle1111    = 0b000011,
    TrappedCoprocessorMoveDouble1111    = 0b000100,
    TrappedCoprocessorMoveSingle1110    = 0b000101,
    // load or store from coprocessor memory
    TrappedCoprocessorAccess            = 0b000110,
    TrappedSimd                         = 0b000111,
    TrappedVirtualCoprocessorMoveSingle = 0b001000,
    TrappedPointerAuthentication        = 0b001001,
    TrappedCoprocessorMoveDouble1110    = 0b001100,
    IllegalState                        = 0b001110,
    SupervisorCall32                    = 0b010001,
    HypervisorCall32                    = 0b010010,
    SecureMonitorCall32                 = 0b010011,
    SupervisorCall64                    = 0b010101,
    HypervisorCall64                    = 0b010110,
    SecureMonitorCall64                 = 0b010111,
    TrappedCoprocessorMoveSingleExtra   = 0b011000,
    InstructionAbortFromLowerRing       = 0b100000,
    InstructionAbortFromSameRing        = 0b100001,
    ProgramCounterAlignmentFault        = 0b100010,
    DataAbortFromLowerRing              = 0b100100,
    DataAbortFromSameRing               = 0b100101,
    StackAlignmentFault                 = 0b100110,
    TrappedFloatingPoint64              = 0b101100,
    _,
};
// zig fmt: on

export fn generic_vector_handler(context: *Context, index: u64) callconv(.C) void {
    zig_generic_vector_handler(context, index);
}

var nested_data_abort: u32 = 0;

fn zig_generic_vector_handler(context: *Context, index: u64) void {
    _ = index;

    const console = uart.channel(uart.CHANNEL1);
    // See page D10.2.39 (pg 2436) of ref 1
    // Format of Exception Syndrome Register (exception_reason)
    // | 31..26 | 25 | 24..0 |
    // | EC     | IL | ISS   |
    // Exception Class (EC)
    // Instruction Length (IL)
    //  - length of the instruction on relevant exceptions
    //  - IL = 0 for 16 bit instructions (ARM THUMB)
    //  - IL = 1 for 32 bit instructions (ARM and ARM64)
    // Instruction Specific Syndrome
    //  - extra information about the exception

    const reason_raw = context.exception_reason >> 26;
    const reason: ExceptionClass = @enumFromInt(reason_raw);
    switch (reason) {
        .DataAbortFromSameRing, .DataAbortFromLowerRing => {
            try console.print("fault address = 0x{x}\r\n", .{context.fault_address});
            try console.print("exception return = 0x{x}\r\n", .{context.exception_return});
            if (nested_data_abort >= 1) @panic("nested abort");
            nested_data_abort += 1;
            @panic("abort");
        },
        .SupervisorCall64 => {
            const nr = context.general[8];
            const args: []const u64 = context.general[0..8];
            _ = sys.handle_syscall(nr, args);
        },
        else => {},
    }

    const name = @tagName(reason);
    try console.print("exception: {b} ({s})\r\n", .{ reason_raw, name });

    tasks.save(context);

    const task = tasks.schedule();
    context.exception_return = task.context.exception_return;
    context.exception_stack = task.context.exception_stack;
    context.program_status = task.context.program_status;
    context.general = task.context.general;

    switch (reason) {
        .DataAbortFromSameRing => {
            nested_data_abort -= 1;
        },
        else => {},
    }
}

extern const __vector_table: u8;

pub fn init() void {
    asm volatile (
        \\msr vbar_el1, %[table]
        :
        : [table] "r" (&__vector_table),
    );
}
