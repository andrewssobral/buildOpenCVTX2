#!/bin/bash
# License: MIT. See license file in root directory
# Copyright(c) JetsonHacks (2017-2018)

OPENCV_VERSION=3.4.1
# Jetson TX2
ARCH_BIN=6.2
# Jetson TX1
# ARCH_BIN=5.3
CMAKE_INSTALL_PREFIX=/usr/local
# Download the opencv_extras repository
# If you are installing the opencv testdata, ie
#  OPENCV_TEST_DATA_PATH=../opencv_extra/testdata
# Make sure that you set this to YES (same for opencv contrib)
# Value should be YES or NO
DOWNLOAD_OPENCV_EXTRAS=YES
DOWNLOAD_OPENCV_CONTRIB=YES
# Source code directory
OPENCV_SOURCE_DIR=$HOME/Downloads
WHEREAMI=$PWD

source scripts/jetson_variables

# Print out the current configuration
echo "Build configuration: "
echo " NVIDIA Jetson $JETSON_BOARD"
echo " Operating System: $JETSON_L4T_STRING [Jetpack $JETSON_JETPACK]"
echo " Current OpenCV Installation: $JETSON_OPENCV"
echo " OpenCV binaries will be installed in: $CMAKE_INSTALL_PREFIX"

if [ $DOWNLOAD_OPENCV_EXTRAS == "YES" ] ; then
 echo "Also installing opencv_extras"
fi

if [ $DOWNLOAD_OPENCV_CONTRIB == "YES" ] ; then
 echo "Also installing opencv_contrib"
fi

# Repository setup
sudo apt-add-repository universe
sudo apt-get update

# Download dependencies for the desired configuration
cd $WHEREAMI
sudo apt-get install -y \
    cmake \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libeigen3-dev \
    libglew-dev \
    libgtk2.0-dev \
    libgtk-3-dev \
    libjasper-dev \
    libjpeg-dev \
    libpng12-dev \
    libpostproc-dev \
    libswscale-dev \
    libtbb-dev \
    libtiff5-dev \
    libv4l-dev \
    libxvidcore-dev \
    libx264-dev \
    qt5-default \
    zlib1g-dev \
    pkg-config

# https://devtalk.nvidia.com/default/topic/1007290/jetson-tx2/building-opencv-with-opengl-support-/post/5141945/#5141945
cd /usr/local/cuda/include
sudo patch -N cuda_gl_interop.h $WHEREAMI'/patches/OpenGLHeader.patch' 
# Clean up the OpenGL tegra libs that usually get crushed
cd /usr/lib/aarch64-linux-gnu/
# before: libGL.so -> mesa/libGL.so
# after:  libGL.so -> tegra/libGL.so
sudo ln -sf tegra/libGL.so libGL.so

cd $WHEREAMI

# Python 2.7
sudo apt-get install -y python-dev python-numpy python-py python-pytest
# Python 3.5
sudo apt-get install -y python3-dev python3-numpy python3-py python3-pytest

# GStreamer support
sudo apt-get install -y libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev 

cd $OPENCV_SOURCE_DIR
git clone https://github.com/opencv/opencv.git
cd opencv
git checkout -b v${OPENCV_VERSION} ${OPENCV_VERSION}
if [ $OPENCV_VERSION = 3.4.1 ] ; then
  # For 3.4.1, use this commit to fix samples/gpu/CMakeLists.txt
  git merge ec0bb66e5e176ffe267948a98508ac6721daf8ad
fi

if [ $DOWNLOAD_OPENCV_EXTRAS == "YES" ] ; then
 echo "Installing opencv_extras"
 cd $OPENCV_SOURCE_DIR
 git clone https://github.com/opencv/opencv_extra.git
 cd opencv_extra
 git checkout -b v${OPENCV_VERSION} ${OPENCV_VERSION}
fi

if [ $DOWNLOAD_OPENCV_CONTRIB == "YES" ] ; then
 echo "Installing opencv_contrib"
 cd $OPENCV_SOURCE_DIR
 git clone https://github.com/opencv/opencv_contrib.git
 cd opencv_contrib
 git checkout -b v${OPENCV_VERSION} ${OPENCV_VERSION}
fi

cd $OPENCV_SOURCE_DIR/opencv
mkdir build
cd build
# Jetson TX2 

# Here are some options to install source examples and tests
#     -D INSTALL_TESTS=ON \
#     -D OPENCV_TEST_DATA_PATH=../opencv_extra/testdata \
#     -D INSTALL_C_EXAMPLES=ON \
#     -D INSTALL_PYTHON_EXAMPLES=ON \
#     -D WITH_JAVA=ON \
#
# Optional:
#     -D PYTHON2_EXECUTABLE=$(which python2) \
#     -D PYTHON2_INCLUDE_DIR=$(python2 -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") \
#     -D PYTHON2_PACKAGES_PATH=$(python2 -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") \
#     -D PYTHON3_EXECUTABLE=$(which python3) \
#     -D PYTHON3_INCLUDE_DIR=$(python3 -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") \
#     -D PYTHON3_PACKAGES_PATH=$(python3 -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") \
#
# Unsupported options:
#     -D WITH_IPP=ON \
#     -D WITH_TBB=ON \
#     -D ENABLE_AVX=ON \
#
# Not tested:
#     -D WITH_FFMPEG=ON \
#     -D FFMPEG_INCLUDE_DIR=/usr/local/ffmpeg/3.3.3/include/ \
#     -D FFMPEG_LIB_DIR=/usr/local/ffmpeg/3.3.3/lib/ \
#
# There are also switches which tell CMAKE to build the samples and tests
# Check OpenCV documentation for details

# Enabled by default: opencv_extra & opencv_contrib
time cmake -D CMAKE_BUILD_TYPE=RELEASE \
      -D CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX} \
      -D WITH_CUDA=ON \
      -D CUDA_ARCH_BIN=${ARCH_BIN} \
      -D CUDA_ARCH_PTX="" \
      -D ENABLE_FAST_MATH=ON \
      -D CUDA_FAST_MATH=ON \
      -D WITH_CUBLAS=ON \
      -D WITH_LIBV4L=ON \
      -D WITH_GSTREAMER=ON \
      -D WITH_GSTREAMER_0_10=OFF \
      -D WITH_QT=ON \
      -D WITH_OPENGL=ON \
      -D WITH_JAVA=OFF \
      -D ENABLE_CXX11=ON \
      -D BUILD_TESTS=ON \
      -D INSTALL_TESTS=ON \
      -D OPENCV_TEST_DATA_PATH=${OPENCV_SOURCE_DIR}/opencv_extra/testdata \
      -D OPENCV_EXTRA_MODULES_PATH=${OPENCV_SOURCE_DIR}/opencv_contrib/modules \
      -D BUILD_PERF_TESTS=OFF \
      -D BUILD_EXAMPLES=ON \
      -D INSTALL_C_EXAMPLES=ON \
      -D INSTALL_PYTHON_EXAMPLES=ON \
      ../

if [ $? -eq 0 ] ; then
  echo "CMake configuration make successful"
else
  # Try to make again
  echo "CMake issues " >&2
  echo "Please check the configuration being used"
  exit 1
fi

# How to boost the power of TX2 to 15W?
# You can set max clocks with this from the home directory:
# sudo ./jetson_clocks.sh
# However, you may like to use also"save" and "restore" functions with that:
# sudo /home/ubuntu/jetson_clocks.sh --store       # save clocks config into l4t_dfs.conf file
# sudo /home/ubuntu/jetson_clocks.sh               # boost clocks
# sudo /home/ubuntu/jetson_clocks.sh --restore     # restore clocks config from l4t_dfs.conf file
# or use nvpmodel
# https://www.jetsonhacks.com/2017/03/25/nvpmodel-nvidia-jetson-tx2-development-kit/
# Consider $ sudo nvpmodel -m 2 or $ sudo nvpmodel -m 0
# You can query which mode is currently being used:
# sudo nvpmodel -q --verbose
# Default: NVPM VERB: Current mode: NV Power Mode: MAXP_CORE_ARM (mode 3)
NUM_CPU=$(nproc)
time make -j$(($NUM_CPU - 1))
if [ $? -eq 0 ] ; then
  echo "OpenCV make successful"
else
  # Try to make again; Sometimes there are issues with the build
  # because of lack of resources or concurrency issues
  echo "Make did not build " >&2
  echo "Retrying ... "
  # Single thread this time
  make
  if [ $? -eq 0 ] ; then
    echo "OpenCV make successful"
  else
    # Try to make again
    echo "Make did not successfully build" >&2
    echo "Please fix issues and retry build"
    exit 1
  fi
fi

echo "Installing ... "
sudo make install
if [ $? -eq 0 ] ; then
   echo "OpenCV installed in: $CMAKE_INSTALL_PREFIX"
else
   echo "There was an issue with the final installation"
   exit 1
fi

# check installation
IMPORT_CHECK="$(python -c "import cv2 ; print cv2.__version__")"
if [[ $IMPORT_CHECK != *$OPENCV_VERSION* ]]; then
  echo "There was an error loading OpenCV in the Python sanity test."
  echo "The loaded version does not match the version built here."
  echo "Please check the installation."
  echo "The first check should be the PYTHONPATH environment variable."
fi
