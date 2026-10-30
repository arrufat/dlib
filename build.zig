const std = @import("std");

const dlib_version = @import("build.zig.zon").version;

const cflags = [_][]const u8{
    "-std=c89",
    "-fno-sanitize=undefined",
};

const cppflags = [_][]const u8{
    "-std=c++17",
    "-fno-sanitize=undefined",
};

// tools/python/src/dlib.cpp records __DATE__ and __TIME__, which zig rejects by default.
const python_cppflags = cppflags ++ [_][]const u8{"-Wno-date-time"};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const strip = optimize != .debug;
    const os_tag = target.result.os.tag;
    const is_native = target.query.isNative();

    // X11 and libwebp come from the host system, so they are off by default when cross-compiling.
    const features: Features = .{
        .gui = b.option(bool, "gui", "Build the GUI (X11 on Unix, win32 on Windows)") orelse
            (is_native or os_tag == .windows),
        .webp = b.option(bool, "webp", "Build WebP support against the system libwebp") orelse
            (is_native and os_tag != .windows),
        .cuda = b.option(bool, "cuda", "Build the CUDA/cuDNN backend (needs nvcc and cuDNN)") orelse false,
    };

    const zlib = b.addLibrary(.{
        .name = "z",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = .fast,
            .strip = true,
            .link_libc = true,
        }),
    });
    zlib.root_module.addCSourceFiles(.{
        .root = b.path("dlib/external/zlib"),
        .files = &.{
            "adler32.c",
            "crc32.c",
            "deflate.c",
            "infback.c",
            "inffast.c",
            "inflate.c",
            "inftrees.c",
            "trees.c",
            "zutil.c",
            "compress.c",
            "uncompr.c",
            "gzclose.c",
            "gzlib.c",
            "gzread.c",
            "gzwrite.c",
        },
        .flags = &cflags,
    });
    zlib.installHeader(b.path("dlib/external/zlib/zconf.h"), "zconf.h");
    zlib.installHeader(b.path("dlib/external/zlib/zlib.h"), "zlib.h");
    b.installArtifact(zlib);

    const libpng = b.addLibrary(.{
        .name = "png",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = .fast,
            .strip = true,
            .link_libc = true,
        }),
    });
    libpng.root_module.addCSourceFiles(.{
        .root = b.path("dlib/external/libpng"),
        .files = &.{
            "png.c",
            "pngerror.c",
            "pngget.c",
            "pngmem.c",
            "pngpread.c",
            "pngread.c",
            "pngrio.c",
            "pngrtran.c",
            "pngrutil.c",
            "pngset.c",
            "pngtrans.c",
            "pngwio.c",
            "pngwrite.c",
            "pngwtran.c",
            "pngwutil.c",
        },
        .flags = &cflags,
    });
    if (target.result.cpu.arch.isArm() or target.result.cpu.arch.isAARCH64()) {
        libpng.root_module.addCSourceFiles(.{
            .root = b.path("dlib/external/libpng"),
            .files = &.{
                "arm/arm_init.c",
                "arm/filter_neon_intrinsics.c",
                "arm/palette_neon_intrinsics.c",
            },
            .flags = &cflags,
        });
    }
    libpng.root_module.linkLibrary(zlib);
    libpng.installHeader(b.path("dlib/external/libpng/pnglibconf.h"), "pnglibconf.h");
    libpng.installHeader(b.path("dlib/external/libpng/pngconf.h"), "pngconf.h");
    libpng.installHeader(b.path("dlib/external/libpng/png.h"), "png.h");
    b.installArtifact(libpng);

    const libjpeg = b.addLibrary(.{
        .name = "jpeg",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = .fast,
            .strip = true,
            .link_libc = true,
        }),
    });
    libjpeg.root_module.addCSourceFiles(.{
        .root = b.path("dlib/external/libjpeg"),
        .files = &.{
            "jaricom.c",
            "jcapimin.c",
            "jcapistd.c",
            "jcarith.c",
            "jccoefct.c",
            "jccolor.c",
            "jcdctmgr.c",
            "jchuff.c",
            "jcinit.c",
            "jcmainct.c",
            "jcmarker.c",
            "jcmaster.c",
            "jcomapi.c",
            "jcparam.c",
            "jcprepct.c",
            "jcsample.c",
            "jdapimin.c",
            "jdapistd.c",
            "jdarith.c",
            "jdatadst.c",
            "jdatasrc.c",
            "jdcoefct.c",
            "jdcolor.c",
            "jddctmgr.c",
            "jdhuff.c",
            "jdinput.c",
            "jdmainct.c",
            "jdmarker.c",
            "jdmaster.c",
            "jdmerge.c",
            "jdpostct.c",
            "jdsample.c",
            "jerror.c",
            "jfdctflt.c",
            "jfdctfst.c",
            "jfdctint.c",
            "jidctflt.c",
            "jidctfst.c",
            "jidctint.c",
            "jmemmgr.c",
            "jmemnobs.c",
            "jquant1.c",
            "jquant2.c",
            "jutils.c",
        },
        .flags = &cflags,
    });
    libjpeg.installHeader(b.path("dlib/external/libjpeg/jconfig.h"), "jconfig.h");
    libjpeg.installHeader(b.path("dlib/external/libjpeg/jmorecfg.h"), "jmorecfg.h");
    libjpeg.installHeader(b.path("dlib/external/libjpeg/jpeglib.h"), "jpeglib.h");
    b.installArtifact(libjpeg);

    const dlib = b.addLibrary(.{
        .name = "dlib",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .strip = strip,
            .link_libcpp = true,
            .pic = true,
        }),
    });
    dlib.root_module.addCSourceFiles(.{
        .root = b.path("dlib"),
        .files = &.{
            "base64/base64_kernel_1.cpp",
            "bigint/bigint_kernel_1.cpp",
            "bigint/bigint_kernel_2.cpp",
            "bit_stream/bit_stream_kernel_1.cpp",
            "entropy_decoder/entropy_decoder_kernel_1.cpp",
            "entropy_decoder/entropy_decoder_kernel_2.cpp",
            "entropy_encoder/entropy_encoder_kernel_1.cpp",
            "entropy_encoder/entropy_encoder_kernel_2.cpp",
            "md5/md5_kernel_1.cpp",
            "tokenizer/tokenizer_kernel_1.cpp",
            "unicode/unicode.cpp",
            "test_for_odr_violations.cpp",
            "fft/fft.cpp",
            "sockets/sockets_kernel_1.cpp",
            "bsp/bsp.cpp",
            "dir_nav/dir_nav_kernel_1.cpp",
            "dir_nav/dir_nav_kernel_2.cpp",
            "dir_nav/dir_nav_extensions.cpp",
            "linker/linker_kernel_1.cpp",
            "logger/extra_logger_headers.cpp",
            "logger/logger_kernel_1.cpp",
            "logger/logger_config_file.cpp",
            "misc_api/misc_api_kernel_1.cpp",
            "misc_api/misc_api_kernel_2.cpp",
            "sockets/sockets_extensions.cpp",
            "sockets/sockets_kernel_2.cpp",
            "sockstreambuf/sockstreambuf.cpp",
            "sockstreambuf/sockstreambuf_unbuffered.cpp",
            "server/server_kernel.cpp",
            "server/server_iostream.cpp",
            "server/server_http.cpp",
            "threads/multithreaded_object_extension.cpp",
            "threads/threaded_object_extension.cpp",
            "threads/threads_kernel_1.cpp",
            "threads/threads_kernel_2.cpp",
            "threads/threads_kernel_shared.cpp",
            "threads/thread_pool_extension.cpp",
            "threads/async.cpp",
            "timer/timer.cpp",
            "stack_trace.cpp",
            "image_loader/png_loader.cpp",
            "image_saver/save_png.cpp",
            "image_loader/jpeg_loader.cpp",
            "image_saver/save_jpeg.cpp",
            "gui_widgets/fonts.cpp",
            "cuda/cpu_dlib.cpp",
            "cuda/tensor_tools.cpp",
            "data_io/image_dataset_metadata.cpp",
            "data_io/mnist.cpp",
            "data_io/cifar.cpp",
            "svm/auto.cpp",
            "global_optimization/global_function_search.cpp",
            "filtering/kalman_filter.cpp",
        },
        .flags = &cppflags,
    });
    if (features.gui) {
        dlib.root_module.addCSourceFiles(.{
            .root = b.path("dlib"),
            .files = &.{
                "gui_widgets/widgets.cpp",
                "gui_widgets/drawable.cpp",
                "gui_widgets/canvas_drawing.cpp",
                "gui_widgets/style.cpp",
                "gui_widgets/base_widgets.cpp",
                "gui_core/gui_core_kernel_1.cpp",
                "gui_core/gui_core_kernel_2.cpp",
            },
            .flags = &cppflags,
        });
    }
    if (features.webp) {
        dlib.root_module.addCSourceFiles(.{
            .root = b.path("dlib"),
            .files = &.{
                "image_loader/webp_loader.cpp",
                "image_saver/save_webp.cpp",
            },
            .flags = &cppflags,
        });
        dlib.root_module.linkSystemLibrary("libwebp", .{});
    }
    addDlibMacros(dlib.root_module, features);
    dlib.root_module.addCMacro("DLIB_JPEG_STATIC", "");
    // nvcc reuses dlib's macros, so this has to come after them.
    const cuda_lib_dir = if (features.cuda) addCuda(b, dlib, optimize) else null;
    dlib.root_module.linkLibrary(libpng);
    dlib.root_module.linkLibrary(libjpeg);
    if (os_tag == .windows) {
        dlib.root_module.linkSystemLibrary("ws2_32", .{});
        dlib.root_module.linkSystemLibrary("winmm", .{});
        if (features.gui) {
            dlib.root_module.linkSystemLibrary("comctl32", .{});
            dlib.root_module.linkSystemLibrary("gdi32", .{});
            dlib.root_module.linkSystemLibrary("imm32", .{});
        }
    } else {
        dlib.root_module.linkSystemLibrary("pthread", .{});
        if (features.gui) dlib.root_module.linkSystemLibrary("X11", .{});
    }
    dlib.installHeadersDirectory(b.path("dlib"), "dlib", .{});
    b.installArtifact(dlib);
    const dlib_link: DlibLink = .{ .lib = dlib, .features = features, .cuda_lib_dir = cuda_lib_dir };

    const examples = [_]struct { []const u8, bool }{
        .{ "assignment_learning_ex", false },
        .{ "max_cost_assignment_ex", false },
        .{ "image_ex", true },
    };

    for (examples) |entry| {
        const example, const needs_gui = entry;
        if (needs_gui and !features.gui) continue;
        const exe = b.addExecutable(.{
            .name = example,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .strip = strip,
                .link_libcpp = true,
            }),
        });
        exe.root_module.addCSourceFile(.{
            .file = b.path(b.fmt("examples/{s}.cpp", .{example})),
            .flags = &cppflags,
        });
        dlib_link.link(exe.root_module);
        b.installArtifact(exe);
    }

    buildPythonModule(b, target, optimize, strip, dlib_link);
}

fn buildPythonModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.Optimize,
    strip: bool,
    dlib: DlibLink,
) void {
    const os_tag = target.result.os.tag;
    const is_native = target.query.isNative();

    const step = b.step("python", "Build the _dlib_pybind11 Python extension module");

    const include_option = b.option(
        std.Build.LazyPath,
        "python-include",
        "Python headers for the target (default: from the host Python)",
    );
    const ext_suffix_option = b.option(
        []const u8,
        "python-ext-suffix",
        "Extension module suffix, e.g. .cpython-314-x86_64-linux-gnu.so (default: from the host Python for native builds)",
    );
    const import_lib_option = b.option(
        std.Build.LazyPath,
        "python-lib",
        "Python import library (python3XX.lib) for Windows targets (default: from the host Python for native builds)",
    );

    // build.zig runs before the requested step is known, so a missing Python
    // must only fail `zig build python`, not the rest of the build.
    const needs_host = include_option == null or (is_native and
        (ext_suffix_option == null or (os_tag == .windows and import_lib_option == null)));
    const host = if (needs_host) queryHostPython(b) else null;
    if (needs_host and host == null) {
        step.dependOn(&b.addFail("could not run python3 or python to locate the Python headers; " ++
            "install Python or pass -Dpython-include").step);
        return;
    }

    const include_dir = include_option orelse std.Build.LazyPath{ .cwd_relative = host.?.include };
    // Python also accepts a bare ".so"/".pyd", which is the safe choice when the
    // host interpreter does not describe the target.
    const ext_suffix = ext_suffix_option orelse if (is_native)
        host.?.ext_suffix
    else if (os_tag == .windows) ".pyd" else ".so";
    const import_lib = import_lib_option orelse if (os_tag == .windows and is_native)
        std.Build.LazyPath{ .cwd_relative = host.?.import_lib }
    else
        null;

    const module = b.addLibrary(.{
        .name = "_dlib_pybind11",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .strip = strip,
            .link_libcpp = true,
        }),
    });
    module.root_module.addSystemIncludePath(include_dir);
    module.root_module.addIncludePath(b.path("dlib/external/pybind11/include"));
    module.root_module.addCSourceFiles(.{
        .root = b.path("tools/python/src"),
        .files = &.{
            "dlib.cpp",
            "matrix.cpp",
            "vector.cpp",
            "svm_c_trainer.cpp",
            "svm_rank_trainer.cpp",
            "decision_functions.cpp",
            "other.cpp",
            "basic.cpp",
            "cca.cpp",
            "sequence_segmenter.cpp",
            "svm_struct.cpp",
            "image.cpp",
            "image2.cpp",
            "image3.cpp",
            "image4.cpp",
            "rectangles.cpp",
            "object_detection.cpp",
            "shape_predictor.cpp",
            "correlation_tracker.cpp",
            "face_recognition.cpp",
            "cnn_face_detector.cpp",
            "global_optimization.cpp",
            "image_dataset_metadata.cpp",
            "numpy_returns.cpp",
            "line.cpp",
        },
        .flags = &python_cppflags,
    });
    if (dlib.features.gui) {
        module.root_module.addCSourceFile(.{
            .file = b.path("tools/python/src/gui.cpp"),
            .flags = &python_cppflags,
        });
    }
    dlib.link(module.root_module);
    module.root_module.addCMacro("DLIB_VERSION", dlib_version);
    module.root_module.addCMacro("DLIB_NO_ABORT_ON_2ND_FATAL_ERROR", "");

    // libpython symbols are resolved by the interpreter that loads the module,
    // except on Windows, where the module must link the import library.
    switch (os_tag) {
        .windows => if (import_lib) |lib| {
            module.root_module.addObjectFile(lib);
            // pyconfig.h only defines this for MSVC, but zig targets the GNU ABI.
            if (target.result.ptrBitWidth() == 64) module.root_module.addCMacro("MS_WIN64", "");
        } else {
            module.step.dependOn(&b.addFail("-Dpython-lib is required when targeting Windows").step);
        },
        .macos => module.linker_allow_shlib_undefined = true,
        else => {},
    }

    const install = b.addInstallArtifact(module, .{
        .dest_dir = .{ .override = .lib },
        .dest_sub_path = b.fmt("_dlib_pybind11{s}", .{ext_suffix}),
        .implib_dir = .disabled,
        .dylib_symlinks = false,
    });
    step.dependOn(&install.step);
}

const HostPython = struct {
    include: []const u8,
    ext_suffix: []const u8,
    import_lib: []const u8,
};

fn queryHostPython(b: *std.Build) ?HostPython {
    const script =
        \\import os, sys, sysconfig
        \\print(sysconfig.get_paths()["include"])
        \\print(sysconfig.get_config_var("EXT_SUFFIX"))
        \\print(os.path.join(sys.base_prefix, "libs", "python%d%d.lib" % sys.version_info[:2]))
    ;
    // Windows installs usually provide `python` but not `python3`.
    for ([_][]const u8{ "python3", "python" }) |exe| {
        var exit_code: u8 = undefined;
        const out = b.runAllowFail(&.{ exe, "-c", script }, &exit_code, .ignore) catch continue;
        var lines = std.mem.tokenizeAny(u8, out, "\r\n");
        const host: HostPython = .{
            .include = lines.next() orelse continue,
            .ext_suffix = lines.next() orelse continue,
            .import_lib = lines.next() orelse continue,
        };
        // zig caches the configure phase, so tie it to the Python version to
        // pick up upgrades.
        b.dependOnFileContents(.{ .cwd_relative = b.pathJoin(&.{ host.include, "patchlevel.h" }) });
        return host;
    }
    // Nothing to track; re-run configure until Python shows up.
    b.graph.poisonCache();
    return null;
}

fn addCuda(b: *std.Build, dlib: *std.Build.Step.Compile, optimize: std.builtin.Optimize) std.Build.LazyPath {
    const cuda_path = b.option(
        std.Build.LazyPath,
        "cuda-path",
        "CUDA toolkit root (default: from nvcc in /usr/local/cuda, /opt/cuda or PATH)",
    ) orelse b.findProgramLazy(.{
        .names = &.{ "/usr/local/cuda/bin/nvcc", "/opt/cuda/bin/nvcc", "nvcc" },
    }).dirname().dirname();
    const cuda_arch = b.option(
        []const u8,
        "cuda-arch",
        "GPU architectures for nvcc -arch, e.g. sm_75, all-major (default: native)",
    ) orelse "native";
    const cuda_lib = cuda_path.path(b, "lib64");

    // nvcc hands the host side of .cu files to a separate C++ compiler. Using
    // zig's clang keeps it on the same libc++ as the rest of dlib, so the
    // objects can share std types with the .cpp files.
    const make_ccbin = b.addSystemCommand(&.{
        "sh", "-c",
        \\printf '#!/bin/sh\nexec "%s" c++ "$@"\n' "$1" > "$0" && chmod +x "$0"
    });
    const ccbin = make_ccbin.addOutputFileArg("clang++");
    make_ccbin.addArg(b.graph.zig_exe);
    const host_flags = std.mem.join(b.allocator, ",", &(cppflags ++ .{"-fPIC"})) catch @panic("OOM");

    for ([_][]const u8{ "cuda_dlib.cu", "cusolver_dlibapi.cu" }) |source| {
        const nvcc = std.Build.Step.Run.create(b, b.fmt("nvcc {s}", .{source}));
        nvcc.addFileArg(cuda_path.path(b, "bin/nvcc"));
        nvcc.addPrefixedFileArg("-ccbin=", ccbin);
        nvcc.addArgs(&.{
            // nvcc only knows released clang versions.
            "-allow-unsupported-compiler",
            "-std=c++17",
            b.fmt("-arch={s}", .{cuda_arch}),
            b.fmt("-Xcompiler={s}", .{host_flags}),
            if (optimize == .debug) "-g" else "-O3",
        });
        nvcc.addArgs(dlib.root_module.c_macros.items);
        nvcc.addArgs(&.{ "-MD", "-c" });
        _ = nvcc.addPrefixedDepFileOutputArg("-MF=", "deps.d");
        nvcc.addFileArg(b.path(b.fmt("dlib/cuda/{s}", .{source})));
        nvcc.addArg("-o");
        dlib.root_module.addObjectFile(nvcc.addOutputFileArg(b.fmt("{s}.o", .{source})));
    }

    dlib.root_module.addCSourceFiles(.{
        .root = b.path("dlib/cuda"),
        .files = &.{
            "cudnn_dlibapi.cpp",
            "cublas_dlibapi.cpp",
            "curand_dlibapi.cpp",
            "cuda_data_ptr.cpp",
            "gpu_data.cpp",
        },
        .flags = &cppflags,
    });
    dlib.root_module.addSystemIncludePath(cuda_path.path(b, "include"));
    dlib.root_module.addLibraryPath(cuda_lib);
    for ([_][]const u8{ "cudart", "cublas", "cudnn", "curand", "cusolver" }) |lib|
        dlib.root_module.linkSystemLibrary(lib, .{ .use_pkg_config = .no });
    return cuda_lib;
}

/// What a module needs to build against and link with dlib.
const DlibLink = struct {
    lib: *std.Build.Step.Compile,
    features: Features,
    /// The library path of a static lib doesn't reach the final link, so
    /// consumers have to add it to find the CUDA libraries.
    cuda_lib_dir: ?std.Build.LazyPath,

    fn link(dlib: DlibLink, module: *std.Build.Module) void {
        addDlibMacros(module, dlib.features);
        module.linkLibrary(dlib.lib);
        if (dlib.cuda_lib_dir) |dir| {
            module.addLibraryPath(dir);
            module.addRPath(dir);
        }
    }
};

const Features = struct {
    gui: bool,
    webp: bool,
    cuda: bool,
};

/// Macros that must match between dlib and anything that links against it,
/// otherwise test_for_odr_violations reports a mismatch at link time.
fn addDlibMacros(module: *std.Build.Module, features: Features) void {
    module.addCMacro("DLIB_PNG_SUPPORT", "1");
    module.addCMacro("DLIB_JPEG_SUPPORT", "1");
    if (features.webp) module.addCMacro("DLIB_WEBP_SUPPORT", "1");
    if (!features.gui) module.addCMacro("DLIB_NO_GUI_SUPPORT", "1");
    if (features.cuda) module.addCMacro("DLIB_USE_CUDA", "1");
    module.addCMacro("DLIB_ENABLE_ASSERTS", "1");
    module.addCMacro("DLIB_ENABLE_STACK_TRACE", "1");
}
