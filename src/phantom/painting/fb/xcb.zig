const std = @import("std");
const vizops = @import("vizops");
const phantom = @import("phantom");
const Surface = @import("../../display/backends/xcb/surface.zig");
const Self = @This();

const c = @cImport({
    @cInclude("xcb/xcb_image.h");
});

base: phantom.painting.fb.Base,
surface: *Surface,
pixmap: c.xcb_pixmap_t,
graphics_context: c.xcb_gcontext_t,
image: ?*c.xcb_image_t,
buffer: []u8,

pub fn new(surface: *Surface) !*Self {
    const self = try surface.output.display.allocator.create(Self);
    errdefer surface.output.display.allocator.destroy(self);

    const info = try surface.output.base.info();

    const graphics_context = c.xcb_generate_id(surface.output.display.connection);
    const pixmap = c.xcb_generate_id(surface.output.display.connection);
    _ = c.xcb_create_pixmap(
        surface.output.display.connection,
        surface.output.screen.*.root_depth,
        pixmap,
        surface.window,
        @intCast(info.size.res.value[0]),
        @intCast(info.size.res.value[1]),
    );
    _ = c.xcb_create_gc(
        surface.output.display.connection,
        graphics_context,
        pixmap,
        0,
        null,
    );

    const buffer = try surface.output.display.allocator.alloc(
        u8,
        info.size.res.value[0] * info.size.res.value[1] * @divExact(info.colorFormat.width(), 8),
    );

    const image = c.xcb_image_create_native(
        surface.output.display.connection,
        @intCast(info.size.res.value[0]),
        @intCast(info.size.res.value[1]),
        c.XCB_IMAGE_FORMAT_Z_PIXMAP,
        surface.output.screen.*.root_depth,
        @ptrCast(@alignCast(buffer)),
        @as(u32, @intCast(info.size.res.value[0])) * @as(u32, @intCast(info.size.res.value[1])) * @as(u32, @intCast(@divExact(info.colorFormat.width(), 8))),
        @ptrCast(@alignCast(buffer)),
    );

    self.* = .{
        .base = .{
            .allocator = surface.output.display.allocator,
            .vtable = &.{
                .addr = impl_addr,
                .info = impl_info,
                .dupe = impl_dupe,
                .deinit = impl_deinit,
                .commit = impl_commit,
                .blt = null,
            },
            .ptr = self,
        },
        .surface = surface,
        .pixmap = pixmap,
        .graphics_context = graphics_context,
        .image = image,
        .buffer = buffer,
    };

    return self;
}

fn impl_commit(ctx: *anyopaque) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ctx));

    const info = try self.surface.output.base.info();

    _ = c.xcb_image_put(
        self.surface.output.display.connection,
        self.pixmap,
        self.graphics_context,
        self.image,
        0,
        0,
        0,
    );

    _ = c.xcb_copy_area(
        self.surface.output.display.connection,
        self.pixmap,
        self.surface.window,
        self.graphics_context,
        0,
        0,
        0,
        0,
        @intCast(info.size.res.value[0]),
        @intCast(info.size.res.value[1]),
    );
}

fn impl_addr(ctx: *anyopaque) anyerror!*anyopaque {
    const self: *Self = @ptrCast(@alignCast(ctx));

    return @ptrCast(@alignCast(self.buffer));
}

fn impl_info(ctx: *anyopaque) phantom.painting.fb.Base.Info {
    const self: *Self = @ptrCast(@alignCast(ctx));

    const info = self.surface.output.base.info() catch |e| @panic(@errorName(e));

    return .{
        .res = info.size.res,
        .colorspace = .sRGB,
        .colorFormat = vizops.color.fourcc.Value.decode(
            vizops.color.fourcc.formats.xrgb8888,
        ) catch |e| @panic(@errorName(e)),
    };
}

fn impl_dupe(ctx: *anyopaque) anyerror!*phantom.painting.fb.Base {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return &(try new(self.surface)).base;
}

fn impl_deinit(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.surface.output.display.allocator.destroy(self);
}
