const uart = @import("uart.zig");
const sys = @import("sys.zig");
const tasks = @import("tasks.zig");

const Tid = tasks.Tid;
const Priority = tasks.Priority;

pub const init_priority = tasks.PRIORITY_MAX - 1;
pub fn init() !void {
    try uart.con.print("[+] init\r\n", .{});

    const priorities = [_]Priority{ init_priority - 1, init_priority - 1, init_priority + 1, init_priority + 1 };
    for (priorities) |prio| {
        const tid = try sys.create(prio, &test_task);
        try uart.con.print("Created: {}\r\n", .{tid});
    }

    try uart.con.print("FirstUserTask: exiting\r\n", .{});
}

fn test_task() !void {
    try uart.con.print("Tid: {}, pTid: {}\r\n", .{ sys.my_tid(), sys.my_parent_tid() });
    sys.yield();
    try uart.con.print("Tid: {}, pTid: {}\r\n", .{ sys.my_tid(), sys.my_parent_tid() });
}

pub fn wrapper(start: tasks.Start) noreturn {
    start() catch |e| {
        try uart.con.print("task {} error: {s}\r\n", .{ sys.my_tid(), @errorName(e) });
    };
    sys.exit();
}
