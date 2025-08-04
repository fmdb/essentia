# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file LICENSE.rst or https://cmake.org/licensing for details.

#[=======================================================================[.rst:
FindTensorFlow
-------

Finds the TensorFlow library, https://www.tensorflow.org.

Imported Targets
^^^^^^^^^^^^^^^^

This module provides the following imported targets, if found:

``TensorFlow::tensorflow``
  The TensorFlow library

Result Variables
^^^^^^^^^^^^^^^^

This will define the following variables:

``TensorFlow_FOUND``
  True if the system has the TensorFlow library.
``TensorFlow_VERSION``
  The version of the TensorFlow library which was found.
``TensorFlow_INCLUDE_DIRS``
  Include directories needed to use TensorFlow.
``TensorFlow_LIBRARIES``
  Libraries needed to link to TensorFlow.

Cache Variables
^^^^^^^^^^^^^^^

The following cache variables may also be set:

``TensorFlow_INCLUDE_DIR``
  The directory containing ``tensorflow.h``.
``TensorFlow_LIBRARY``
  The path to the TensorFlow library.

#]=======================================================================]

find_package(PkgConfig QUIET)

if (PKG_CONFIG_FOUND)
  pkg_check_modules(PC_TensorFlow tensorflow QUIET)
endif ()

find_path(TensorFlow_INCLUDE_DIR
  NAMES tensorflow/c/c_api.h
  HINTS ${PC_TensorFlow_INCLUDE_DIRS}
  PATHS
    /usr/local/include
    /usr/include
    /opt/homebrew/include
    /opt/homebrew/Cellar/libtensorflow/*/include
    # Also look for the tensorflow subdirectory structure
    /usr/local/include/tensorflow
    /usr/include/tensorflow
    /opt/homebrew/include/tensorflow
    /opt/homebrew/Cellar/libtensorflow/*/include/tensorflow
    # Common Linux paths for TensorFlow C API
    /usr/local/include/tensorflow/c
    /usr/include/tensorflow/c
    PATH_SUFFIXES tensorflow
)

find_library(TensorFlow_LIBRARY
  NAMES tensorflow
  HINTS ${PC_TensorFlow_LIBRARY_DIRS}
  PATHS
    /usr/local/lib
    /usr/lib
    /opt/homebrew/lib
    /opt/homebrew/Cellar/libtensorflow/*/lib
    # Linux-specific library paths
    /usr/lib/x86_64-linux-gnu
    /usr/lib/aarch64-linux-gnu
    /usr/local/lib64
    /usr/lib64
)

set(TensorFlow_VERSION ${PC_TensorFlow_VERSION})

include(FindPackageHandleStandardArgs)

find_package_handle_standard_args(TensorFlow
  REQUIRED_VARS
    TensorFlow_LIBRARY
    TensorFlow_INCLUDE_DIR
  VERSION_VAR
    TensorFlow_VERSION
)

if(TensorFlow_FOUND)
  set(TensorFlow_LIBRARIES ${TensorFlow_LIBRARY})
  set(TensorFlow_INCLUDE_DIRS ${TensorFlow_INCLUDE_DIR})
  set(TensorFlow_DEFINITIONS ${PC_TensorFlow_CFLAGS_OTHER})
endif()

if(TensorFlow_FOUND AND NOT TARGET TensorFlow::tensorflow)
  add_library(TensorFlow::tensorflow UNKNOWN IMPORTED)
  set_target_properties(TensorFlow::tensorflow PROPERTIES
    IMPORTED_LOCATION "${TensorFlow_LIBRARY}"
    INTERFACE_COMPILE_OPTIONS "${PC_TensorFlow_CFLAGS_OTHER}"
    INTERFACE_INCLUDE_DIRECTORIES "${TensorFlow_INCLUDE_DIR}"
  )
endif()
