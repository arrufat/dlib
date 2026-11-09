// Copyright (C) 2026  Davis E. King (davis@dlib.net)
// License: Boost Software License   See LICENSE.txt for the full license.

#include <dlib/svm.h>
#include <dlib/rand.h>
#include <cmath>
#include <map>
#include <vector>

#include "tester.h"

namespace
{
    using namespace test;
    using namespace dlib;
    using namespace std;

    logger dlog("test.auto_train_linear_classifier");

    using sparse_type = std::vector<std::pair<unsigned long,double>>;
    using dense_type = matrix<double,0,1>;

// ----------------------------------------------------------------------------------------

    // An unbalanced problem: num_pos positives and 100 - num_pos negatives that overlap
    // a little.
    template <typename sample_type>
    void make_problem(std::vector<sample_type>& x, std::vector<double>& y, const int num_pos = 20)
    {
        dlib::rand rnd;
        for (int i = 0; i < 100; ++i)
        {
            const double label = i < num_pos ? +1 : -1;
            const double a = label + rnd.get_random_gaussian();
            const double b = rnd.get_random_gaussian();
            if constexpr (is_matrix<sample_type>::value)
                x.push_back({a, b});
            else
                x.push_back({{0, a}, {1, b}});
            y.push_back(label);
        }
    }

    // Returns the power of 10 C, between 1e-6 and 1e6, with which a class-balanced
    // svm_c_linear_dcd_trainer gives df, or 0 if none does.
    template <typename kernel_type, typename sample_type>
    double find_c (
        const decision_function<kernel_type>& df,
        const std::vector<sample_type>& x,
        const std::vector<double>& y
    )
    {
        const double num_pos = sum(mat(y) > 0);
        const double num_neg = y.size() - num_pos;
        for (int e = -6; e <= 6; ++e)
        {
            const double c = std::pow(10.0, e);
            svm_c_linear_dcd_trainer<kernel_type> by_hand;
            by_hand.set_c_class1(c*y.size()/(2*num_pos));
            by_hand.set_c_class2(c*y.size()/(2*num_neg));
            const auto expected = by_hand.train(x, y);
            if (max(abs(sparse_to_dense(df.basis_vectors(0)) - sparse_to_dense(expected.basis_vectors(0)))) < 1e-9 &&
                std::abs(df.b - expected.b) < 1e-9)
            {
                return c;
            }
        }
        return 0;
    }

// ----------------------------------------------------------------------------------------

    void test_sparse()
    {
        std::vector<sparse_type> x;
        std::vector<double> y;
        make_problem(x, y);

        const auto df = auto_train_linear_classifier(x, y, false);
        DLIB_TEST(df(sparse_type{{0, 3.0}}) > 0.9);
        DLIB_TEST(df(sparse_type{{0, -3.0}}) < 0.1);

        // The SVM inside is a class-balanced SVM trained on all the samples with a power
        // of 10 C.
        const double c = find_c(df.decision_funct, x, y);
        dlog << LINFO << "chosen C: " << c;
        DLIB_TEST(c != 0);

        // The same data gives the same result.
        const auto df2 = auto_train_linear_classifier(x, y, false);
        DLIB_TEST(df2.alpha == df.alpha && df2.beta == df.beta);
        DLIB_TEST(df2.decision_funct.b == df.decision_funct.b);

        // A view of selected samples gives the same result as a copy of them.
        std::vector<long> rows;
        std::vector<sparse_type> copy_x;
        std::vector<double> copy_y;
        for (long i = 0; i < 100; i += 2)
        {
            rows.push_back(i);
            copy_x.push_back(x[i]);
            copy_y.push_back(y[i]);
        }
        const auto df_view = auto_train_linear_classifier(rowm(mat(x), mat(rows)), rowm(mat(y), mat(rows)), false);
        const auto df_copy = auto_train_linear_classifier(copy_x, copy_y, false);
        DLIB_TEST(df_view.alpha == df_copy.alpha && df_view.beta == df_copy.beta);
        DLIB_TEST(df_view.decision_funct.b == df_copy.decision_funct.b);
    }

// ----------------------------------------------------------------------------------------

    void test_rare_positives()
    {
        // 20 positives among 400 sparse samples of noise words, the positives also holding
        // a few words of their own.  Strong regularization still gets the sign of the held
        // out scores right on both classes, but ranks them worse, so it must not be chosen.
        dlib::rand rnd;
        std::vector<sparse_type> x;
        std::vector<double> y;
        for (int i = 0; i < 400; ++i)
        {
            const double label = i < 20 ? +1 : -1;
            std::map<unsigned long,double> words;
            for (int k = 0; k < 20; ++k)
                words[10 + rnd.get_random_32bit_number()%1000] = 1;
            if (label > 0)
            {
                for (int k = 0; k < 3; ++k)
                    words[rnd.get_random_32bit_number()%10] = 1;
            }
            x.emplace_back(words.begin(), words.end());
            for (auto& word : x.back())
                word.second /= std::sqrt(static_cast<double>(words.size()));
            y.push_back(label);
        }
        const auto df = auto_train_linear_classifier(x, y, false);
        const double c = find_c(df.decision_funct, x, y);
        dlog << LINFO << "chosen C: " << c;
        DLIB_TEST(c >= 1);
    }

// ----------------------------------------------------------------------------------------

    void test_search()
    {
        // The best C for make_problem() is below the initial 0.1, 1 and 10.
        std::vector<sparse_type> x;
        std::vector<double> y;
        make_problem(x, y);
        const double c = find_c(auto_train_linear_classifier(x, y, false).decision_funct, x, y);
        dlog << LINFO << "chosen C: " << c;
        DLIB_TEST(c < 0.1);

        // With features 1000 times smaller, the scores shrink, but the sigmoid rescales them.
        for (auto& sample : x)
        {
            for (auto& feature : sample)
                feature.second *= 1e-3;
        }
        const auto df = auto_train_linear_classifier(x, y, false);
        DLIB_TEST(df(sparse_type{{0, 3e-3}}) > 0.9);
        DLIB_TEST(df(sparse_type{{0, -3e-3}}) < 0.1);
    }

// ----------------------------------------------------------------------------------------

    void test_dense()
    {
        std::vector<dense_type> x;
        std::vector<double> y;
        make_problem(x, y, 30);

        const auto df = auto_train_linear_classifier(x, y, false);
        DLIB_TEST(df(dense_type{3.0, 0.0}) > 0.9);
        DLIB_TEST(df(dense_type{-3.0, 0.0}) < 0.1);
    }

// ----------------------------------------------------------------------------------------

    class test_auto_train_linear_classifier : public tester
    {
    public:
        test_auto_train_linear_classifier (
        ) :
            tester ("test_auto_train_linear_classifier",
                    "Runs tests on auto_train_linear_classifier().")
        {}

        void perform_test (
        )
        {
            test_sparse();
            print_spinner();
            test_rare_positives();
            print_spinner();
            test_search();
            print_spinner();
            test_dense();
        }
    } a;

}
