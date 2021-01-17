.ONESHELL:
.PHONY: test deps download build clean astyle cmds docker

# OpenCV version to use.
OPENCV_VERSION?=4.5.1

# Go version to use when building Docker image
GOVERSION?=1.15.3

# Temporary directory to put files into.
TMP_DIR?=/tmp/

# Build shared or static library
BUILD_SHARED_LIBS?=ON

# Package list for each well-known Linux distribution
RPMS=cmake curl wget git gtk2-devel libpng-devel libjpeg-devel libtiff-devel tbb tbb-devel libdc1394-devel unzip gcc-c++
DEBS=unzip wget build-essential cmake curl git libgtk2.0-dev pkg-config libavcodec-dev libavformat-dev libswscale-dev libtbb2 libtbb-dev libjpeg-dev libpng-dev libtiff-dev libdc1394-22-dev

explain:
	@echo "For quick install with typical defaults of both OpenCV and GoCV, run 'make install'"

# Detect Linux distribution
distro_deps=
ifneq ($(shell which dnf 2>/dev/null),)
	distro_deps=deps_fedora
else
ifneq ($(shell which apt-get 2>/dev/null),)
	distro_deps=deps_debian
else
ifneq ($(shell which yum 2>/dev/null),)
	distro_deps=deps_rh_centos
endif
endif
endif

# Install all necessary dependencies.
deps: $(distro_deps)

deps_rh_centos:
	yum -y install pkgconfig $(RPMS)

deps_fedora:
	dnf -y install pkgconf-pkg-config $(RPMS)

deps_debian:
	apt-get -y update
	apt-get -y install $(DEBS)


# Download OpenCV source tarballs.
download:
	rm -rf $(TMP_DIR)opencv
	mkdir $(TMP_DIR)opencv
	cd $(TMP_DIR)opencv
	curl -Lo opencv.zip https://github.com/opencv/opencv/archive/$(OPENCV_VERSION).zip
	unzip -q opencv.zip
	curl -Lo opencv_contrib.zip https://github.com/opencv/opencv_contrib/archive/$(OPENCV_VERSION).zip
	unzip -q opencv_contrib.zip
	rm opencv.zip opencv_contrib.zip
	cd -

# Download openvino source tarballs.
download_openvino:
	rm -rf /usr/local/dldt/
	rm -rf /usr/local/openvino/
	git clone https://github.com/openvinotoolkit/openvino -b 2019_R3.1 /usr/local/openvino/

# Build openvino.
build_openvino_package:
	cd /usr/local/openvino/inference-engine
	git submodule init
	git submodule update --recursive
	./install_dependencies.sh
	mv -f thirdparty/clDNN/common/intel_ocl_icd/6.3/linux/Release thirdparty/clDNN/common/intel_ocl_icd/6.3/linux/RELEASE
	mkdir build
	cd build
	rm -rf *
	cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local -D BUILD_SHARED_LIBS=${BUILD_SHARED_LIBS} -D ENABLE_VPU=ON -D ENABLE_MKL_DNN=ON -D ENABLE_CLDNN=ON ..
	$(MAKE) -j $(shell nproc --all)
	touch VERSION
	mkdir -p src/ngraph
	cp thirdparty/ngraph/src/ngraph/version.hpp src/ngraph
	cd -

# Build OpenCV.
build:
	cd $(TMP_DIR)opencv/opencv-$(OPENCV_VERSION)
	mkdir build
	cd build
	rm -rf *
	cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local -D BUILD_SHARED_LIBS=${BUILD_SHARED_LIBS} -D OPENCV_EXTRA_MODULES_PATH=$(TMP_DIR)opencv/opencv_contrib-$(OPENCV_VERSION)/modules -D BUILD_DOCS=OFF -D BUILD_EXAMPLES=OFF -D BUILD_TESTS=OFF -D BUILD_PERF_TESTS=OFF -D BUILD_opencv_java=NO -D BUILD_opencv_python=NO -D BUILD_opencv_python2=NO -D BUILD_opencv_python3=NO -D WITH_JASPER=OFF -DOPENCV_GENERATE_PKGCONFIG=ON ..
	$(MAKE) -j $(shell nproc --all)
	$(MAKE) preinstall
	cd -

# Build OpenCV on Raspbian with ARM hardware optimizations.
build_raspi:
	cd $(TMP_DIR)opencv/opencv-$(OPENCV_VERSION)
	mkdir build
	cd build
	rm -rf *
	cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local -D BUILD_SHARED_LIBS=${BUILD_SHARED_LIBS} -D OPENCV_EXTRA_MODULES_PATH=$(TMP_DIR)opencv/opencv_contrib-$(OPENCV_VERSION)/modules -D BUILD_DOCS=OFF -D BUILD_EXAMPLES=OFF -D BUILD_TESTS=OFF -D BUILD_PERF_TESTS=OFF -D BUILD_opencv_java=OFF -D BUILD_opencv_python=NO -D BUILD_opencv_python2=NO -D BUILD_opencv_python3=NO -D ENABLE_NEON=ON -D ENABLE_VFPV3=ON -D WITH_JASPER=OFF -D OPENCV_GENERATE_PKGCONFIG=ON ..
	$(MAKE) -j $(shell nproc --all)
	$(MAKE) preinstall
	cd -

# Build OpenCV on Raspberry pi zero which has ARMv6.
build_raspi_zero:
	cd $(TMP_DIR)opencv/opencv-$(OPENCV_VERSION)
	mkdir build
	cd build
	rm -rf *
	cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local -D BUILD_SHARED_LIBS=${BUILD_SHARED_LIBS} -D OPENCV_EXTRA_MODULES_PATH=$(TMP_DIR)opencv/opencv_contrib-$(OPENCV_VERSION)/modules -D BUILD_DOCS=OFF -D BUILD_EXAMPLES=OFF -D BUILD_TESTS=OFF -D BUILD_PERF_TESTS=OFF -D BUILD_opencv_java=OFF -D BUILD_opencv_python=NO -D BUILD_opencv_python2=NO -D BUILD_opencv_python3=NO -D ENABLE_VFPV2=ON -D WITH_JASPER=OFF -D OPENCV_GENERATE_PKGCONFIG=ON ..
	$(MAKE) -j $(shell nproc --all)
	$(MAKE) preinstall
	cd -

# Build OpenCV with non-free contrib modules.
build_nonfree:
	cd $(TMP_DIR)opencv/opencv-$(OPENCV_VERSION)
	mkdir build
	cd build
	rm -rf *
	cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local -D BUILD_SHARED_LIBS=${BUILD_SHARED_LIBS} -D OPENCV_EXTRA_MODULES_PATH=$(TMP_DIR)opencv/opencv_contrib-$(OPENCV_VERSION)/modules -D BUILD_DOCS=OFF -D BUILD_EXAMPLES=OFF -D BUILD_TESTS=OFF -D BUILD_PERF_TESTS=OFF -D BUILD_opencv_java=NO -D BUILD_opencv_python=NO -D BUILD_opencv_python2=NO -D BUILD_opencv_python3=NO -D WITH_JASPER=OFF -DOPENCV_GENERATE_PKGCONFIG=ON -DOPENCV_ENABLE_NONFREE=ON ..
	$(MAKE) -j $(shell nproc --all)
	$(MAKE) preinstall
	cd -

# Build OpenCV with openvino.
build_openvino:
	cd $(TMP_DIR)opencv/opencv-$(OPENCV_VERSION)
	mkdir build
	cd build
	rm -rf *
	cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local -D BUILD_SHARED_LIBS=${BUILD_SHARED_LIBS} -D ENABLE_CXX11=ON -D OPENCV_EXTRA_MODULES_PATH=$(TMP_DIR)opencv/opencv_contrib-$(OPENCV_VERSION)/modules -D WITH_INF_ENGINE=ON -D InferenceEngine_DIR=/usr/local/dldt/inference-engine/build -D BUILD_DOCS=OFF -D BUILD_EXAMPLES=OFF -D BUILD_TESTS=OFF -D BUILD_PERF_TESTS=OFF -D BUILD_opencv_java=NO -D BUILD_opencv_python=NO -D BUILD_opencv_python2=NO -D BUILD_opencv_python3=NO -D WITH_JASPER=OFF -DOPENCV_GENERATE_PKGCONFIG=ON -DOPENCV_ENABLE_NONFREE=ON ..
	$(MAKE) -j $(shell nproc --all)
	$(MAKE) preinstall
	cd -

# Build OpenCV with cuda.
build_cuda:
	cd $(TMP_DIR)opencv/opencv-$(OPENCV_VERSION)
	mkdir build
	cd build
	rm -rf *
	cmake -j $(shell nproc --all) -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local -D BUILD_SHARED_LIBS=${BUILD_SHARED_LIBS} -D OPENCV_EXTRA_MODULES_PATH=$(TMP_DIR)opencv/opencv_contrib-$(OPENCV_VERSION)/modules -D BUILD_DOCS=OFF -D BUILD_EXAMPLES=OFF -D BUILD_TESTS=OFF -D BUILD_PERF_TESTS=OFF -D BUILD_opencv_java=NO -D BUILD_opencv_python=NO -D BUILD_opencv_python2=NO -D BUILD_opencv_python3=NO -D WITH_JASPER=OFF -DOPENCV_GENERATE_PKGCONFIG=ON -DWITH_CUDA=ON -DENABLE_FAST_MATH=1 -DCUDA_FAST_MATH=1 -DWITH_CUBLAS=1 -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda/ -DBUILD_opencv_cudacodec=OFF -D WITH_CUDNN=ON -D OPENCV_DNN_CUDA=ON -D CUDA_GENERATION=Auto ..
	$(MAKE) -j $(shell nproc --all)
	$(MAKE) preinstall
	cd -

# Build OpenCV with cuda.
build_all:
	cd $(TMP_DIR)opencv/opencv-$(OPENCV_VERSION)
	mkdir build
	cd build
	rm -rf *
	cmake -j $(shell nproc --all) -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local -D BUILD_SHARED_LIBS=${BUILD_SHARED_LIBS} -D ENABLE_CXX11=ON -D OPENCV_EXTRA_MODULES_PATH=$(TMP_DIR)opencv/opencv_contrib-$(OPENCV_VERSION)/modules -D WITH_INF_ENGINE=ON -D InferenceEngine_DIR=/usr/local/dldt/inference-engine/build -D BUILD_DOCS=OFF -D BUILD_EXAMPLES=OFF -D BUILD_TESTS=OFF -D BUILD_PERF_TESTS=OFF -D BUILD_opencv_java=NO -D BUILD_opencv_python=NO -D BUILD_opencv_python2=NO -D BUILD_opencv_python3=NO -D WITH_JASPER=OFF -DOPENCV_GENERATE_PKGCONFIG=ON -DWITH_CUDA=ON -DENABLE_FAST_MATH=1 -DCUDA_FAST_MATH=1 -DWITH_CUBLAS=1 -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda/ -DBUILD_opencv_cudacodec=OFF -D WITH_CUDNN=ON -D OPENCV_DNN_CUDA=ON -D CUDA_GENERATION=Auto ..
	$(MAKE) -j $(shell nproc --all)
	$(MAKE) preinstall
	cd -

# Cleanup temporary build files.
clean:
	go clean --cache
	rm -rf $(TMP_DIR)opencv

# Cleanup old library files.
sudo_pre_install_clean:
	rm -rf /usr/local/lib/cmake/opencv4/
	rm -rf /usr/local/lib/libopencv*
	rm -rf /usr/local/lib/pkgconfig/opencv*
	rm -rf /usr/local/include/opencv*

# Do everything.
install: deps download sudo_pre_install_clean build sudo_install clean verify

# Do everything on Raspbian.
install_raspi: deps download build_raspi sudo_install clean verify

# Do everything on the raspberry pi zero.
install_raspi_zero: deps download build_raspi_zero sudo_install clean verify

# Do everything with cuda.
install_cuda: deps download sudo_pre_install_clean build_cuda sudo_install clean verify verify_cuda

# Do everything with openvino.
install_openvino: deps download download_openvino sudo_pre_install_clean build_openvino_package sudo_install_openvino build_openvino sudo_install clean verify_openvino

# Do everything with openvino and cuda.
install_all: deps download download_openvino sudo_pre_install_clean build_openvino_package sudo_install_openvino build_all sudo_install clean verify_openvino verify_cuda

# Install system wide.
sudo_install:
	cd $(TMP_DIR)opencv/opencv-$(OPENCV_VERSION)/build
	$(MAKE) install
	ldconfig
	cd -

# Install system wide.
sudo_install_openvino:
	cd /usr/local/openvino/inference-engine/build
	$(MAKE) install
	ldconfig
	cd -

# Build a minimal Go app to confirm gocv works.
verify:
	go run ./cmd/version/main.go

# Build a minimal Go app to confirm gocv cuda works.
verify_cuda:
	go run ./cmd/cuda/main.go

# Build a minimal Go app to confirm gocv openvino works.
verify_openvino:
	go run -tags openvino ./cmd/version/main.go

# Runs tests.
# This assumes env.sh was already sourced.
# pvt is not tested here since it requires additional depenedences.
test:
	go test -tags matprofile . ./contrib

docker:
	docker build --build-arg OPENCV_VERSION=$(OPENCV_VERSION) --build-arg GOVERSION=$(GOVERSION) .

astyle:
	astyle --project=.astylerc --recursive *.cpp,*.h

CMDS=basic-drawing caffe-classifier captest capwindow counter faceblur facedetect find-circles hand-gestures hello-sift img-similarity mjpeg-streamer motion-detect pose saveimage savevideo showimage ssd-facedetect tf-classifier tracking version
cmds:
	for cmd in $(CMDS) ; do \
		go build -o build/$$cmd cmd/$$cmd/main.go ;
	done ; \