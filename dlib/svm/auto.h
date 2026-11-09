// Copyright (C) 2018  Davis E. King (davis@dlib.net)
// License: Boost Software License   See LICENSE.txt for the full license.
#ifndef DLIB_AUTO_LEARnING_Hh_
#define DLIB_AUTO_LEARnING_Hh_

#include "auto_abstract.h"
#include "../algs.h"
#include "function.h"
#include "kernel.h"
#include "svm_multiclass_linear_trainer.h"
#include "cross_validate_multiclass_trainer.h"
#include "svm_c_linear_dcd_trainer.h"
#include "sparse_kernel.h"
#include "svm.h"
#include <chrono>
#include <cmath>
#include <iostream>
#include <numeric>
#include <type_traits>
#include <utility>
#include <vector>

namespace dlib
{

    normalized_function<decision_function<radial_basis_kernel<matrix<double,0,1>>>> auto_train_rbf_classifier (
        std::vector<matrix<double,0,1>> x,
        std::vector<double> y,
        const std::chrono::nanoseconds max_runtime,
        bool be_verbose = true
    );

// ----------------------------------------------------------------------------------------

    namespace impl
    {
        // The type of the samples in samples_type, a container that mat() accepts.
        template <typename samples_type>
        using auto_sample_type =
            typename std::decay_t<decltype(dlib::mat(std::declval<const samples_type&>()))>::type;

        template <typename samples_type>
        using auto_linear_kernel = std::conditional_t<is_matrix<auto_sample_type<samples_type>>::value,
                                                      linear_kernel<auto_sample_type<samples_type>>,
                                                      sparse_linear_kernel<auto_sample_type<samples_type>>>;
    }

    template <
        typename samples_type,
        typename labels_type
        >
    probabilistic_decision_function<impl::auto_linear_kernel<samples_type>> auto_train_linear_classifier (
        const samples_type& samples,
        const labels_type& labels,
        bool be_verbose = true
    )
    {
        using kernel_type = impl::auto_linear_kernel<samples_type>;
        constexpr long num_folds = 5;

        const auto& x = mat(samples);
        const auto& y = mat(labels);
        DLIB_CASSERT(is_binary_classification_problem(samples, labels),
            "\t auto_train_linear_classifier()"
            << "\n\t invalid inputs were given to this function"
            << "\n\t x.size(): " << x.size()
            << "\n\t y.size(): " << y.size()
        );
        DLIB_CASSERT(sum(y > 0) >= num_folds && sum(y < 0) >= num_folds,
            "You must provide at least " << num_folds << " examples of each class to this training routine.");

        // Trains a linear SVM with the C of each class scaled by n/(2*n_class).
        const auto train_svm = [](const auto& train_x, const auto& train_y, const double c)
        {
            const double num_pos = sum(train_y > 0);
            const double num_neg = train_y.size() - num_pos;
            svm_c_linear_dcd_trainer<kernel_type> trainer;
            trainer.set_c_class1(c * train_y.size() / (2 * num_pos));
            trainer.set_c_class2(c * train_y.size() / (2 * num_neg));
            return trainer.train(train_x, train_y);
        };

        // The folds are dealt here, not by cross_validate_trainer(), since the loss needs
        // every sample's held out score.  fold[i] is the fold that holds out sample i.  Each class's shuffled samples are
        // dealt across the folds in turn.  train_rows[k] lists the samples fold k trains on.
        std::vector<long> order(y.size());
        std::iota(order.begin(), order.end(), 0);
        dlib::rand rnd;
        randomize_samples(order, rnd);
        std::vector<long> fold(y.size());
        long next_pos = 0;
        long next_neg = 0;
        for (const long i : order)
            fold[i] = (y(i) > 0 ? next_pos++ : next_neg++) % num_folds;
        std::vector<std::vector<long>> train_rows(num_folds);
        for (long i = 0; i < y.size(); ++i)
        {
            for (long k = 0; k < num_folds; ++k)
            {
                if (fold[i] != k)
                    train_rows[k].push_back(i);
            }
        }

        const std::vector<double> label_values(y.begin(), y.end());

        // Returns the held out log loss of C == 10^e, and the sigmoid it was measured with.
        struct held_out_fit
        {
            double loss;
            double alpha;
            double beta;
        };
        const auto fit_held_out = [&](const int e)
        {
            const double c = std::pow(10.0, e);
            std::vector<double> scores(y.size());
            for (long k = 0; k < num_folds; ++k)
            {
                const auto df = train_svm(rowm(x, mat(train_rows[k])), rowm(y, mat(train_rows[k])), c);
                for (long i = 0; i < y.size(); ++i)
                {
                    if (fold[i] == k)
                        scores[i] = df(x(i));
                }
            }

            const auto [alpha, beta] = learn_platt_scaling(scores, label_values);
            double loss = 0;
            for (long i = 0; i < y.size(); ++i)
            {
                // -log(P(y(i))) is log(1 + exp(margin)), written so large margins can't overflow.
                const double margin = y(i) > 0 ? alpha*scores[i] + beta : -(alpha*scores[i] + beta);
                loss += margin > 0 ? margin + std::log1p(std::exp(-margin)) : std::log1p(std::exp(margin));
            }
            loss /= y.size();
            if (be_verbose)
                std::cout << "C: " << c << "   held out log loss: " << loss << std::endl;
            return held_out_fit{loss, alpha, beta};
        };

        // C == 10^best.  Start with the best of 0.1, 1 and 10.  If that is 0.1 or 10, keep
        // stepping the same way while the loss improves; ties go to the smaller C.
        int best = -1;
        held_out_fit best_fit = fit_held_out(best);
        for (const int e : {0, 1})
        {
            const held_out_fit f = fit_held_out(e);
            if (f.loss < best_fit.loss)
            {
                best = e;
                best_fit = f;
            }
        }
        const int step = best == -1 ? -1 : best == 1 ? +1 : 0;
        while (step != 0 && std::abs(best + step) <= 6)
        {
            const held_out_fit f = fit_held_out(best + step);
            if (step < 0 ? f.loss > best_fit.loss : f.loss >= best_fit.loss)
                break;
            best += step;
            best_fit = f;
        }
        if (be_verbose)
            std::cout << "chosen C: " << std::pow(10.0, best) << std::endl;

        return probabilistic_decision_function<kernel_type>(
            best_fit.alpha, best_fit.beta, train_svm(x, y, std::pow(10.0, best)));
    }

// ----------------------------------------------------------------------------------------

    normalized_function<multiclass_linear_decision_function<linear_kernel<matrix<double,0,1>>, unsigned long>>
    auto_train_multiclass_svm_linear_classifier (
        std::vector<matrix<double,0,1>> x,
        std::vector<unsigned long> y,
        const std::chrono::nanoseconds max_runtime,
        bool be_verbose = true
    );

    normalized_function<multiclass_linear_decision_function<linear_kernel<matrix<float,0,1>>, unsigned long>>
    auto_train_multiclass_svm_linear_classifier (
        const std::vector<matrix<float,0,1>>& x,
        std::vector<unsigned long> y,
        const std::chrono::nanoseconds max_runtime,
        bool be_verbose = true
    );
}

#endif // DLIB_AUTO_LEARnING_Hh_

