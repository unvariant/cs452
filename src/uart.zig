const rpi = @cImport(@cInclude("rpi.h"));
const std = @import("std");
const Writer = std.io.Writer;

const Error = error{};
fn uart_write(line: usize, bytes: []const u8) Error!usize {
    for (bytes) |ch| {
        rpi.uart_putc(line, ch);
    }
    // rpi.uart_putl(line, bytes.ptr, bytes.len);
    return bytes.len;
}
const UartWriter = Writer(usize, Error, uart_write);

// these numbers are indices into the lines array in rpi.c
pub const CHANNEL1: usize = 1;
pub const CHANNEL2: usize = 2;
pub fn channel(line: usize) UartWriter {
    return UartWriter{ .context = line };
}

pub fn init() void {
    rpi.gpio_init();
    rpi.uart_config_and_enable(CHANNEL1);
    rpi.uart_config_and_enable(CHANNEL2);
}
