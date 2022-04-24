// Copyright (C) 2022  Davis E. King (davis@dlib.net), Martin Sandsmark, Adrià Arrufat
// License: Boost Software License   See LICENSE.txt for the full license.
#ifndef DLIB_WEBP_LOADER_CPp_
#define DLIB_WEBP_LOADER_CPp_

// only do anything with this file if DLIB_WEBP_SUPPORT is defined
#ifdef DLIB_WEBP_SUPPORT

#include "../array2d.h"
#include "../pixel.h"
#include "../dir_nav.h"
#include "webp_loader.h"

#include <webp/decode.h>
#include <webp/demux.h>
#include <fstream>

namespace dlib
{

    static std::vector<unsigned char> load_contents(const std::string& filename)
    {
        std::ifstream stream(filename, std::ios::binary);
        stream.exceptions(std::ifstream::failbit | std::ifstream::badbit | std::ifstream::eofbit);
        stream.seekg(0, std::ios_base::end);
        std::vector<unsigned char> buffer(stream.tellg());
        stream.seekg(0);
        stream.read(reinterpret_cast<char*>(buffer.data()), buffer.size());
        return buffer;
    }

// ----------------------------------------------------------------------------------------

    webp_loader::
    webp_loader(const char* filename) : height_(0), width_(0)
    {
        data_ = load_contents(filename);
        get_info();
    }

// ----------------------------------------------------------------------------------------

    webp_loader::
    webp_loader(const std::string& filename) : height_(0), width_(0)
    {
        data_ = load_contents(filename);
        get_info();
    }

// ----------------------------------------------------------------------------------------

    webp_loader::
    webp_loader(const dlib::file& f) : height_(0), width_(0)
    {
        data_ = load_contents(f.full_name());
        get_info();
    }

// ----------------------------------------------------------------------------------------

    webp_loader::
    webp_loader(const unsigned char* imgbuffer, size_t imgbuffersize) : height_(0), width_(0)
    {
        data_.resize(imgbuffersize);
        memcpy(data_.data(), imgbuffer, imgbuffersize);
        get_info();
    }

// ----------------------------------------------------------------------------------------

    webp_loader::~webp_loader()
    {
        if (demuxer)
            WebPDemuxDelete(reinterpret_cast<WebPDemuxer*>(demuxer));
    }
// ----------------------------------------------------------------------------------------

    void webp_loader::get_info()
    {
        WebPBitstreamFeatures features;
        if (WebPGetFeatures(data_.data(), data_.size(), &features) != VP8_STATUS_OK)
        {
            throw image_load_error("webp_loader: Invalid header");
        }
        width_ = features.width;
        height_ = features.height;
        if (features.has_animation == 1)
        {
            WebPData webp_data {data_.data(), data_.size()};
            demuxer = WebPDemux(&webp_data);
            if (demuxer == nullptr)
                throw image_load_error("webp_loader: decoding demuxer failed");
            num_frames_ = WebPDemuxGetI(reinterpret_cast<WebPDemuxer*>(demuxer), WEBP_FF_FRAME_COUNT);
            // TODO: use the default background color
            const auto bc = WebPDemuxGetI(reinterpret_cast<WebPDemuxer*>(demuxer), WEBP_FF_BACKGROUND_COLOR);
        }
        else
        {
            num_frames_ = 1;
        }
    }

// ----------------------------------------------------------------------------------------

    void webp_loader::read_argb(unsigned char *out, const size_t out_size, const int out_stride) const
    {
        if (num_frames_ == 1)
        {
            if (!WebPDecodeARGBInto(data_.data(), data_.size(), out, out_size, out_stride))
            {
                throw image_load_error("webp_loader: decoding failed");
            }
        }
        else
        {
        }
    }

// ----------------------------------------------------------------------------------------

    void webp_loader::read_rgba(unsigned char *out, const size_t out_size, const int out_stride, int frame_number) const
    {
        if (num_frames_ == 1)
        {
            if(!WebPDecodeRGBAInto(data_.data(), data_.size(), out, out_size, out_stride))
                throw image_load_error("webp_loader: decoding failed");
        }
        else
        {
            std::cerr << "reading WebP animated image\n";
            WebPIterator iter;
            {
                if (WebPDemuxGetFrame(reinterpret_cast<WebPDemuxer*>(demuxer), frame_number + 1, &iter))
                {
                    // WebP frames can have an offset from the top-left corner
                    const auto offset = iter.x_offset * 4 + iter.y_offset * out_stride;
                    if(!WebPDecodeRGBAInto(iter.fragment.bytes,
                                           iter.fragment.size,
                                           out + offset,
                                           out_size - offset,
                                           out_stride))
                        throw image_load_error("webp_loader: decoding failed");
                }
                else
                {
                        throw image_load_error("webp_loader: decoding failed");
                }
            }
            WebPDemuxReleaseIterator(&iter);
        }
    }

// ----------------------------------------------------------------------------------------

    void webp_loader::read_bgra(unsigned char *out, const size_t out_size, const int out_stride) const
    {
        if (num_frames_ == 1)
        {
            if (!WebPDecodeBGRAInto(data_.data(), data_.size(), out, out_size, out_stride))
            {
                throw image_load_error("webp_loader: decoding failed");
            }
        }
        else
        {
        }
    }

// ----------------------------------------------------------------------------------------

    void webp_loader::read_rgb(unsigned char *out, const size_t out_size, const int out_stride) const
    {
        if (num_frames_ == 1)
        {
            if (!WebPDecodeRGBInto(data_.data(), data_.size(), out, out_size, out_stride))
            {
                throw image_load_error("webp_loader: decoding failed");
            }
        }
        else
        {
        }
    }

// ----------------------------------------------------------------------------------------

    void webp_loader::read_bgr(unsigned char *out, const size_t out_size, const int out_stride) const
    {
        if (num_frames_ == 1)
        {
            if (!WebPDecodeBGRInto(data_.data(), data_.size(), out, out_size, out_stride))
            {
                throw image_load_error("webp_loader: decoding failed");
            }
        }
        else
        {
        }
    }

// ----------------------------------------------------------------------------------------

}

#endif // DLIB_WEBP_SUPPORT

#endif // DLIB_WEBP_LOADER_CPp_

