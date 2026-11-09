// Copyright (C) 2018  Davis E. King (davis@dlib.net)
// License: Boost Software License   See LICENSE.txt for the full license.
#undef DLIB_AUTO_LEARnING_ABSTRACT_Hh_
#ifdef DLIB_AUTO_LEARnING_ABSTRACT_Hh_

#include "kernel_abstract.h"
#include "function_abstract.h"
#include <chrono>
#include <vector>

namespace dlib
{

    normalized_function<decision_function<radial_basis_kernel<matrix<double,0,1>>>> auto_train_rbf_classifier (
        std::vector<matrix<double,0,1>> x,
        std::vector<double> y,
        const std::chrono::nanoseconds max_runtime,
        bool be_verbose = true
    );
    /*!
        requires
            - is_binary_classification_problem(x,y) == true
            - y contains at least 6 examples of each class.
        ensures
            - This routine trains a radial basis function SVM on the given binary
              classification training data.  It uses the svm_c_trainer to do this.  It also
              uses find_max_global() and 6-fold cross-validation to automatically determine
              the best settings of the SVM's hyperparameters.
            - The hyperparameter search will run for about max_runtime and will print
              messages to the screen as it runs if be_verbose==true.
    !*/

// ----------------------------------------------------------------------------------------

    template <
        typename samples_type,
        typename labels_type
        >
    probabilistic_decision_function<kernel_type> auto_train_linear_classifier (
        const samples_type& x,
        const labels_type& y,
        bool be_verbose = true
    );
    /*!
        requires
            - x is a vector of samples of type sample_type, and y a vector of labels, each
              a dlib::matrix or something mat() converts to one, such as a std::vector or
              a view of selected elements made with rowm().
            - sample_type is a dlib::matrix column vector, or a sparse vector as defined
              in dlib/svm/sparse_vector_abstract.h.
            - is_binary_classification_problem(x,y) == true
            - y contains at least 5 examples of each class.
        ensures
            - Trains a linear SVM on x and y and returns a function that outputs the
              probability that a sample's label is +1.
            - kernel_type is linear_kernel<sample_type> if sample_type is a dlib::matrix,
              and sparse_linear_kernel<sample_type> otherwise.
            - The SVM is an svm_c_linear_dcd_trainer whose C is scaled per class: trained
              on M samples, M_pos of them +1 and M_neg of them -1, the +1 class gets
              C*M/(2*M_pos) and the -1 class C*M/(2*M_neg).
            - The loss of a value of C is the mean log loss of its 5-fold cross-validation
              scores, after learn_platt_scaling() fits a sigmoid to them.  Each fold holds
              the same share of each class.
            - C is a power of 10 in [1e-6, 1e6].  The values tried are 0.1, 1 and 10, plus
              the next power of 10 beyond the smallest or largest value tried, for as long
              as that value has the lowest loss.  The chosen C is the value tried with the
              lowest loss, the smallest on ties.
            - The returned function's decision_funct is the SVM trained on all of x with the
              chosen C, and its sigmoid is the one fit to that C's cross-validation scores.
            - The same x and y always give the same result.
            - If be_verbose == true, prints the loss of each value of C tried, and the
              chosen C, to standard out.
    !*/

// ----------------------------------------------------------------------------------------

    normalized_function<multiclass_linear_decision_function<linear_kernel<matrix<double,0,1>>, unsigned long>>
    auto_train_multiclass_svm_linear_classifier (
        std::vector<matrix<double,0,1>> x,
        std::vector<unsigned long> y,
        const std::chrono::nanoseconds max_runtime,
        bool be_verbose = true
    );
    /*!
        requires
            - is_learning_problem(x,y) == true
            - y contains at least 3 examples of each class.
        ensures
            - This routine trains a linear multiclass SVM on the given classification training data.
              It uses the svm_multiclass_linear_trainer to do this.  It also
              uses find_max_global() and 3-fold cross-validation to automatically determine
              the best setting of the SVM's hyperparameter C.
            - The hyperparameter search will run for about max_runtime and will print
              messages to the screen as it runs if be_verbose==true.
    !*/

    normalized_function<multiclass_linear_decision_function<linear_kernel<matrix<float,0,1>>, unsigned long>>
    auto_train_multiclass_svm_linear_classifier (
        const std::vector<matrix<float,0,1>>& x,
        std::vector<unsigned long> y,
        const std::chrono::nanoseconds max_runtime,
        bool be_verbose = true
    );
    /*!
        requires
            - is_learning_problem(x,y) == true
            - y contains at least 3 examples of each class.
        ensures
            - This function is just an overload of the one defined immediately above.  It casts the
              input data from float to double, calls the above function, and casts the results back
              to float.
            - This routine trains a linear multiclass SVM on the given classification training data.
              It uses the svm_multiclass_linear_trainer to do this.  It also
              uses find_max_global() and 3-fold cross-validation to automatically determine
              the best setting of the SVM's hyperparameter C.
            - The hyperparameter search will run for about max_runtime and will print
              messages to the screen as it runs if be_verbose==true.
    !*/
}

#endif // DLIB_AUTO_LEARnING_ABSTRACT_Hh_


