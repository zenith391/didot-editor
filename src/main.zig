const std = @import("std");
const upaya = @import("upaya");
const objects = @import("didot-objects");
const graphics = @import("didot-graphics");

usingnamespace @import("scene.zig");
usingnamespace upaya.imgui;

var propertiesShow: bool = true;
var sceneGraphShow: bool = true;
var scene: ?*objects.Scene = null;
var selectedObject: ?*objects.GameObject = undefined;

fn toggleSceneGraph() void {
    sceneGraphShow = !sceneGraphShow;
}

fn toggleProperties() void {
    propertiesShow = !propertiesShow;
}

pub fn main() !void {
    upaya.run(.{
        .init = init,
        .update = updateUpaya,
        .setupDockLayout = setupDockLayout,
        .docking = true
    });
}

fn init() void {
    var io = igGetIO();
    //var cwd = std.process.getCwdAlloc(upaya.mem.tmp_allocator) catch unreachable;
    //var dupe = upaya.mem.tmp_allocator.dupeZ(u8, cwd) catch unreachable;
    //_ = upaya.filebrowser.openFileDialog("test", dupe, "*");

    objects.initPrimitives();

    scene = loadFrom(upaya.mem.tmp_allocator, @embedFile("../example-scene.json")) catch unreachable;
}

fn onExit() void {
    upaya.quit();
}

fn updateUpaya() void {
    update() catch unreachable;
}

fn update() !void {
    upaya.menu.draw(&[_]upaya.MenuItem{
        .{
            .label = "File",
            .children = &[_]upaya.MenuItem{
                .{ .label = "New" },
                .{ .label = "Load"},
                .{ .label = "Save", .shortcut = "Ctrl+S" },
                .{ .label = "Exit", .action = onExit }
            }
        },
        .{
            .label = "Game",
            .children = &[_]upaya.MenuItem{
                .{ .label = "Run", .shortcut = "F6" }
            }
        },
        .{
            .label = "View",
            .children = &[_]upaya.MenuItem {
                .{ .label = "Scene Graph", .action = toggleSceneGraph },
                .{ .label = "Properties", .action = toggleProperties }
            }
        }
    });

    if (sceneGraphShow) {
        if (igBegin("Scene Graph", null, ImGuiWindowFlags_None)) {
            igText("Objects:");

            if (scene) |scn| {
                for (scn.gameObject.childrens.items) |*obj| {
                    var dupe = try upaya.mem.tmp_allocator.dupeZ(u8, obj.name);
                    defer upaya.mem.tmp_allocator.free(dupe);
                    if (igTreeNodeExStr(dupe, if (obj.childrens.items.len == 0)
                        ImGuiTreeNodeFlags_Leaf
                        else ImGuiTreeNodeFlags_None)) {
                        igTreePop();
                        if (igIsItemClicked(ImGuiMouseButton_Left)) {
                            selectedObject = obj;
                        }
                    }
                }
            }
        }
        igEnd();
    }

    if (propertiesShow) {
        if (igBegin("Properties", null, ImGuiWindowFlags_None)) {
            if (selectedObject) |selected| {
                var buf: [1024]u8 = undefined;
                igText(try std.fmt.bufPrintZ(&buf, "{}", .{selected.name}));
                igText(try std.fmt.bufPrintZ(&buf, "Type: {}", .{selected.objectType}));
                igSeparator();
                igText("Position:");
                var min: f32 = 0.0;
                _ = igDragScalar("Position X", ImGuiDataType_Float, &selected.position.x, 0.005, &min, &min, "%f", 2);
                _ = igDragScalar("Position Y", ImGuiDataType_Float, &selected.position.y, 0.005, &min, &min, "%f", 2);
                _ = igDragScalar("Position Z", ImGuiDataType_Float, &selected.position.z, 0.005, &min, &min, "%f", 2);
                igSpacing();
                igText("Scale:");
                _ = igDragScalar("Scale X", ImGuiDataType_Float, &selected.scale.x, 0.005, &min, &min, "%f", 2);
                _ = igDragScalar("Scale Y", ImGuiDataType_Float, &selected.scale.y, 0.005, &min, &min, "%f", 2);
                _ = igDragScalar("Scale Z", ImGuiDataType_Float, &selected.scale.z, 0.005, &min, &min, "%f", 2);
                igSeparator();
                igTextWrapped(try std.fmt.bufPrintZ(&buf, "Mesh: {}", .{selected.meshPath}));
                igSeparator();
                _ = ogButton("Delete");
            } else {
                igText("Please select a game object.");
            }
        }
        igEnd();
    }

    igPushStyleVarVec2(ImGuiStyleVar_WindowPadding, .{});
    if (igBegin("Game", null, ImGuiWindowFlags_None)) {
        if (scene) |scn| {
            
        } else {
            igText("Please open a scene.");
        }
    }
    igEnd();
    igPopStyleVar(1);

    if (igBegin("Assets", null, ImGuiWindowFlags_None)) {
        igText("Assets: TODO");
    }
    igEnd();

    //igShowDemoWindow(null);
}

fn setupDockLayout(id: ImGuiID) void {
    var left_id = id;
    const right_id = igDockBuilderSplitNode(left_id, ImGuiDir_Right, 0.35, null, &left_id);
    igDockBuilderDockWindow("Properties", right_id);
    igDockBuilderDockWindow("Scene Graph", left_id);
    igDockBuilderFinish(id);
}