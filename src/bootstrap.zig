const rpi = @cImport(@cInclude("rpi.h"));
const std = @import("std");
const uart = @import("uart.zig");
const mmio = @import("mmio.zig");
const timers = @import("timers.zig");
const vectors = @import("vectors.zig");
const tasks = @import("tasks.zig");
const main = @import("main.zig");

var systimer: *volatile timers.Timers = @ptrFromInt(mmio.BASE + 0x3000);

export fn kmain() callconv(.C) noreturn {
    uart.init();
    try uart.con.print("[+] UART initialized\r\n", .{});

    try uart.con.print("[+] initializing vectors\r\n", .{});
    vectors.init();
    try uart.con.print("[+] interrupt vectors initialized\r\n", .{});

    try uart.con.print("[+] initializing scheduler (but not running)\r\n", .{});
    tasks.init(&main.wrapper);
    try uart.con.print("[+] scheduler initialized (but not running)\r\n", .{});

    try uart.con.print("[+] bootstrapping scheduler (running)\r\n", .{});
    tasks.bootstrap(&main.init, main.init_priority);

    @panic("end of kmain");
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    try uart.con.print("panic: {s}\r\n", .{msg});
    while (true) {}
}
