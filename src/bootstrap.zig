const rpi = @cImport(@cInclude("rpi.h"));
const std = @import("std");
const uart = @import("uart.zig");
const mmio = @import("mmio.zig");
const timers = @import("timers.zig");
const vectors = @import("vectors.zig");
const tasks = @import("tasks.zig");
const sys = @import("sys.zig");
const main = @import("main.zig");

var systimer: *volatile timers.Timers = @ptrFromInt(mmio.BASE + 0x3000);
const console = uart.channel(uart.CHANNEL1);

export fn kmain() callconv(.C) noreturn {
    uart.init();
    try console.print("[+] UART initialized\r\n", .{});

    try console.print("[+] initializing vectors\r\n", .{});
    vectors.init();
    try console.print("[+] interrupt vectors initialized\r\n", .{});

    try console.print("[+] registering idle task\r\n", .{});
    _ = tasks.check(tasks.create(tasks.PRIORITY_MIN, &idle));

    try console.print("[+] bootstrapping scheduler\r\n", .{});
    tasks.bootstrap(&main.init, main.init_priority);

    @panic("end of kmain");
}

fn idle() noreturn {
    while (true) {
        asm volatile ("wfe");
    }
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    try console.print("panic: {s}\r\n", .{msg});
    while (true) {}
}
