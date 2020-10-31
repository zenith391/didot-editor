const std = @import("std");
const objects = @import("didot-objects");
const zlm = @import("zlm");
const Allocator = std.mem.Allocator;

fn to_f32(value: std.json.Value) f32 {
    return switch (value) {
        .Float => |float| @floatCast(f32, float),
        .Integer => |int| @intToFloat(f32, int),
        else => unreachable
    };
}

fn to_vec3(array: []std.json.Value) zlm.Vec3 {
    return zlm.vec3(to_f32(array[0]), to_f32(array[1]), to_f32(array[2]));
}

pub fn loadFrom(allocator: *Allocator, text: []const u8) !*objects.Scene {
    var scene = try objects.Scene.create(allocator, null);

    var p = std.json.Parser.init(allocator, false);
    defer p.deinit();

    var tree = try p.parse(text);
    defer tree.deinit();
    var root = tree.root;
    var objectsJs = root.Object.get("objects").?.Array;

    for (objectsJs.items) |obj, i| {
        var go = objects.GameObject.createEmpty(allocator);
        go.name = obj.Object.get("name").?.String;
        go.objectType = obj.Object.get("type").?.String;
        if (obj.Object.get("mesh")) |mesh| {
            go.meshPath = mesh.String;
        }

        go.position = to_vec3(obj.Object.get("position").?.Array.items);
        go.rotation = to_vec3(obj.Object.get("rotation").?.Array.items);
        go.scale = to_vec3(obj.Object.get("scale").?.Array.items);
        try scene.add(go);
    }

    return scene;
}
