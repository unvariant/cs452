const std = @import("std");
const tasks = @import("tasks.zig");
const sys = @import("sys.zig");

const Tid = tasks.Tid;
const Type = enum {
    register,
    request,
};
pub const Packet = union(Type) {
    register: []u8,
    request: []u8,
};

const Name = struct {
    data: []u8,
    tid: Tid,
};
var global_names: [tasks.NUM_TASKS]Name = undefined;

pub fn main() !void {
    var packet: Packet = undefined;
    var buf: [*]u8 = @ptrCast(&packet);
    var tid: Tid = undefined;
    while (true) {
        sys.recv(&tid, buf[0..@sizeOf(Packet)]);
        switch (packet) {
            Type.register => |name| {
                for (global_names) |*entry| {
                    if (std.mem.eql(u8, name, entry.data)) {
                        entry.data = name;
                        entry.tid = tid;
                    }
                }
                sys.reply(tid, "registered");
            },
            Type.request => |name| {
                for (global_names) |entry| {
                    if (std.mem.eql(u8, name, entry)) {
                        sys.reply(
                            tid,
                        );
                    }
                }
            },
        }
    }
}
