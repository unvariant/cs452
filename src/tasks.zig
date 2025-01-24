const std = @import("std");
const Order = std.math.Order;
const uart = @import("uart.zig");
const vectors = @import("vectors.zig");
const sys = @import("sys.zig");
const PriorityQueue = std.PriorityQueue;
const Context = vectors.Context;
const DoublyLinkedList = std.DoublyLinkedList;

// maximum number of tasks
pub const NUM_TASKS: usize = 128;
// task stack size
pub const STACK_SIZE: usize = 0x800000;
// maximum number of priority levels
pub const NUM_PRIORITIES: usize = 16;
pub const PRIORITY_MAX: Priority = NUM_PRIORITIES - 1;
pub const PRIORITY_MIN: Priority = 0;
// the type of the task function
pub const Start = *const fn () sys.Error!void;
pub const Wrapper = *const fn (Start) noreturn;
pub const Tid = usize;
pub const Priority = usize;

const Packet = struct {
    const Self = @This();

    buf: []u8,

    pub fn tid(self: *const Self) Tid {
        return (@intFromPtr(self) - @intFromPtr(&global_packets)) / @sizeOf(Self);
    }
};
const RecvQueue = DoublyLinkedList(Packet);
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

    stack: [*]align(16) u8,

    ptid: Tid,

    recv: ?[]u8,
    recvQueue: RecvQueue,

    pub fn tid(self: *const Self) Tid {
        return (@intFromPtr(self) - @intFromPtr(&global_tasks)) / @sizeOf(TaskQueue.Node);
    }
};
const TaskQueue = DoublyLinkedList(Task);

var task_count: usize = 0;
var global_tasks: [NUM_TASKS]TaskQueue.Node = undefined;
// 8 MB stack per task
// `align(16)` is *supposed* to set the alignment to 16,
// but @alignOf still reports alignment of 1.
var global_stacks: [NUM_TASKS][STACK_SIZE]u8 align(16) = undefined;
// Maximum number of in-flight packets is limited by the maximum number of tasks
// Worst case scenario:
//  Task 1..NUM_TASKS execute send to Task 0
//  Now Task 0 has NUM_TASKS-1 packets in its queue
//  Task 0 executes send to Task 1
//  Now there are NUM_TASKS packets in-flight, and all tasks are blocked
var global_packets: [NUM_TASKS]RecvQueue.Node = undefined;
var queues: [NUM_PRIORITIES]TaskQueue = [_]TaskQueue{TaskQueue{}} ** NUM_PRIORITIES;
var current_task: *TaskQueue.Node = undefined;
var wrapper: Wrapper = undefined;

pub fn init(wrapper_fn: Wrapper) void {
    // write noticable bytes to stack memory
    // this takes a while
    // @memset(@as([*]u8, @ptrCast(&global_stacks))[0..@sizeOf(@TypeOf(global_stacks))], 0xcc);
    // initialize everything to exited
    for (0..NUM_TASKS) |i| {
        global_tasks[i].data.state = .Exited;
    }

    wrapper = wrapper_fn;

    try uart.con.print("[+] registering idle task\r\n", .{});
    current_task = &global_tasks[0];
    _ = check(create(PRIORITY_MIN, &idle));
}

fn idle() noreturn {
    while (true) {
        asm volatile ("wfe");
    }
}

pub fn bootstrap(start: Start, priority: Priority) noreturn {
    const init_task = check(create(priority, start));
    current_task = &global_tasks[init_task];
    const curr = &current_task.data;
    curr.state = .Active;

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

fn available_tid() ?Tid {
    for (0..NUM_TASKS) |i| {
        const tid = (task_count + i) % NUM_TASKS;
        // try uart.con.print("state[{}] = {s}\r\n", .{ tid, @tagName(global_tasks[tid].data.state) });
        if (global_tasks[tid].data.state == .Exited) {
            return tid;
        }
    }
    return null;
}

pub fn create(priority: Priority, start: Start) isize {
    if (priority >= NUM_PRIORITIES) {
        return -1;
    }
    const maybe_tid = available_tid();
    // try uart.con.print("tid = {?}\r\n", .{maybe_tid});
    if (maybe_tid == null) {
        return -2;
    }

    const tid = maybe_tid.?;
    const node = &global_tasks[tid];
    const task = &node.data;
    queues[priority].prepend(node);
    task.state = .Ready;
    task.priority = priority;
    task.ptid = current_task.data.tid();
    task.context.user_stack = @intFromPtr(&global_stacks[tid]) + STACK_SIZE;
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
        queues[task.priority].prepend(&global_tasks[task.tid()]);
        // set the recv blocked task return value
        task.context.general[0] = sendbuf.len;
        // now we are reply blocked
        queues[curr.priority].remove(current_task);
        curr.state = .WaitingForReply;
    } else {
        // target has not already executed recv, and is still running
        // add packet to targets recv queue
        const packet = &global_packets[curr.tid()];
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
        const task = &global_tasks[packet.tid()].data;
        // sanity check
        if (task.state != .WaitingForReceive) {
            try uart.con.print("task {} is not waiting for recv?\r\n", .{task.tid()});
            @panic("abort");
        }
        const len = @min(recvbuf.len, packet.buf.len);
        @memcpy(recvbuf[0..len], packet.buf[0..len]);
        tid.* = packet.tid();
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
    queues[task.priority].prepend(&global_tasks[task.tid()]);
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

pub fn schedule() *Task {
    for (0..NUM_PRIORITIES) |i| {
        const priority = NUM_PRIORITIES - 1 - i;
        var queue = &queues[priority];
        if (queue.len > 0) {
            // try uart.con.print("found task at prio {}\r\n", .{priority});
            current_task = queue.popFirst().?;
            const curr = &current_task.data;
            if (curr.state == .Ready) {
                // try uart.con.print("setting up task start\r\n", .{});
                curr.context.general[0] = curr.context.exception_return;
                curr.context.exception_return = @intFromPtr(wrapper);
                curr.state = .Active;
            }
            queue.append(current_task);
            return curr;
        }
    }

    @panic("unable to find task to schedule");
}
