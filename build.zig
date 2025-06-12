const std = @import("std");

fn linkSystemLibraries(
    exe: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    use_webp: bool,
    use_jxl: bool,
    use_ffmpeg: bool,
) void {
    // Link standard system libraries (not Windows)
    if (target.result.os.tag != .windows) {
        exe.linkSystemLibrary("pthread");
        exe.linkSystemLibrary("X11");
    }

    // Link optional system libraries based on integration flags
    if (use_webp) {
        exe.linkSystemLibrary("libwebp");
    }

    if (use_jxl) {
        exe.linkSystemLibrary("jxl");
        exe.linkSystemLibrary("jxl_cms");
        exe.linkSystemLibrary("jxl_threads");
    }

    if (use_ffmpeg) {
        exe.linkSystemLibrary("avdevice");
        exe.linkSystemLibrary("avfilter");
        exe.linkSystemLibrary("avformat");
        exe.linkSystemLibrary("avcodec");
        exe.linkSystemLibrary("swresample");
        exe.linkSystemLibrary("swscale");
        exe.linkSystemLibrary("avutil");
    }

    // Link default image libraries
    exe.linkSystemLibrary("png");
    exe.linkSystemLibrary("jpeg");
}

fn addOption(
    b: *std.Build,
    module: *std.Build.Step.Compile,
    name: []const u8,
    description: []const u8,
    T: type,
    default_value: T,
) void {
    const opt = b.option(T, name, b.fmt("{s} (default: {})", .{ description, default_value })) orelse default_value;
    const macro_value = switch (T) {
        bool => if (opt) "1" else "0",
        void => "",
        []const u8 => default_value,
        else => @compileError("option of type " ++ @typeName(@TypeOf(T)) ++ " not supported"),
    };
    if (T != void or macro_value.len > 0) {
        module.root_module.addCMacro(name, macro_value);
    }
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const strip = optimize != .Debug;
    const cflags = [_][]const u8{
        "-std=c89",
        "-fno-sanitize=undefined",
    };
    const cppflags = [_][]const u8{
        "-std=c++14",
        "-fPIC",
        "-fno-sanitize=undefined",
    };

    const dlib = b.addLibrary(.{
        .name = "dlib",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .strip = strip,
        }),
    });
    dlib.linkLibCpp();
    dlib.addCSourceFiles(.{ .files = &.{
        "dlib/base64/base64_kernel_1.cpp",
        "dlib/bigint/bigint_kernel_1.cpp",
        "dlib/bigint/bigint_kernel_2.cpp",
        "dlib/bit_stream/bit_stream_kernel_1.cpp",
        "dlib/entropy_decoder/entropy_decoder_kernel_1.cpp",
        "dlib/entropy_decoder/entropy_decoder_kernel_2.cpp",
        "dlib/entropy_encoder/entropy_encoder_kernel_1.cpp",
        "dlib/entropy_encoder/entropy_encoder_kernel_2.cpp",
        "dlib/md5/md5_kernel_1.cpp",
        "dlib/tokenizer/tokenizer_kernel_1.cpp",
        "dlib/unicode/unicode.cpp",
        "dlib/test_for_odr_violations.cpp",
        "dlib/sockets/sockets_kernel_1.cpp",
        "dlib/bsp/bsp.cpp",
        "dlib/dir_nav/dir_nav_kernel_1.cpp",
        "dlib/dir_nav/dir_nav_kernel_2.cpp",
        "dlib/dir_nav/dir_nav_extensions.cpp",
        "dlib/linker/linker_kernel_1.cpp",
        "dlib/logger/extra_logger_headers.cpp",
        "dlib/logger/logger_kernel_1.cpp",
        "dlib/logger/logger_config_file.cpp",
        "dlib/misc_api/misc_api_kernel_1.cpp",
        "dlib/misc_api/misc_api_kernel_2.cpp",
        "dlib/sockets/sockets_extensions.cpp",
        "dlib/sockets/sockets_kernel_2.cpp",
        "dlib/sockstreambuf/sockstreambuf.cpp",
        "dlib/sockstreambuf/sockstreambuf_unbuffered.cpp",
        "dlib/server/server_kernel.cpp",
        "dlib/server/server_iostream.cpp",
        "dlib/server/server_http.cpp",
        "dlib/threads/multithreaded_object_extension.cpp",
        "dlib/threads/threaded_object_extension.cpp",
        "dlib/threads/threads_kernel_1.cpp",
        "dlib/threads/threads_kernel_2.cpp",
        "dlib/threads/threads_kernel_shared.cpp",
        "dlib/threads/thread_pool_extension.cpp",
        "dlib/threads/async.cpp",
        "dlib/timer/timer.cpp",
        "dlib/stack_trace.cpp",
        "dlib/image_loader/png_loader.cpp",
        "dlib/image_saver/save_png.cpp",
        "dlib/image_loader/jpeg_loader.cpp",
        "dlib/image_saver/save_jpeg.cpp",
        "dlib/image_loader/jpeg_loader.cpp",
        "dlib/image_saver/save_jpeg.cpp",
        "dlib/gui_widgets/fonts.cpp",
        "dlib/gui_widgets/widgets.cpp",
        "dlib/gui_widgets/drawable.cpp",
        "dlib/gui_widgets/canvas_drawing.cpp",
        "dlib/gui_widgets/style.cpp",
        "dlib/gui_widgets/base_widgets.cpp",
        "dlib/gui_core/gui_core_kernel_1.cpp",
        "dlib/gui_core/gui_core_kernel_2.cpp",
        "dlib/cuda/cpu_dlib.cpp",
        "dlib/cuda/tensor_tools.cpp",
        "dlib/data_io/image_dataset_metadata.cpp",
        "dlib/data_io/mnist.cpp",
        "dlib/data_io/cifar.cpp",
        "dlib/svm/auto.cpp",
        "dlib/global_optimization/global_function_search.cpp",
        "dlib/filtering/kalman_filter.cpp",
    }, .flags = &cppflags });

    // Options
    addOption(b, dlib, "DLIB_PNG_SUPPORT", "Enable PNG support via libpng", bool, true);
    addOption(b, dlib, "DLIB_JPEG_SUPPORT", "Enable JPEG support via libjpeg", bool, true);
    addOption(b, dlib, "DLIB_ENABLE_ASSERTS", "Enable to turn one the DLIB_ASSERT macro", bool, false);
    addOption(b, dlib, "DLIB_ENABLE_STACK_TRACE", "Enable to turn one the DLIB_STACK_TRACE macros", bool, false);
    addOption(b, dlib, "USE_AVX_INSTRUCTIONS", "Turn on AVX instructions", bool, true);
    addOption(b, dlib, "USE_SS2_INSTRUCTIONS", "Turn on SS2 instructions", bool, true);
    addOption(b, dlib, "USE_SS4_INSTRUCTIONS", "Turn on SS4 instructions", bool, true);

    dlib.installHeadersDirectory(b.path("dlib"), "dlib", .{});
    b.installArtifact(dlib);

    // System integrations (conditional compilation only)
    const use_webp = b.systemIntegrationOption("webp", .{});
    if (use_webp) {
        dlib.root_module.addCMacro("DLIB_WEBP_SUPPORT", "1");
        dlib.addCSourceFiles(.{ .files = &.{
            "dlib/image_loader/webp_loader.cpp",
            "dlib/image_saver/save_webp.cpp",
        }, .flags = &cppflags });
    }

    const use_jxl = b.systemIntegrationOption("jxl", .{});
    if (use_jxl) {
        dlib.root_module.addCMacro("DLIB_JXL_SUPPORT", "1");
        dlib.addCSourceFiles(.{ .files = &.{
            "dlib/image_loader/jxl_loader.cpp",
            "dlib/image_saver/save_jxl.cpp",
        }, .flags = &cppflags });
    }

    const use_ffmpeg = b.systemIntegrationOption("ffmpeg", .{});
    if (use_ffmpeg) {
        dlib.root_module.addCMacro("DLIB_USE_FFMPEG", "");
    }

    if (!b.systemIntegrationOption("png", .{ .default = true })) {
        const zlib = b.addLibrary(.{
            .name = "z",
            .linkage = .static,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .strip = strip,
            }),
        });
        zlib.linkLibC();
        zlib.addCSourceFiles(.{ .files = &.{
            "dlib/external/zlib/adler32.c",
            "dlib/external/zlib/crc32.c",
            "dlib/external/zlib/deflate.c",
            "dlib/external/zlib/infback.c",
            "dlib/external/zlib/inffast.c",
            "dlib/external/zlib/inflate.c",
            "dlib/external/zlib/inftrees.c",
            "dlib/external/zlib/trees.c",
            "dlib/external/zlib/zutil.c",
            "dlib/external/zlib/compress.c",
            "dlib/external/zlib/uncompr.c",
            "dlib/external/zlib/gzclose.c",
            "dlib/external/zlib/gzlib.c",
            "dlib/external/zlib/gzread.c",
            "dlib/external/zlib/gzwrite.c",
        }, .flags = &cflags });
        zlib.installHeader(b.path("dlib/external/zlib/zconf.h"), "zconf.h");
        zlib.installHeader(b.path("dlib/external/zlib/zlib.h"), "zlib.h");
        b.installArtifact(zlib);

        const libpng = b.addLibrary(.{
            .name = "png",
            .linkage = .static,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .strip = strip,
            }),
        });
        libpng.linkLibC();
        libpng.addCSourceFiles(.{ .files = &.{
            "dlib/external/libpng/arm/arm_init.c",
            "dlib/external/libpng/arm/filter_neon_intrinsics.c",
            "dlib/external/libpng/arm/palette_neon_intrinsics.c",
            "dlib/external/libpng/png.c",
            "dlib/external/libpng/pngerror.c",
            "dlib/external/libpng/pngget.c",
            "dlib/external/libpng/pngmem.c",
            "dlib/external/libpng/pngpread.c",
            "dlib/external/libpng/pngread.c",
            "dlib/external/libpng/pngrio.c",
            "dlib/external/libpng/pngrtran.c",
            "dlib/external/libpng/pngrutil.c",
            "dlib/external/libpng/pngset.c",
            "dlib/external/libpng/pngtrans.c",
            "dlib/external/libpng/pngwio.c",
            "dlib/external/libpng/pngwrite.c",
            "dlib/external/libpng/pngwtran.c",
            "dlib/external/libpng/pngwutil.c",
        }, .flags = &cflags });
        libpng.linkLibrary(zlib);
        libpng.installHeader(b.path("dlib/external/libpng/pnglibconf.h"), "pnglibconf.h");
        libpng.installHeader(b.path("dlib/external/libpng/pngconf.h"), "pngconf.h");
        libpng.installHeader(b.path("dlib/external/libpng/png.h"), "png.h");
        libpng.installHeader(b.path("dlib/external/libpng/png.h"), "png.h");
        b.installArtifact(libpng);
        dlib.linkLibrary(libpng);
    }

    if (!b.systemIntegrationOption("jpeg", .{ .default = true })) {
        dlib.root_module.addCMacro("DLIB_JPEG_STATIC", "");
        const libjpeg = b.addLibrary(.{
            .name = "jpeg",
            .linkage = .static,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .strip = strip,
            }),
        });
        libjpeg.linkLibC();
        libjpeg.addCSourceFiles(.{ .files = &.{
            "dlib/external/libjpeg/jaricom.c",
            "dlib/external/libjpeg/jcapimin.c",
            "dlib/external/libjpeg/jcapistd.c",
            "dlib/external/libjpeg/jcarith.c",
            "dlib/external/libjpeg/jccoefct.c",
            "dlib/external/libjpeg/jccolor.c",
            "dlib/external/libjpeg/jcdctmgr.c",
            "dlib/external/libjpeg/jchuff.c",
            "dlib/external/libjpeg/jcinit.c",
            "dlib/external/libjpeg/jcmainct.c",
            "dlib/external/libjpeg/jcmarker.c",
            "dlib/external/libjpeg/jcmaster.c",
            "dlib/external/libjpeg/jcomapi.c",
            "dlib/external/libjpeg/jcparam.c",
            "dlib/external/libjpeg/jcprepct.c",
            "dlib/external/libjpeg/jcsample.c",
            "dlib/external/libjpeg/jdapimin.c",
            "dlib/external/libjpeg/jdapistd.c",
            "dlib/external/libjpeg/jdarith.c",
            "dlib/external/libjpeg/jdatadst.c",
            "dlib/external/libjpeg/jdatasrc.c",
            "dlib/external/libjpeg/jdcoefct.c",
            "dlib/external/libjpeg/jdcolor.c",
            "dlib/external/libjpeg/jddctmgr.c",
            "dlib/external/libjpeg/jdhuff.c",
            "dlib/external/libjpeg/jdinput.c",
            "dlib/external/libjpeg/jdmainct.c",
            "dlib/external/libjpeg/jdmarker.c",
            "dlib/external/libjpeg/jdmaster.c",
            "dlib/external/libjpeg/jdmerge.c",
            "dlib/external/libjpeg/jdpostct.c",
            "dlib/external/libjpeg/jdsample.c",
            "dlib/external/libjpeg/jerror.c",
            "dlib/external/libjpeg/jfdctflt.c",
            "dlib/external/libjpeg/jfdctfst.c",
            "dlib/external/libjpeg/jfdctint.c",
            "dlib/external/libjpeg/jidctflt.c",
            "dlib/external/libjpeg/jidctfst.c",
            "dlib/external/libjpeg/jidctint.c",
            "dlib/external/libjpeg/jmemmgr.c",
            "dlib/external/libjpeg/jmemnobs.c",
            "dlib/external/libjpeg/jquant1.c",
            "dlib/external/libjpeg/jquant2.c",
            "dlib/external/libjpeg/jutils.c",
        }, .flags = &cflags });
        libjpeg.installHeader(b.path("dlib/external/libjpeg/jconfig.h"), "jconfig.h");
        libjpeg.installHeader(b.path("dlib/external/libjpeg/jmorecfg.h"), "jmorecfg.h");
        libjpeg.installHeader(b.path("dlib/external/libjpeg/jpeglib.h"), "jpeglib.h");
        b.installArtifact(libjpeg);
        dlib.linkLibrary(libjpeg);
    }

    const examples = [_][]const u8{
        "assignment_learning_ex",
        "max_cost_assignment_ex",
        "image_ex",
    };

    for (examples) |example| {
        const exe = b.addExecutable(.{
            .name = example,
            .target = target,
            .optimize = optimize,
            .strip = strip,
        });
        exe.addCSourceFile(.{
            .file = b.path(b.fmt("examples/{s}.cpp", .{example})),
            .flags = &cppflags,
        });
        exe.linkLibCpp();
        exe.linkLibrary(dlib);

        // Link system libraries required by dlib
        linkSystemLibraries(exe, target, use_webp, use_jxl, use_ffmpeg);

        exe.root_module.addCMacro("DLIB_PNG_SUPPORT", "1");
        exe.root_module.addCMacro("DLIB_JPEG_SUPPORT", "1");
        if (use_webp) exe.root_module.addCMacro("DLIB_WEBP_SUPPORT", "1");
        if (use_jxl) exe.root_module.addCMacro("DLIB_JXL_SUPPORT", "1");
        exe.root_module.addCMacro("DLIB_ENABLE_ASSERTS", "1");
        exe.root_module.addCMacro("DLIB_ENABLE_STACK_TRACE", "1");
        exe.root_module.strip = strip;
        b.installArtifact(exe);
    }

    if (b.systemIntegrationOption("python", .{ .default = false })) {
        const pybind11 = b.addLibrary(.{
            .name = "pybind11",
            .linkage = .dynamic,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
            }),
        });
        const pybind11flags = [_][]const u8{
            "-std=c++14",
            "-fPIC",
            "-fno-sanitize=undefined",
            "-fvisibility=hidden",
            "-flto",
            "-fno-fat-lto-objects",
            "-fvisibility=hidden",
            "-fvisibility-inlines-hidden",
        };
        pybind11.root_module.strip = strip;
        pybind11.addCSourceFiles(.{ .files = &.{
            "tools/python/src/dlib.cpp",
            "tools/python/src/matrix.cpp",
            "tools/python/src/vector.cpp",
            "tools/python/src/svm_c_trainer.cpp",
            "tools/python/src/svm_rank_trainer.cpp",
            "tools/python/src/decision_functions.cpp",
            "tools/python/src/other.cpp",
            "tools/python/src/basic.cpp",
            "tools/python/src/cca.cpp",
            "tools/python/src/sequence_segmenter.cpp",
            "tools/python/src/svm_struct.cpp",
            "tools/python/src/image.cpp",
            "tools/python/src/image2.cpp",
            "tools/python/src/image3.cpp",
            "tools/python/src/image4.cpp",
            "tools/python/src/rectangles.cpp",
            "tools/python/src/object_detection.cpp",
            "tools/python/src/shape_predictor.cpp",
            "tools/python/src/correlation_tracker.cpp",
            "tools/python/src/face_recognition.cpp",
            "tools/python/src/cnn_face_detector.cpp",
            "tools/python/src/global_optimization.cpp",
            "tools/python/src/image_dataset_metadata.cpp",
            "tools/python/src/numpy_returns.cpp",
            "tools/python/src/line.cpp",
        }, .flags = &pybind11flags });
        pybind11.addIncludePath(b.path("dlib/external/pybind11/include"));
        pybind11.linkLibCpp();
        pybind11.linkLibrary(dlib);

        // Link system libraries required by dlib and Python
        linkSystemLibraries(pybind11, target, use_webp, use_jxl, use_ffmpeg);
        pybind11.linkSystemLibrary("python3");

        pybind11.root_module.addCMacro("PYBIND11_PYTHON_VERSION", "3.10");
        pybind11.root_module.addCMacro("_dlib_pybind11_EXPORTS", "1");
        pybind11.root_module.addCMacro("PYBIND11_PYTHONLIBS_OVERWRITE", "");
        pybind11.root_module.addCMacro("DLIB_VERSION", "19.24.99");
        pybind11.root_module.addCMacro("DLIB_PNG_SUPPORT", "1");
        pybind11.root_module.addCMacro("DLIB_JPEG_SUPPORT", "1");
        pybind11.root_module.addCMacro("DLIB_NO_GUI_SUPPORT", "1");
        pybind11.root_module.addCMacro("DLIB_NO_ABORT_ON_2ND_FATAL_ERROR", "");
        b.installArtifact(pybind11);
    }
}
