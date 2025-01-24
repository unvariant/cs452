const std = @import("std");
const uart = @import("uart.zig");
const tasks = @import("tasks.zig");
const sys = @import("sys.zig");

pub const Context = extern struct {
    user_stack: u64,
    nothing: u64,
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
    // scratch space
    scratch: u64,
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

var hits: u32 = 0;

export fn zig_exception_handler(context: *Context) void {
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
    // const index = (std.mem.alignBackward(u64, context.scratch, 0x80) - @intFromPtr(&__vector_table)) / 0x80;
    // try uart.con.print("index({}): {b} ({s})\r\n", .{ index, reason_raw, @tagName(reason) });
    // try uart.con.print("spsr = {b}\r\n", .{context.program_status});

    var syscall_result: ?i64 = null;
    switch (reason) {
        .DataAbortFromSameRing => {
            try uart.con.print("same ring fault\r\n", .{});
            try uart.con.print("fault address = 0x{x}\r\n", .{context.fault_address});
            try uart.con.print("exception return = 0x{x}\r\n", .{context.exception_return});
            @panic("abort");
        },
        .DataAbortFromLowerRing => {
            try uart.con.print("lower ring fault\r\n", .{});
            try uart.con.print("fault address = 0x{x}\r\n", .{context.fault_address});
            try uart.con.print("exception return = 0x{x}\r\n", .{context.exception_return});
            @panic("abort");
        },
        .SupervisorCall64 => {
            const nr = context.general[8];
            const args: []const u64 = context.general[0..8];
            syscall_result = sys.handle(nr, args);
        },
        else => {},
    }

    if (syscall_result) |result| {
        // write syscall result back to the return register
        context.general[0] = @bitCast(result);
    }
    tasks.save(context);
    const task = tasks.schedule();

    context.* = task.context;
    // try uart.con.print("returning to 0x{x}\r\n", .{context.exception_return});
}

extern const __vector_table: u8;

pub fn init() void {
    asm volatile (
        \\msr vbar_el1, %[table]
        :
        : [table] "r" (&__vector_table),
    );
}
