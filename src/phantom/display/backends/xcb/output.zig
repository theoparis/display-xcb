const std = @import("std");
const vizops = @import("vizops");
const phantom = @import("phantom");
const Display = @import("display.zig");
const Surface = @import("surface.zig");
const Self = @This();
const c = @cImport({
    @cInclude("xcb/xcb_image.h");
});

base: phantom.display.Output,
display: *Display,
surface: ?*Surface,
screen: *c.xcb_screen_t,
name: []const u8,
manufacturer: ?[]const u8,
scale: vizops.vector.Float32Vector2,

pub fn new(display: *Display, screen: *c.xcb_screen_t) !*Self {
    const self = try display.allocator.create(Self);
    errdefer display.allocator.destroy(self);

    self.* = .{
        .base = .{
            .ptr = self,
            .vtable = &.{
                .surfaces = impl_surfaces,
                .createSurface = impl_create_surface,
                .info = impl_info,
                .updateInfo = impl_update_info,
                .deinit = impl_deinit,
            },
            .displayKind = display.kind,
            .type = @typeName(Self),
        },
        .display = display,
        .surface = null,
        .screen = screen,
        .name = try std.fmt.allocPrint(display.allocator, "{d}", .{screen.root}),
        .manufacturer = null,
        .scale = vizops.vector.Float32Vector2.init(1.0),
    };
    return self;
}

fn impl_surfaces(ctx: *anyopaque) anyerror!std.ArrayList(*phantom.display.Surface) {
    const self: *Self = @ptrCast(@alignCast(ctx));

    var surfaces = std.ArrayList(*phantom.display.Surface).init(self.display.allocator);
    errdefer surfaces.deinit();

    if (self.surface) |surf| {
        try surfaces.append(&surf.base);
    }

    return surfaces;
}

fn impl_create_surface(ctx: *anyopaque, kind: phantom.display.Surface.Kind, info: phantom.display.Surface.Info) anyerror!*phantom.display.Surface {
    const self: *Self = @ptrCast(@alignCast(ctx));

    if (kind != .output) return error.InvalidKind;
    if (self.surface) |_| return error.AlreadyExists;

    self.surface = try Surface.new(self, info);
    return &self.surface.?.base;
}

fn impl_info(ctx: *anyopaque) anyerror!phantom.display.Output.Info {
    const self: *Self = @ptrCast(@alignCast(ctx));

    var res = vizops.vector.UsizeVector2.zero();

    res.value[0] = @intCast(self.screen.width_in_pixels);
    res.value[1] = @intCast(self.screen.height_in_pixels);

    return .{
        .enable = true,
        .size = .{
            .phys = .{
                .value = .{
                    @floatFromInt(self.screen.width_in_millimeters),
                    @floatFromInt(self.screen.height_in_millimeters),
                },
            },
            .res = res,
        },
        .scale = self.scale,
        .name = self.name,
        .manufacturer = self.manufacturer orelse "Unknown",
        .colorFormat = .{ .rg = @splat(0) },
    };
}

fn impl_update_info(ctx: *anyopaque, info: phantom.display.Output.Info, fields: []std.meta.FieldEnum(phantom.display.Output.Info)) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    _ = self;
    _ = info;
    _ = fields;
    return error.NotImplemented;
}

fn impl_deinit(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.display.allocator.destroy(self);
}
