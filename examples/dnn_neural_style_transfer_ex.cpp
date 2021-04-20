// The contents of this file are in the public domain. See LICENSE_FOR_EXAMPLE_PROGRAMS.txt
/*
    This is an example illustrating the use of the deep learning tools from the dlib C++
    Library.  I'm assuming you have already read the dnn_introduction_ex.cpp, the
    dnn_introduction2_ex.cpp and the dnn_introduction3_ex.cpp examples.
*/

// #include "resnet.h"
#include "weights_visitor.h"

#include <dlib/dnn.h>
#include <dlib/gui_widgets.h>
#include <dlib/image_io.h>
#include <iostream>

using namespace std;
using namespace dlib;

template <long num_filters, typename SUBNET>
using rcon = relu<add_layer<con_<num_filters, 3, 3, 1, 1, 1, 1>, SUBNET>>;

template <long num_filters, typename SUBNET>
using con3 = add_layer<con_<num_filters, 3, 3, 1, 1, 1, 1>, SUBNET>;

template <typename SUBNET> using rcon_64 = rcon<64, SUBNET>;
template <typename SUBNET> using rcon_128 = rcon<128, SUBNET>;
template <typename SUBNET> using rcon_256 = rcon<256, SUBNET>;
template <typename SUBNET> using rcon_512 = rcon<512, SUBNET>;

// using vgg16_type = loss_multiclass_log<
//             fc<1000, relu<fc<4096, relu<fc<4096,
//             max_pool<2, 2, 2, 2, rcon_512<rcon_512<rcon_512<
//             max_pool<2, 2, 2, 2, rcon_512<rcon_512<rcon_512<
//             max_pool<2, 2, 2, 2, rcon_256<rcon_256<rcon_256<
//             max_pool<2, 2, 2, 2, rcon_128<rcon_128<
//             max_pool<2, 2, 2, 2, rcon_64<rcon_64<
//             tag1<input_rgb_image>>>>>>>>>>>>>>>>>>>>>>>>>;

using vgg_backbone = tag1<con3<512, relu<con3<512, relu<con3<512,
            max_pool<2, 2, 2, 2, relu<tag2<con3<512, relu<con3<512, relu<con3<512,
            max_pool<2, 2, 2, 2, relu<tag3<con3<256, relu<con3<256, relu<con3<256,
            max_pool<2, 2, 2, 2, relu<tag4<con3<128, relu<con3<128,
            max_pool<2, 2, 2, 2, relu<tag5<con3<64, relu<con3<64,
            tag6<input_rgb_image>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>;

using vgg16_type = loss_multiclass_log<fc<1000, relu<fc<4096, relu<fc<4096, max_pool<2, 2, 2, 2, relu<vgg_backbone>>>>>>>>;


// An overload to be able to print the tensor sizes easily
std::ostream& operator<<(std::ostream& out, const tensor& t)
{
    out << t.num_samples() << 'x' << t.k() << 'x' << t.nr() << 'x' << t.nc();
    return out;
}

// reshape tensor: inspired from: https://github.com/davisking/dlib/blob/master/dlib/dnn/layers.h#L3495
auto reshape(const tensor& t) -> resizable_tensor
{
    DLIB_CASSERT(t.num_samples() == 1, "input tensor must have only one sample");
    alias_tensor a_out(1, 1, t.k(), t.nr() * t.nc());
    resizable_tensor out = a_out(t).get();
    return out;
}

// using net_type = loss_mean_squared_per_channel_and_pixel<
//     2048,
//     resnet::def<affine>::backbone_50<input_rgb_image>>;

template <typename net_type>
std::vector<resizable_tensor> extract_features(net_type& net, const matrix<rgb_pixel>& image)
{
    std::vector<resizable_tensor> features;
    net(image);
    features.push_back(layer<tag1>(net).get_output());
    features.push_back(layer<tag2>(net).get_output());
    features.push_back(layer<tag3>(net).get_output());
    features.push_back(layer<tag4>(net).get_output());
    features.push_back(layer<tag5>(net).get_output());
    return features;
}

int main(int argc, char** argv)
try
{
    vgg16_type vgg;
    // Darknet models don't substract the mean to input images, so we set that up accordingly.
    input_layer(vgg) = input_rgb_image(0, 0, 0);
    // Also, darknet disables bias for convolutions followed by batch normalization layers.
    // In this case, there are no batch normalization layers, so this function call will do nothing.
    disable_duplicative_biases(vgg);
    // We need to forward a dummy image to allocate the weights of the network.
    matrix<rgb_pixel> image;
    load_image(image, "./elephant.jpg");
    cout << vgg(image) << endl;
    // Finally, load the Darknet weights into our network.
    visit_layers_backwards(vgg, darknet::weights_visitor("./vgg-16.weights"));
    // Let's try the network with a real image
    vgg(image);
    cout << vgg << endl;
    matrix<float> probs = soft_max(mat((vgg.subnet().get_output())));
    cout << index_of_max(probs) << " " << probs(index_of_max(probs)) << endl;
    vgg.clean();
    // serialize("vgg-16.dnn") << vgg;
    // deserialize("./vgg-16.dnn") >> vgg;

    using net_type = loss_multiclass_log_per_pixel<vgg_backbone>;
    net_type net;
    net.subnet() = layer<8>(vgg).subnet();

    matrix<rgb_pixel> content, style, target;
    dlib::load_image(content, "davis.png");
    dlib::load_image(target, "nulhom.png");
    style.set_size(content.nr(), content.nc());
    dlib::resize_image(target, style);
    target = content;
    net(content);
    cout << net << endl;
    // image_window win;
    // win.set_image(join_rows(content, style));

    std::vector<adam> solvers(net.num_computational_layers, adam(0, 0.5, 0.999));

    for (size_t i = 0; i < 2000; ++i)
    {
        // double style_loss = 0.;
        double content_loss = 0.;

        const auto target_features = extract_features(net, target);
        const auto content_features = extract_features(net, content);
        const auto style_features = extract_features(net, style);
        resizable_tensor diff_tensor, square_tensor;

        for (size_t f = 0; f < target_features.size(); ++f)
        {
            double partial_loss = 0;
            diff_tensor = target_features[f];
            tt::add(1, diff_tensor, -1, content_features[f]);
            square_tensor.copy_size(diff_tensor);
            tt::multiply(false, square_tensor, diff_tensor, diff_tensor);
            for (const auto& i : square_tensor)
            {
                partial_loss += i;
            }
            content_loss += partial_loss / square_tensor.size();

            std::cout << "content :" << content_features[f] << '\n';
            std::cout << "target :" << target_features[f] << '\n';
            std::cout << "style :" << style_features[f] << '\n';
            const auto target_feature = reshape(target_features[f]);
            const auto style_feature = reshape(style_features[f]);
            std::cout << "reshaped target: " << target_feature << '\n';
            std::cout << "reshaped style: " << style_feature << '\n';

            resizable_tensor target_gramm(target_feature.num_samples(), target_feature.k(), target_feature.nr(), target_feature.nr());
            resizable_tensor style_gramm(style_feature.num_samples(), style_feature.k(), style_feature.nr(), style_feature.nr());
            std::cout << "target gramm: " << target_gramm<< '\n';
            std::cout << "style gramm: " << style_gramm << '\n';

			// tt::gemm(0, target_gramm, 1, target_feature, false, target_feature, true);
			// cout << "done\n";
			// cin.get();
			// tt::gemm(0, style_gramm, 1, style_feature, false, style_feature, true);
			// cout << "done\n";
			// cin.get();

            // const matrix<float> target_feature = image_plane(reshape(target_features[f]));
            // const matrix<float> content_feature = image_plane(reshape(content_features[f]));
            // const matrix<float> style_feature = image_plane(reshape(style_features[f]));

            // const matrix<float> target_gramm = target_plane * trans(target_plane);
            // const matrix<float> style_gramm = style_plane * trans(style_plane);
            // const matrix<float> diff = style_gramm - target_gramm;
            // const matrix<float> temp = diff * scale;
            // style_loss += mean(squared(diff)) * scale;
            // resizable_tensor input(1, 1, style_gramm.nr(), style_gramm.nc());
            // input.set_sample(0, style_gramm);
            // resizable_tensor grad(1, 1, temp.nr(), temp.nc());
            // grad.set_sample(0, temp);
            // net.back_propagate_error(style_features[f], grad);
            // std::cout << "style_loss: " << style_loss << '\n';
        }
        std::cout << "content_loss: " << content_loss << '\n';
        std::cin.get();
    }

    net(content);
    // std::cout << net << '\n';
    // const auto& out_4 = layer<3>(net).get_output();
    // const auto& out_3 = layer<39>(net).get_output();
    // const auto& out_2 = layer<108>(net).get_output();
    // const auto& out_1 = layer<155>(net).get_output();
    // std::cout << out_4 << '\n';
    // std::cout << out_3 << '\n';
    // std::cout << out_2 << '\n';
    // std::cout << out_1 << '\n';

    return EXIT_SUCCESS;
}
catch (const serialization_error& e)
{
    cout << e.what() << endl;
    cout << "You need to download a copy of the file resnet50_1000_imagenet_classifier.dnn" << endl;
    cout << "available at http://dlib.net/files/resnet50_1000_imagenet_classifier.dnn.bz2" << endl;
    cout << endl;
    return EXIT_FAILURE;
}
catch (const exception& e)
{
    cout << e.what() << endl;
    return EXIT_FAILURE;
}
