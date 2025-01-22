const uart = @import("uart.zig");
const sys = @import("sys.zig");
const tasks = @import("tasks.zig");

const Tid = tasks.Tid;
const Priority = tasks.Priority;

const console = uart.channel(uart.CHANNEL1);

pub const init_priority = tasks.PRIORITY_MAX - 1;
pub fn init() !void {
    try console.print("[+] init\r\n", .{});

    const priorities = [_]Priority{ init_priority - 1, init_priority - 1, init_priority + 1, init_priority + 1 };
    for (priorities) |prio| {
        const tid = try sys.create(prio, &test_task);
        try console.print("Created: {}\r\n", .{tid});
    }

    try console.print("FirstUserTask: exiting\r\n", .{});
}

fn test_task() !void {
    try console.print("Tid: {}, pTid: {}\r\n", .{ sys.my_tid(), sys.my_parent_tid() });
    sys.yield();
    try console.print("Tid: {}, pTid: {}\r\n", .{ sys.my_tid(), sys.my_parent_tid() });
}
