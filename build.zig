const std = @import("std");
const builtin = @import("builtin");

// TODO: (?) if a tracy debug build and on linux add compile option: -fno-eliminate-unused-debug-types
// TODO: (?) tracy vendor force options to set: https://github.com/wolfpld/tracy/blob/2d9169e3d13f8d6048a8b9fadba40ab56d702527/cmake/vendor.cmake

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = .ReleaseFast;

    const tracy_src = b.dependency("tracy_src", .{});

    const capstone_dep = b.dependency("capstone", .{
        .target = target,
        .optimize = optimize,
    });
    // capstone dependency installs capstone headers at ./capstone (rewritten from ./include/capstone) and tracy imports capstone as "capstone.h" so we need the path directly to within the enclosing folder otherwise capstone.h cannot be found.
    const capstone_headers = capstone_dep.artifact("capstone")
        .getEmittedIncludeTree().path(b, "capstone");
    const capstone_artifact = capstone_dep.artifact("capstone");

    const zstd_dep = b.dependency("zstd", .{
        .target = target,
        .optimize = optimize,
    });
    const zstd_artifact = zstd_dep.artifact("zstd");

    const cpp_flags = [_][]const u8{
        // "-Wall",      "-Werror", "-Wpedantic",
        "-std=c++20",
        "-fexperimental-library",
        // "-DTRACY_ENABLE",
        // "-fno-sanitize=undefined",
    };

    // Tracy binary utilities at directories: profiler, update, capture, csvexport, import

    // TODO: profiler

    //
    // ////////////////// update
    const update_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    update_mod.addIncludePath(capstone_headers);
    update_mod.linkLibrary(capstone_artifact);
    update_mod.linkLibrary(zstd_artifact);

    update_mod.addCSourceFiles(.{
        .root = tracy_src.path("update"),
        .files = &.{
            "src/update.cpp",
            "src/OfflineSymbolResolver.cpp",
            "src/OfflineSymbolResolverAddr2Line.cpp",
            "src/OfflineSymbolResolverDbgHelper.cpp",
        },
        .flags = &cpp_flags,
    });

    update_mod.addCSourceFiles(.{
        .root = tracy_src.path("public/common"),
        .files = &tracy_common_sources,
        .flags = &cpp_flags,
    });

    update_mod.addCSourceFiles(.{
        .root = tracy_src.path("server"),
        .files = &tracy_server_sources,
        .flags = &cpp_flags,
    });

    const update_exe = b.addExecutable(.{
        .name = "tracy-update",
        .root_module = update_mod,
    });

    b.installArtifact(update_exe);

    //
    // ////////////////// capture
    const capture_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    capture_mod.addIncludePath(capstone_headers);
    capture_mod.linkLibrary(capstone_artifact);
    capture_mod.linkLibrary(zstd_artifact);

    capture_mod.addCSourceFile(.{
        .file = tracy_src.path("capture/src/capture.cpp"),
        .flags = &cpp_flags,
    });

    capture_mod.addCSourceFiles(.{
        .root = tracy_src.path("public/common"),
        .files = &tracy_common_sources,
        .flags = &cpp_flags,
    });

    capture_mod.addCSourceFiles(.{
        .root = tracy_src.path("server"),
        .files = &tracy_server_sources,
        .flags = &cpp_flags,
    });

    const capture_exe = b.addExecutable(.{
        .name = "tracy-capture",
        .root_module = capture_mod,
    });

    b.installArtifact(capture_exe);

    // TODO: csvexport, import
}

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
