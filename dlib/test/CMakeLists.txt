#
# This is a CMake makefile.  You can find the cmake utility and
# information about it at http://www.cmake.org
#

cmake_minimum_required(VERSION 2.8.12)

# create a variable called target_name and set it to the string "dtest"
set (target_name dtest)
PROJECT(${target_name})

# compile the dlib/all/source.cpp file into its own object just to make sure it compiles
set(DLIB_TEST_COMPILE_ALL_SOURCE_CPP ON)

add_subdirectory(.. dlib_build)

# This variable contains a list of all the tests we are building
# into the regression test suite.
set (tests
    dnn.cpp
)


# add all the cpp files we want to compile to this list.  This tells
# cmake that they are part of our target (which is the executable named dtest)
ADD_EXECUTABLE(${target_name} main.cpp tester.cpp ${tests})

# Turn on all warnings when using gcc.
if (CMAKE_COMPILER_IS_GNUCXX)
   add_definitions("-W -Wall")
   # I don't care about unused testing functions though.  I like to keep them
   # around.  Don't warn about it.
   add_definitions("-Wno-unused-function -Wno-deprecated-copy")
endif()


TARGET_LINK_LIBRARIES(${target_name} dlib::dlib )
