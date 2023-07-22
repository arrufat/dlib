const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zlib = b.addStaticLibrary(.{
        .name = "z",
        .target = target,
        .optimize = optimize,
    });
    zlib.linkLibC();
    zlib.addCSourceFiles(&.{
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
    }, &.{"-std=c89"});
    zlib.installHeader("dlib/external/zlib/zconf.h", "zconf.h");
    zlib.installHeader("dlib/external/zlib/zlib.h", "zlib.h");
    b.installArtifact(zlib);

    const libpng = b.addStaticLibrary(.{
        .name = "png",
        .target = target,
        .optimize = optimize,
    });
    libpng.linkLibC();
    libpng.addCSourceFiles(&.{
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
    }, &.{"-std=c89"});
    libpng.linkLibrary(zlib);
    libpng.installHeader("dlib/external/libpng/pnglibconf.h", "pnglibconf.h");
    libpng.installHeader("dlib/external/libpng/pngconf.h", "pngconf.h");
    libpng.installHeader("dlib/external/libpng/png.h", "png.h");
    libpng.installHeader("dlib/external/libpng/png.h", "png.h");
    b.installArtifact(libpng);

    const libjpeg = b.addStaticLibrary(.{
        .name = "jpeg",
        .target = target,
        .optimize = optimize,
    });
    libjpeg.linkLibC();
    libjpeg.addCSourceFiles(&.{
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
    }, &.{"-std=c89"});
    libjpeg.installHeader("dlib/external/libjpeg/jconfig.h", "jconfig.h");
    libjpeg.installHeader("dlib/external/libjpeg/jmorecfg.h", "jmorecfg.h");
    libjpeg.installHeader("dlib/external/libjpeg/jpeglib.h", "jpeglib.h");
    b.installArtifact(libjpeg);

    const dlib = b.addStaticLibrary(.{
        .name = "dlib",
        .target = target,
        .optimize = optimize,
    });
    dlib.linkLibCpp();
    dlib.addCSourceFiles(&.{
        // "dlib/all/source.cpp",
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
    }, &.{
        "-std=c++14",
        "-DDLIB_PNG_SUPPORT=1",
        "-DDLIB_JPEG_SUPPORT=1",
    });
    dlib.installHeadersDirectory("dlib", "dlib");
    dlib.linkLibrary(libpng);
    dlib.linkLibrary(libjpeg);
    dlib.linkSystemLibrary("pthread");
    dlib.linkSystemLibrary("X11");

    b.installArtifact(dlib);
}
