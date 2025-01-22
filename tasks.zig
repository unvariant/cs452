const std = @import("std");
const Order = std.math.Order;
const uart = @import("uart.zig");
const vectors = @import("vectors.zig");
const sys = @import("sys.zig");
const PriorityQueue = std.PriorityQueue;
const Context = vectors.Context;
const DoublyLinkedList = std.DoublyLinkedList;

// The tid field is redundant here, since you can calculate
// the tid based on the index into the global_packets array
const Packet = struct {
    tid: Tid,
    buf: []u8,
};
const RecvQueue = DoublyLinkedList(Packet);
// maximum number of tasks
const NUM_TASKS: usize = 128;
const Task = struct {
    const Self = @This();
    const State = enum {
        Active,
        Ready,
        Exited,
        WaitingForSend,
        WaitingForReceive,
        WaitingForReply,
    };

    state: State,
    priority: Priority,
    context: Context,

    // TODO: move outside of task
    // 1 MB stack
    stack: [0x100000]u8 align(16),

    tid: Tid,
    ptid: Tid,

    recv: ?[]u8,
    recvQueue: RecvQueue,
};

pub const Priority = usize;
const NUM_PRIORITIES: Priority = 16;
pub const PRIORITY_MAX: Priority = NUM_PRIORITIES - 1;
pub const PRIORITY_MIN: Priority = 0;
const Queue = DoublyLinkedList(Task);

pub const Tid = usize;
pub const Start = *const fn () sys.Error!void;
var task_count: usize = 0;
var global_tasks: [NUM_TASKS]Queue.Node = undefined;
// Maximum number of in-flight packets is limited by the maximum number of tasks
// Worst case scenario:
//  Task 1..NUM_TASKS execute send to Task 0
//  Now Task 0 has NUM_TASKS-1 packets in its queue
//  Task 0 executes send to Task 1
//  Now there are NUM_TASKS packets in-flight, and all tasks are blocked
var global_packets: [NUM_TASKS]RecvQueue.Node = undefined;
var queues: [NUM_PRIORITIES]Queue = [_]Queue{Queue{}} ** NUM_PRIORITIES;
var current_task: *Queue.Node = undefined;
const console = uart.channel(uart.CHANNEL1);

pub fn bootstrap(init: Start, priority: Priority) noreturn {
    const init_task = check(create(priority, init));
    current_task = &global_tasks[init_task];
    const curr = &current_task.data;
    curr.state = .Active;

    // try console.print("init = 0x{x}\r\n", .{@intFromPtr(init)});
    // try console.print("exception return = 0x{x}\r\n", .{current_task.data.context.exception_return});

    asm volatile (
        \\  msr elr_el1, %[wrapper]
        \\  msr spsr_el1, %[program_status]
        \\  msr sp_el0, %[program_stack]
        \\  eret
        :
        : [wrapper] "r" (wrapper),
          [program_status] "r" (curr.context.program_status),
          [program_stack] "r" (curr.context.user_stack),
          [exception_return] "{x0}" (curr.context.exception_return),
    );

    @panic("failed scheduler bootstrap");
}

pub fn save(context: *Context) void {
    current_task.data.context = context.*;
}

pub fn create(priority: Priority, start: Start) isize {
    if (priority >= NUM_PRIORITIES) {
        return -1;
    }

    const tid = task_count;
    const node = &global_tasks[tid];
    const task = &node.data;
    queues[priority].prepend(node);
    task.state = .Ready;
    task.priority = priority;
    task.tid = tid;
    task.ptid = current_task.data.tid;
    task.context.user_stack = @intFromPtr(&task.stack) + task.stack.len;
    task.context.exception_return = @intFromPtr(start);
    task.context.program_status = 0b1111_00_0000;
    task_count += 1;
    return @bitCast(tid);
}

pub fn check(result: isize) Tid {
    return switch (result) {
        -1 => @panic("invalid priority"),
        -2 => @panic("out of task descriptors"),
        else => @bitCast(result),
    };
}

pub fn current() *const Task {
    return &current_task.data;
}

pub fn send(tid: Tid, sendbuf: []u8, recvbuf: []u8) ?isize {
    const task = &global_tasks[tid].data;
    const curr = &current_task.data;

    if (task.state == .Exited) {
        return -1;
    }

    // set up our reply buf
    curr.recv = recvbuf;

    if (task.state == .WaitingForSend) {
        // target has already executed recv, and is blocked waiting for a message
        const buf = task.recv.?;
        const len = @min(sendbuf.len, buf.len);
        @memcpy(buf[0..len], sendbuf[0..len]);
        // reset target recv buf
        task.recv = null;
        // reinsert into the scheduling queue
        task.state = .Ready;
        queues[task.priority].prepend(&global_tasks[task.tid]);
        // set the recv blocked task return value
        task.context.general[0] = sendbuf.len;
        // now we are reply blocked
        queues[curr.priority].remove(current_task);
        curr.state = .WaitingForReply;
    } else {
        // target has not already executed recv, and is still running
        // add packet to targets recv queue
        const packet = &global_packets[curr.tid];
        packet.data.tid = curr.tid;
        packet.data.buf = sendbuf;
        task.recvQueue.append(packet);
        // block until message has been recieved
        queues[curr.priority].remove(current_task);
        curr.state = .WaitingForReceive;
    }

    return null;
}

pub fn recv(tid: *Tid, recvbuf: []u8) ?isize {
    const curr = &current_task.data;
    if (curr.recvQueue.len != 0) {
        // another task has already sent a message
        const packet: Packet = curr.recvQueue.popFirst().?.data;
        const task = &global_tasks[packet.tid].data;
        // sanity check
        if (task.state != .WaitingForReceive) {
            try console.print("task {} is not waiting for recv?\r\n", .{task.tid});
            @panic("abort");
        }
        const len = @min(recvbuf.len, packet.buf.len);
        @memcpy(recvbuf[0..len], packet.buf[0..len]);
        tid.* = packet.tid;
        // set the other task as waiting for reply
        task.state = .WaitingForReply;
        // return value is the full length of the packet message
        // direct return since non-blocking
        return @bitCast(packet.buf.len);
    } else {
        queues[curr.priority].remove(current_task);
        curr.recv = recvbuf;
        curr.state = .WaitingForSend;
        // blocking with no return value for now
        return null;
    }
}

pub fn reply(tid: Tid, replybuf: []u8) isize {
    const task = &global_tasks[tid].data;
    if (task.state == .Exited) {
        return -1;
    }
    if (task.state != .WaitingForReply) {
        // try console.print("task {} is not reply blocked", .{tid});
        // @panic("abort");
        return -2;
    }

    const len = @min(task.recv.?.len, replybuf.len);
    @memcpy(task.recv.?[0..len], replybuf[0..len]);
    // reset the reply buf
    task.recv = null;
    // reinsert into scheduling queue
    task.state = .Ready;
    queues[task.priority].prepend(&global_tasks[task.tid]);
    // set the reply blocked task return value
    task.context.general[0] = replybuf.len;
    // return len directly since reply never blocks
    return @bitCast(len);
}

pub fn exit(tid: Tid) void {
    const task = &global_tasks[tid].data;
    queues[task.priority].remove(&global_tasks[tid]);
    task.state = .Exited;
}

fn wrapper(start: Start) noreturn {
    start() catch |e| {
        try console.print("task {} error: {s}\r\n", .{ sys.my_tid(), @errorName(e) });
    };
    sys.exit();
}

pub fn schedule() *Task {
    for (0..NUM_PRIORITIES) |i| {
        const priority = NUM_PRIORITIES - 1 - i;
        var queue = &queues[priority];
        if (queue.len > 0) {
            // try console.print("found task at prio {}\r\n", .{priority});
            current_task = queue.popFirst().?;
            const curr = &current_task.data;
            if (curr.state == .Ready) {
                // try console.print("setting up task start\r\n", .{});
                curr.context.general[0] = curr.context.exception_return;
                curr.context.exception_return = @intFromPtr(&wrapper);
                curr.state = .Active;
            }
            queue.append(current_task);
            return curr;
        }
    }

    @panic("unable to find task to schedule");
}
