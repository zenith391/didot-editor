const std = @import("std");
const objects = @import("didot-objects");
const models = @import("didot-models");
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
    var assetsJs = root.Object.get("assets").?.Object;

    var assetsIterator = assetsJs.iterator();
    while (assetsIterator.next()) |entry| {
        const assetJs = entry.value;
        if (assetJs.Object.contains("mesh")) {
            const mesh = assetJs.Object.get("mesh").?.Object;
            const path = mesh.get("path").?.String;
            const format = mesh.get("format").?.String;
            try scene.assetManager.put(entry.key, .{
                .loader = models.meshAssetLoader,
                .loaderData = try models.MeshAssetLoaderData.init(allocator, path, format),
                .objectType = .Mesh,
            });
        }
    }

    for (objectsJs.items) |obj, i| {
        const objectType = obj.Object.get("type").?.String;
        var go: objects.GameObject = undefined;

        if (std.mem.eql(u8, objectType, "camera")) {
            var shader = try @import("didot-graphics").ShaderProgram.create(@embedFile("../assets/shaders/vert.glsl"), @embedFile("../assets/shaders/frag.glsl"));
            var camera = try objects.Camera.create(allocator, shader);
            go = camera.gameObject;
        } else if (std.mem.eql(u8, objectType, "point_light")) {
            var pointLight = try objects.PointLight.create(allocator);
            go = pointLight.gameObject;
        } else {
            go = objects.GameObject.createEmpty(allocator);
        }
        go.name = obj.Object.get("name").?.String;

        if (obj.Object.get("mesh")) |mesh| {
            go.meshPath = mesh.String;
        }

        go.position = to_vec3(obj.Object.get("position").?.Array.items);
        go.rotation = to_vec3(obj.Object.get("rotation").?.Array.items).toRadians();
        go.scale = to_vec3(obj.Object.get("scale").?.Array.items);
        try scene.add(go);
    }

    return scene;
}
