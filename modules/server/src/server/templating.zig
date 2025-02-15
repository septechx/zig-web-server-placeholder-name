const std = @import("std");
const log = std.log.scoped(.templater);
const lua = @import("lua.zig");

pub fn parse(page: []const u8, path: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    if (!std.mem.endsWith(u8, path, "index.html")) {
        return error.InvalidPath;
    }

    const base_length = path.len - "index.html".len;
    const new_length = base_length - 5 + "server/server.lua".len;

    var lua_path = try allocator.allocSentinel(u8, new_length, 0);
    defer allocator.free(lua_path);

    std.mem.copyForwards(u8, lua_path[0..6], "server");
    std.mem.copyForwards(u8, lua_path[6 .. 6 + base_length - 4], path[4..base_length]);
    std.mem.copyForwards(u8, lua_path[6 + base_length - 4 ..], "server.lua");

    var variables = try lua.getVariables(lua_path, allocator);
    defer variables.deinit();

    var result = try allocator.alloc(u8, 0);

    var iter = std.mem.splitAny(u8, page, "\n");
    while (iter.next()) |line| {
        if (std.mem.containsAtLeast(u8, line, 1, "{") and std.mem.containsAtLeast(u8, line, 1, "}")) {
            const start = std.mem.indexOf(u8, line, "{") orelse continue;
            const end = std.mem.indexOf(u8, line, "}") orelse continue;
            const placeholder = line[start + 1 .. end];
            const value = variables.get(placeholder);

            if (value == null) {
                log.err("Variable to replace not found, requested: {s}", .{placeholder});
                return error.VariableNotFound;
            }

            const no_braces = try allocator.alloc(u8, line.len);
            defer allocator.free(no_braces);

            _ = std.mem.replace(u8, line, "{", "", no_braces);
            _ = std.mem.replace(u8, no_braces[0..no_braces.len], "}", "", no_braces);

            const final_size = value.?.len + no_braces.len - placeholder.len;

            var final_line = try allocator.alloc(u8, final_size);
            defer allocator.free(final_line);

            _ = std.mem.replace(u8, no_braces[0..no_braces.len], placeholder, value.?, final_line);

            result = try appendToBuffer(result, allocator, final_line[0..final_line.len]);
        } else {
            result = try appendToBuffer(result, allocator, line);
        }
    }
    return result;
}
fn appendToBuffer(buffer: []u8, allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const new_len = buffer.len + data.len;
    var new_buffer = try allocator.alloc(u8, new_len);
    std.mem.copyForwards(u8, new_buffer[0..buffer.len], buffer);
    std.mem.copyForwards(u8, new_buffer[buffer.len..new_len], data);
    allocator.free(buffer);
    return new_buffer;
}
