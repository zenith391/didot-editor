const std = @import("std");
const upaya = @import("upaya");
const zlm = @import("zlm");
const objects = @import("didot-objects");
const graphics = @import("didot-graphics");

usingnamespace @import("scene.zig");
usingnamespace upaya.imgui;
usingnamespace @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
});

var propertiesShow: bool = true;
var sceneGraphShow: bool = true;
var scene: ?*objects.Scene = null;
var selectedObject: ?*objects.GameObject = undefined;
var gp: std.heap.GeneralPurposeAllocator(.{}) = .{};
var allocator = &gp.allocator;

var fbo: GLuint = undefined;
var renderTexture: GLuint = undefined;

var render_texture: upaya.sokol.sg_image = undefined;

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
        .docking = true,
    });
}

fn init() void {
    var io = igGetIO();
    //var cwd = std.process.getCwdAlloc(upaya.mem.tmp_allocator) catch unreachable;
    //var dupe = upaya.mem.tmp_allocator.dupeZ(u8, cwd) catch unreachable;
    //_ = upaya.filebrowser.openFileDialog("test", dupe, "*");

    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);

    glGenTextures(1, &renderTexture);
    glBindTexture(GL_TEXTURE_2D, renderTexture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, 800, 600, 0, GL_RGB, GL_UNSIGNED_BYTE, null);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glBindTexture(GL_TEXTURE_2D, 0);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, renderTexture, 0);

    var rbo: GLuint = undefined;
    glGenRenderbuffers(1, &rbo);
    glBindRenderbuffer(GL_RENDERBUFFER, rbo);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, 800, 600);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, rbo);

    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        std.debug.warn("framebuffer error\n", .{});
    }
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    scene = loadFrom(allocator, @embedFile("../example-scene.json")) catch unreachable;
    objects.initPrimitives();
    scene.?.assetManager.put("Meshes/Primitives/Cube", .{
        .objectPtr = @ptrToInt(&objects.PrimitiveCubeMesh),
        .unloadable = false,
        .objectType = .Mesh
    }) catch unreachable;
    scene.?.assetManager.put("Meshes/Primitives/Plane", .{
        .objectPtr = @ptrToInt(&objects.PrimitivePlaneMesh),
        .unloadable = false,
        .objectType = .Mesh
    }) catch unreachable;

    var img_desc = std.mem.zeroes(upaya.sokol.sg_image_desc);
    img_desc.render_target = true;
    img_desc.width = 800;
    img_desc.height = 600;
    img_desc.pixel_format = .SG_PIXELFORMAT_RGBA8;
    img_desc.min_filter = .SG_FILTER_LINEAR;
    img_desc.mag_filter = .SG_FILTER_LINEAR;
    img_desc.gl_textures[0] = renderTexture;

    render_texture = upaya.sokol.sg_make_image(&img_desc);
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

    //igPushStyleVarVec2(ImGuiStyleVar_WindowPadding, .{});
    if (igBegin("Game", null, ImGuiWindowFlags_None)) {
        if (scene) |scn| {
            glBindFramebuffer(GL_FRAMEBUFFER, fbo);
            var program: GLint = undefined;
            glGetIntegerv(GL_CURRENT_PROGRAM, &program);
            try scn.renderOffscreen(zlm.vec4(0, 0, 800, 600));
            glUseProgram(@bitCast(c_uint, program));
            glBindFramebuffer(GL_FRAMEBUFFER, 0);
            const err = glGetError();
            if (err != 0) {
                std.debug.warn("gl error: {}\n", .{err});
            }

            ogImage(@intToPtr(*c_void, render_texture.id), 800, 600);
        } else {
            igText("Please open a scene.");
        }
    }
    igEnd();
    //igPopStyleVar(1);

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