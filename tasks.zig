const std = @import("std");
const PriorityQueue = std.PriorityQueue;
const Order = std.math.Order;
const uart = @import("uart.zig");
const vectors = @import("vectors.zig");
const Context = vectors.Context;
const DoublyLinkedList = std.DoublyLinkedList;

// maximum number of tasks
const NUM_TASKS: usize = 128;
const Task = struct {
    const Self = @This();
    const State = enum {
        Active,
        Ready,
        Exited,
    };

    state: State,
    priority: Priority,
    context: Context,
    // TODO: move outside of task
    // 1 MB stack
    stack: [0x100000]u8 align(16),

    pub fn idx(self: *const Self) usize {
        return self - @as(*const Self, @ptrCast(&global_tasks));
    }
};

pub const Priority = usize;
const NUM_PRIORITIES: Priority = 16;
pub const PRIORITY_MAX: Priority = NUM_PRIORITIES - 1;
pub const PRIORITY_MIN: Priority = 0;
const Queue = DoublyLinkedList(Task);

const Tid = usize;
const Start = *const fn () noreturn;
var task_count: usize = 0;
var global_tasks: [NUM_TASKS]Queue.Node = undefined;
var queues: [NUM_PRIORITIES]Queue = [_]Queue{Queue{}} ** NUM_PRIORITIES;
var current_task: *Queue.Node = undefined;
const console = uart.channel(uart.CHANNEL1);

pub fn bootstrap(init: Start, priority: Priority) noreturn {
    const init_task = create(priority, init);
    current_task = &global_tasks[init_task];
    current_task.data.context.program_status = 0b1111_00_0101;

    try console.print("init = 0x{x}\r\n", .{@intFromPtr(init)});
    try console.print("exception return = 0x{x}\r\n", .{current_task.data.context.exception_return});

    asm volatile (
        \\  msr elr_el1, %[exception_return]
        \\  msr spsr_el1, %[program_status]
        \\  mov sp, %[exception_stack]
        \\  eret
        :
        : [exception_return] "r" (current_task.data.context.exception_return),
          [program_status] "r" (current_task.data.context.program_status),
          [exception_stack] "r" (current_task.data.context.exception_stack),
    );

    @panic("failed scheduler bootstrap");
}

pub fn save(context: *Context) void {
    current_task.data.context = context.*;
    current_task.data.context.exception_stack = @intFromPtr(context) + @sizeOf(Context);
}

pub fn create(priority: Priority, start: Start) Tid {
    if (priority >= NUM_PRIORITIES) {
        @panic("invalid priority");
    }

    const tid = task_count;
    const node = &global_tasks[tid];
    const task = &node.data;
    queues[priority].append(node);
    task.priority = priority;
    task.context.exception_return = @intFromPtr(start);
    task.context.exception_stack = @intFromPtr(&task.stack) + task.stack.len;
    task.context.program_status = 0b1111_00_0101;
    task_count += 1;
    return tid;
}

pub fn exit() void {
    var queue = &queues[current_task.data.priority];
    queue.remove(current_task);
}

pub fn schedule() *Task {
    for (0..NUM_PRIORITIES) |i| {
        const priority = NUM_PRIORITIES - 1 - i;
        var queue = queues[priority];
        if (queue.len > 0) {
            // try console.print("found task at prio {}\r\n", .{priority});
            current_task = queue.popFirst().?;
            queue.append(current_task);
            return &current_task.data;
        }
    }

    @panic("unable to find task to schedule");
}
