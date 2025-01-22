const tasks = @import("tasks.zig");
const uart = @import("uart.zig");

const Tid = tasks.Tid;

const console = uart.channel(uart.CHANNEL1);

pub const Error = error{
    InvalidPriority,
    TooManyTasks,
    TaskDoesNotExist,
    TaskNotReplyBlocked,
};

pub fn create(priority: tasks.Priority, start: tasks.Start) Error!Tid {
    const ret = syscall(.Create, .{ priority, start });
    if (ret < 0) {
        return switch (ret) {
            -1 => Error.InvalidPriority,
            -2 => Error.TooManyTasks,
            else => @panic("invalid create return value"),
        };
    }
    return @bitCast(ret);
}

pub fn my_tid() Tid {
    return @bitCast(syscall(.MyTid, .{}));
}

pub fn my_parent_tid() Tid {
    return @bitCast(syscall(.MyParentTid, .{}));
}

pub fn yield() void {
    _ = syscall(.Yield, .{});
}

pub fn exit() noreturn {
    _ = syscall(.Exit, .{});
    @panic("returned from exit");
}

pub fn send(tid: Tid, sendbuf: []const u8, replybuf: []u8) Error!usize {
    const ret = syscall(.Send, .{ tid, sendbuf.ptr, sendbuf.len, replybuf.ptr, replybuf.len });
    if (ret < 0) {
        return switch (ret) {
            -1 => Error.TaskDoesNotExist,
            else => @panic("invalid send return value"),
        };
    }
    return @bitCast(ret);
}

pub fn recv(tid: *Tid, recvbuf: []u8) Error!usize {
    const ret = syscall(.Recv, .{ tid, recvbuf.ptr, recvbuf.len });
    return @bitCast(ret);
}

pub fn reply(tid: Tid, replybuf: []const u8) Error!usize {
    const ret = syscall(.Reply, .{ tid, replybuf.ptr, replybuf.len });
    if (ret < 0) {
        return switch (ret) {
            -1 => Error.TaskDoesNotExist,
            -2 => Error.TaskNotReplyBlocked,
            else => @panic("invalid reply return value"),
        };
    }
    return @bitCast(ret);
}

const Call = enum {
    Create,
    MyTid,
    MyParentTid,
    Yield,
    Exit,
    Send,
    Recv,
    Reply,
};

pub fn handle_syscall(nr: u64, args: []const u64) ?i64 {
    const call: Call = @enumFromInt(nr);
    // try console.print("call = {s}\r\n", .{@tagName(call)});
    switch (call) {
        .Create => {
            const priority = args[0];
            const start: tasks.Start = @ptrFromInt(args[1]);
            return tasks.create(priority, start);
        },
        .MyTid => return @bitCast(tasks.current().tid),
        .MyParentTid => return @bitCast(tasks.current().ptid),
        .Yield => return 0,
        .Exit => {
            tasks.exit(tasks.current().tid);
            return null;
        },
        .Send => {
            const tid = args[0];
            const sendptr: [*]u8 = @ptrFromInt(args[1]);
            const sendlen = args[2];
            const recvptr: [*]u8 = @ptrFromInt(args[3]);
            const recvlen = args[4];
            return tasks.send(tid, sendptr[0..sendlen], recvptr[0..recvlen]);
        },
        .Recv => {
            const tid: *Tid = @ptrFromInt(args[0]);
            const recvptr: [*]u8 = @ptrFromInt(args[1]);
            const recvlen = args[2];
            return tasks.recv(tid, recvptr[0..recvlen]);
        },
        .Reply => {
            const tid = args[0];
            const replyptr: [*]u8 = @ptrFromInt(args[1]);
            const replylen = args[2];
            return tasks.reply(tid, replyptr[0..replylen]);
        },
    }
}

inline fn syscall(call: Call, args: anytype) i64 {
    if (args.len > 5) {
        @panic("too many syscall arguments");
    }
    const num: [1]u8 = [_]u8{@truncate(0x30 + args.len)};
    const ret = @call(.always_inline, @field(@This(), "syscall" ++ &num), .{ @intFromEnum(call), args });
    return @bitCast(ret);
}

fn syscall0(nr: u64, args: anytype) u64 {
    _ = args;
    return asm volatile (
        \\  svc #0
        : [ret] "={x0}" (-> u64),
        : [nr] "{x8}" (nr),
    );
}

fn syscall1(nr: u64, args: anytype) u64 {
    return asm volatile (
        \\  svc #0
        : [ret] "={x0}" (-> u64),
        : [nr] "{x8}" (nr),
          [arg0] "{x0}" (args[0]),
    );
}

fn syscall2(nr: u64, args: anytype) u64 {
    return asm volatile (
        \\  svc #0
        : [ret] "={x0}" (-> u64),
        : [nr] "{x8}" (nr),
          [arg0] "{x0}" (args[0]),
          [arg1] "{x1}" (args[1]),
    );
}

fn syscall3(nr: u64, args: anytype) u64 {
    return asm volatile (
        \\  svc #0
        : [ret] "={x0}" (-> u64),
        : [nr] "{x8}" (nr),
          [arg0] "{x0}" (args[0]),
          [arg1] "{x1}" (args[1]),
          [arg2] "{x2}" (args[2]),
    );
}

fn syscall4(nr: u64, args: anytype) u64 {
    return asm volatile (
        \\  svc #0
        : [ret] "={x0}" (-> u64),
        : [nr] "{x8}" (nr),
          [arg0] "{x0}" (args[0]),
          [arg1] "{x1}" (args[1]),
          [arg2] "{x2}" (args[2]),
          [arg3] "{x3}" (args[3]),
    );
}

fn syscall5(nr: u64, args: anytype) u64 {
    return asm volatile (
        \\  svc #0
        : [ret] "={x0}" (-> u64),
        : [nr] "{x8}" (nr),
          [arg0] "{x0}" (args[0]),
          [arg1] "{x1}" (args[1]),
          [arg2] "{x2}" (args[2]),
          [arg3] "{x3}" (args[3]),
          [arg4] "{x4}" (args[4]),
    );
}
