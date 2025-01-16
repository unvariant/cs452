const rpi = @cImport(@cInclude("rpi.h"));
const std = @import("std");
const uart = @import("uart.zig");
const mmio = @import("mmio.zig");
const timers = @import("timers.zig");
const vectors = @import("vectors.zig");
const tasks = @import("tasks.zig");
const sys = @import("sys.zig");

var systimer: *volatile timers.Timers = @ptrFromInt(mmio.BASE + 0x3000);
const console = uart.channel(uart.CHANNEL1);
const USER_PRIORITY: tasks.Priority = 8;

export fn kmain() callconv(.C) noreturn {
    uart.init();
    try console.print("[+] UART initialized\r\n", .{});

    try console.print("[+] initializing vectors\r\n", .{});
    vectors.init();
    try console.print("[+] interrupt vectors initialized\r\n", .{});

    try console.print("[+] registering idle task\r\n", .{});
    _ = tasks.create(tasks.PRIORITY_MIN, &idle);

    try console.print("[+] bootstrapping scheduler\r\n", .{});
    tasks.bootstrap(&init, USER_PRIORITY);

    @panic("end of kmain");
}

fn init() noreturn {
    try console.print("[+] init\r\n", .{});

    _ = tasks.create();
    sys.yield();
    while (true) {}
}

fn idle() noreturn {
    while (true) {}
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    try console.print("panic: {s}\r\n", .{msg});
    while (true) {}
}
