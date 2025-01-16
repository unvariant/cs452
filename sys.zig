const tasks = @import("tasks.zig");
const uart = @import("uart.zig");

const Call = enum {
    Exit,
    Yield,
};

pub fn handle_syscall(nr: u64, args: []const u64) u64 {
    _ = args;
    const syscall: Call = @enumFromInt(nr);
    switch (syscall) {
        .Exit => {
            tasks.exit();
        },
        .Yield => {},
    }
    return 0;
}

pub fn yield() void {
    const nr: usize = @intFromEnum(Call.Yield);
    asm volatile (
        \\  svc #0
        :
        : [nr] "{x8}" (nr),
    );
}

pub fn exit() noreturn {
    const nr: usize = @intFromEnum(Call.Exit);
    asm volatile (
        \\  svc #0
        :
        : [nr] "{x8}" (nr),
    );
    @panic("returned from exit");
}
