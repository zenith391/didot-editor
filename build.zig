const std = @import("std");
const Builder = std.build.Builder;
const upaya_build = @import("zig-upaya/src/build.zig");
const didot_build = @import("didot/build.zig");

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("didot-editor", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addPackagePath("zig-upaya/", "");
    upaya_build.linkArtifact(b, exe, target);
    try didot_build.addEngineToExe(exe, .{
        .prefix = "didot/"
    });
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
