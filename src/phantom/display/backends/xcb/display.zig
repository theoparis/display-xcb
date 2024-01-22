const std = @import("std");
const Allocator = std.mem.Allocator;
const phantom = @import("phantom");
const Output = @import("output.zig");
const Self = @This();
const c = @cImport({
    @cInclude("xcb/xcb_image.h");
});

allocator: Allocator,
kind: phantom.display.Base.Kind,
connection: ?*c.xcb_connection_t,
setup: *const c.xcb_setup_t,

pub fn init(alloc: Allocator, kind: phantom.display.Base.Kind) Self {
    const connection = c.xcb_connect(null, null);
    if (connection == null)
        @panic("Could not connect to X server");

    const setup = c.xcb_get_setup(connection);
    if (setup == null)
        @panic("Could not get X server setup");

    return .{
        .allocator = alloc,
        .kind = kind,
        .connection = connection,
        .setup = setup,
    };
}

pub fn deinit(self: *Self) void {
    c.xcb_disconnect(self.connection);
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

    var iter = c.xcb_setup_roots_iterator(self.setup);

    while (iter.rem > 0) {
        const screen = iter.data;
        const output = try Output.new(self, screen);
        errdefer output.base.deinit();
        try outputs.append(&output.base);

        c.xcb_screen_next(&iter);
    }

    return outputs;
}
