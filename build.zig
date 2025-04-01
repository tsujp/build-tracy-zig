const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tracy_src = b.dependency("tracy_src", .{});

    // Tracy binary utilities at directories:
    // profiler
    // update
    // capture
    // csvexport
    // import

    // https://github.com/wolfpld/tracy/blob/2d9169e3d13f8d6048a8b9fadba40ab56d702527/cmake/server.cmake#L3-L9
    const tracy_common_sources = [_][]const u8{
        "tracy_lz4.cpp",
        "tracy_lz4hc.cpp",
        "TracySocket.cpp",
        "TracyStackFrames.cpp",
        "TracySystem.cpp",
    };

    // https://github.com/wolfpld/tracy/blob/2d9169e3d13f8d6048a8b9fadba40ab56d702527/cmake/server.cmake#L16-L25
    const tracy_server_sources = [_][]const u8{
        "TracyMemory.cpp",
        "TracyMmap.cpp",
        "TracyPrint.cpp",
        "TracySysUtil.cpp",
        "TracyTaskDispatch.cpp",
        "TracyTextureCompression.cpp",
        "TracyThreadCompress.cpp",
        "TracyWorker.cpp",
    };

    const capture_mod = b.createModule(.{
        // Do not use .root_source_file for non-zig files, you'll get a parser error.
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    const cppflags = [_][]const u8{
        "-fexperimental-library",
        // "-DTRACY_ENABLE",
        // "-fno-sanitize=undefined",
    };

    const capstone_dependency = b.dependency("capstone", .{
        .target = target,
        .optimize = optimize,
    });
    // capstone dependency installs capstone headers at ./capstone (rewritten from ./include/capstone) and tracy imports capstone as "capstone.h" so we need the path directly to within the enclosing folder otherwise capstone.h cannot be found.
    capture_mod.addIncludePath(capstone_dependency.artifact("capstone")
        .getEmittedIncludeTree().path(b, "capstone"));
    capture_mod.linkLibrary(capstone_dependency.artifact("capstone"));

    const zstd_dependency = b.dependency("zstd", .{
        .target = target,
        .optimize = optimize,
    });
    capture_mod.linkLibrary(zstd_dependency.artifact("zstd"));

    capture_mod.addCSourceFile(.{
        .file = tracy_src.path("capture/src/capture.cpp"),
        .flags = &cppflags,
    });

    capture_mod.addCSourceFiles(.{
        .root = tracy_src.path("public/common"),
        .files = &tracy_common_sources,
        .flags = &cppflags,
    });

    capture_mod.addCSourceFiles(.{
        .root = tracy_src.path("server"),
        .files = &tracy_server_sources,
        .flags = &cppflags,
    });

    const capture_exe = b.addExecutable(.{
        .name = "tracy-capture",
        .root_module = capture_mod,
    });

    b.installArtifact(capture_exe);
}
