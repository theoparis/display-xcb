const std = @import("std");
const phantom = @import("phantom");
const vizops = @import("vizops");
const Output = @import("output.zig");
const FrameBuffer = @import("../../../painting/fb/xcb.zig");
const Self = @This();
const c = @cImport({
    @cInclude("xcb/xcb_image.h");
});

base: phantom.display.Surface,
info: phantom.display.Surface.Info,
output: *Output,
scene: ?*phantom.scene.Base,
window: c.xcb_window_t,
fb: ?*FrameBuffer,

pub fn new(output: *Output, info: phantom.display.Surface.Info) !*Self {
    const self = try output.display.allocator.create(Self);
    errdefer output.display.allocator.destroy(self);

    const connection = output.display.connection;
    const size = info.size.value;

    const window = c.xcb_generate_id(connection);
    const root_iterator = c.xcb_setup_roots_iterator(c.xcb_get_setup(connection));
    const root = root_iterator.data.*.root;

    _ = c.xcb_create_window(
        connection,
        c.XCB_COPY_FROM_PARENT,
        window,
        root,
        0,
        0,
        @intCast(size[0]),
        @intCast(size[1]),
        0,
        c.XCB_WINDOW_CLASS_INPUT_OUTPUT,
        root_iterator.data.*.root_visual,
        0,
        null,
    );

    _ = c.xcb_map_window(connection, window);

    _ = c.xcb_flush(connection);

    self.* = .{
        .base = .{
            .ptr = self,
            .vtable = &.{
                .deinit = impl_deinit,
                .destroy = impl_destroy,
                .info = impl_info,
                .updateInfo = impl_update_info,
                .createScene = impl_create_scene,
            },
            .displayKind = output.base.displayKind,
            .kind = .output,
            .type = @typeName(Self),
        },
        .info = info,
        .output = output,
        .scene = null,
        .fb = null,
        .window = window,
    };

    return self;
}

fn impl_deinit(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));

    if (self.fb) |fb| fb.base.deinit();
    if (self.scene) |scene| scene.deinit();

    _ = c.xcb_destroy_window(self.output.display.connection, self.window);

    self.output.display.allocator.destroy(self);
}

fn impl_destroy(ctx: *anyopaque) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    _ = self;
}

fn impl_info(ctx: *anyopaque) anyerror!phantom.display.Surface.Info {
    const self: *Self = @ptrCast(@alignCast(ctx));

    return self.info;
}

fn impl_update_info(ctx: *anyopaque, info: phantom.display.Surface.Info, fields: []std.meta.FieldEnum(phantom.display.Surface.Info)) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    _ = self;
    _ = info;
    _ = fields;
    return error.NotImplemented;
}

fn impl_create_scene(ctx: *anyopaque, backendType: phantom.scene.BackendType) anyerror!*phantom.scene.Base {
    const self: *Self = @ptrCast(@alignCast(ctx));

    if (self.scene) |scene| return scene;

    if (self.fb == null)
        self.fb = try FrameBuffer.new(self);

    self.scene = try phantom.scene.createBackend(backendType, .{
        .allocator = self.output.display.allocator,
        .frame_info = phantom.scene.Node.FrameInfo.init(.{
            .res = self.info.size,
            .scale = vizops.vector.Float32Vector2.init(1.0),
            .colorFormat = self.info.colorFormat.?,
        }),
        .target = .{ .fb = &self.fb.?.base },
    });
    return self.scene.?;
}
