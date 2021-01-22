// Copyright (C) 2015  Davis E. King (davis@dlib.net)
// License: Boost Software License   See LICENSE.txt for the full license.


#include <sstream>
#include <string>
#include <cstdlib>
#include <ctime>
#include <vector>
#include <random>
#include <numeric>
#include "../dnn.h"

#include "tester.h"

#ifndef __INTELLISENSE__

namespace
{

    using namespace test;
    using namespace dlib;
    using namespace std;

    logger dlog("test.dnn");

// ----------------------------------------------------------------------------------------

    template <typename T>
    float compare_gradients (
        const tensor& t,
        T grad
    )
    {
        float max_error = 0;
        auto p = t.host();
        for (size_t i = 0; i < t.size(); ++i)
        {
            max_error = std::max(max_error, std::abs(p[i]-grad(i)));
        }
        return max_error;
    }

    void relu()
    {
#ifdef DLIB_USE_CUDA
        using namespace dlib::tt;
        print_spinner();

        relu_ l;
        auto res= test_layer(l);
        DLIB_TEST_MSG(res, res);

        const long n = 2;
        const long k = 3;
        const long nr = 4;
        const long nc = 5;
        resizable_tensor src(n, k, nr, nc);
        tt::tensor_rand rnd;
        rnd.fill_uniform(src);
        resizable_tensor dest_cuda, dest_cpu;
        dest_cuda.copy_size(src);
        dest_cpu.copy_size(src);
        // initialize to different values in order to make sure the output is actually changed
        dest_cuda = 1;
        dest_cpu = 2;
        cuda::relu(dest_cuda, src);
        cpu::relu(dest_cpu, src);
        DLIB_TEST_MSG(max(abs(mat(dest_cuda) - mat(dest_cpu))) < 1e-7, max(abs(mat(dest_cuda) - mat(dest_cpu))));

        // test gradients
        resizable_tensor grad_cuda, grad_cpu, grad_input;
        grad_cuda.copy_size(src);
        grad_cpu.copy_size(src);
        grad_input.copy_size(src);
        rnd.fill_uniform(grad_input);
        grad_cuda = 1;
        grad_cpu = 2;
        cuda::relu_gradient(grad_cuda, dest_cuda, grad_input);
        cpu::relu_gradient(grad_cpu, dest_cpu, grad_input);
        const auto error = max(abs(mat(grad_cuda) - mat(grad_cpu)));
        DLIB_TEST_MSG(error < 1e-7, "error: " << error);

#endif // DLIB_USE_CUDA
    }
    void test_clipped_relu()
    {
#ifdef DLIB_USE_CUDA
        using namespace dlib::tt;
        print_spinner();

        clipped_relu_ l;
        auto res= test_layer(l);
        DLIB_TEST_MSG(res, res);

        const long n = 2;
        const long k = 3;
        const long nr = 4;
        const long nc = 5;
        const float ceiling = 6.0f;
        resizable_tensor src(n, k, nr, nc);
        tt::tensor_rand rnd;
        rnd.fill_uniform(src);
        resizable_tensor dest_cuda, dest_cpu;
        dest_cuda.copy_size(src);
        dest_cpu.copy_size(src);
        // initialize to different values in order to make sure the output is actually changed
        dest_cuda = 1;
        dest_cpu = 2;
        cuda::clipped_relu(dest_cuda, src, ceiling);
        cpu::clipped_relu(dest_cpu, src, ceiling);
        DLIB_TEST_MSG(max(abs(mat(dest_cuda) - mat(dest_cpu))) < 1e-7, max(abs(mat(dest_cuda) - mat(dest_cpu))));

        // test gradients
        resizable_tensor grad_cuda, grad_cpu, grad_input;
        grad_cuda.copy_size(src);
        grad_cpu.copy_size(src);
        grad_input.copy_size(src);
        rnd.fill_uniform(grad_input);
        grad_cuda = 1;
        grad_cpu = 2;
        cuda::clipped_relu_gradient(grad_cuda, dest_cuda, grad_input, ceiling);
        cpu::clipped_relu_gradient(grad_cpu, dest_cpu, grad_input, ceiling);
        const auto error = max(abs(mat(grad_cuda) - mat(grad_cpu)));
        DLIB_TEST_MSG(error < 1e-7, "error: " << error);

#endif // DLIB_USE_CUDA
    }

    void test_elu()
    {
#ifdef DLIB_USE_CUDA
        using namespace dlib::tt;
        print_spinner();

        elu_ l;
        auto res= test_layer(l);
        DLIB_TEST_MSG(res, res);

        const long n = 2;
        const long k = 3;
        const long nr = 4;
        const long nc = 5;
        const float alpha = 1.0f;
        resizable_tensor src(n, k, nr, nc);
        tt::tensor_rand rnd;
        rnd.fill_uniform(src);
        resizable_tensor dest1, dest2, grad;
        dest1.copy_size(src);
        dest2.copy_size(src);
        grad.copy_size(src);
        rnd.fill_uniform(grad);
        resizable_tensor dest_cuda, dest_cpu;
        dest_cuda.copy_size(src);
        dest_cpu.copy_size(src);
        // initialize to different values in order to make sure the output is actually changed
        dest_cuda = 1;
        dest_cpu = 2;
        cuda::elu(dest_cuda, src, alpha);
        cpu::elu(dest_cpu, src, alpha);
        DLIB_TEST_MSG(max(abs(mat(dest_cuda) - mat(dest_cpu))) < 1e-7, max(abs(mat(dest_cuda) - mat(dest_cpu))));

        // test gradients
        resizable_tensor grad_cuda, grad_cpu, grad_input;
        grad_cuda.copy_size(src);
        grad_cpu.copy_size(src);
        grad_input.copy_size(src);
        rnd.fill_uniform(grad_input);
        grad_cuda = 1;
        grad_cpu = 2;
        cuda::elu_gradient(grad_cuda, dest_cuda, grad_input, alpha);
        cpu::elu_gradient(grad_cpu, dest_cpu, grad_input, alpha);
        const auto error = max(abs(mat(grad_cuda) - mat(grad_cpu)));
        DLIB_TEST_MSG(error < 1e-7, "error: " << error);


#endif // DLIB_USE_CUDA
    }

// ----------------------------------------------------------------------------------------

    class dnn_tester : public tester
    {
    public:
        dnn_tester (
        ) :
            tester ("test_dnn",
                "Runs tests on the deep neural network tools.")
        {}

        void run_tests (
        )
        {
            // make the tests repeatable
            srand(1234);
            test_clipped_relu();
            test_elu();
        }

        void perform_test()
        {
            dlog << LINFO << "NOW RUNNING TESTS WITH set_dnn_prefer_fastest_algorithms()";
            set_dnn_prefer_fastest_algorithms();
            run_tests();

            dlog << LINFO << "NOW RUNNING TESTS WITH set_dnn_prefer_smallest_algorithms()";
            set_dnn_prefer_smallest_algorithms();
            run_tests();


            {
                resizable_tensor a(2,3,4,5);
                resizable_tensor b(2,3,4,5);
                DLIB_TEST(have_same_dimensions(a,b));

                a.set_size(2,3,4,4);
                DLIB_TEST(!have_same_dimensions(a,b));
                a.set_size(2,3,3,5);
                DLIB_TEST(!have_same_dimensions(a,b));
                a.set_size(2,2,4,5);
                DLIB_TEST(!have_same_dimensions(a,b));
                a.set_size(1,3,4,5);
                DLIB_TEST(!have_same_dimensions(a,b));

                static_assert(!is_image_type<resizable_tensor>::value, "should be false");
            }
        }
    } a;
}

#endif // __INTELLISENSE__

