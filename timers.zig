pub const Timers = packed struct {
    const Self = @This();

    status: packed struct(u4) {
        m0: bool,
        m1: bool,
        m2: bool,
        m3: bool,
    },
    _reversed: u28,
    timer_lo: u32,
    timer_hi: u32,
    compare0: u32,
    compare1: u32,
    compare2: u32,
    compare3: u32,

    fn timer(self: *volatile Self) u64 {
        return @as(u64, self.timer_lo) | (@as(u64, self.timer_hi) << 32);
    }
};

comptime {
    if (@offsetOf(Timers, "status") != 0x00) {
        @compileError("bad offset for Timers.status");
    }
    if (@offsetOf(Timers, "timer_lo") != 0x04) {
        @compileError("bad offset for Timers.timer_lo");
    }
    if (@offsetOf(Timers, "timer_hi") != 0x08) {
        @compileError("bad offset for Timers.timer_lo");
    }
    if (@offsetOf(Timers, "compare0") != 0x0c) {
        @compileError("bad offset for Timers.compare");
    }
    if (@offsetOf(Timers, "compare1") != 0x10) {
        @compileError("bad offset for Timers.compare");
    }
    if (@offsetOf(Timers, "compare2") != 0x14) {
        @compileError("bad offset for Timers.compare");
    }
    if (@offsetOf(Timers, "compare3") != 0x18) {
        @compileError("bad offset for Timers.compare");
    }
}
