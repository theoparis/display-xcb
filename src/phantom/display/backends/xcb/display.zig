const std = @import("std");
const Allocator = std.mem.Allocator;
const phantom = @import("phantom");
const Output = @import("output.zig");
const Self = @This();

allocator: Allocator,
kind: phantom.display.Base.Kind,

pub fn init(alloc: Allocator, kind: phantom.display.Base.Kind) Self {
    return .{
        .allocator = alloc,
        .kind = kind,
    };
}

pub fn deinit(self: *Self) void {
    _ = self;
}

pub fn display(self: *Self) phantom.display.Base {
    return .{
        .vtable = &.{
            .outputs = impl_outputs,
        },
        .type = @typeName(Self),
        .ptr = self,
        .kind = self.kind,
    };
}

fn impl_outputs(ctx: *anyopaque) anyerror!std.ArrayList(*phantom.display.Output) {
    const self: *Self = @ptrCast(@alignCast(ctx));
    var outputs = std.ArrayList(*phantom.display.Output).init(self.allocator);
    errdefer outputs.deinit();

    // TODO: implement me
    return outputs;
}
