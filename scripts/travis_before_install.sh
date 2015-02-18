#!/usr/bin/env bash

set -e
set -o pipefail

if [[ ${TRAVIS_OS_NAME} == "linux" ]]; then
    #
    # install Linux dependencies
    #
    if [[ ${MASON_PLATFORM} != "android" ]]; then
        if [[ `lsb_release -r` =~ "12.04" ]]; then
            sudo add-apt-repository --yes ppa:ubuntu-toolchain-r/test
        fi
        sudo add-apt-repository --yes ppa:boost-latest/ppa
    fi

    mapbox_time "apt_update" \
    sudo apt-get update -y

    mapbox_time "install_build_tools" \
    sudo apt-get -y install git build-essential automake gdb \
                            libtool xutils-dev make cmake pkg-config python-pip

    if [[ ${MASON_PLATFORM} == "android" ]]; then
        mapbox_time "setup_android" \
        ./scripts/setup-android-build.sh
    else
        mapbox_time "install_gcc" \
        sudo apt-get -y install gcc-4.8 g++-4.8

        mapbox_time "install_libraries" \
        sudo apt-get -y install zlib1g-dev libboost1.55-dev \
                                libcurl4-openssl-dev libpng-dev libsqlite3-dev

        mapbox_time "install_opengl" \
        sudo apt-get -y install mesa-utils libxi-dev x11proto-randr-dev \
                                x11proto-xext-dev libxrandr-dev \
                                x11proto-xf86vidmode-dev libxxf86vm-dev \
                                libxcursor-dev libxinerama-dev \
                                llvm-3.4 # required for mesa

        mapbox_time "install_mesa" \
        mason install mesa 10.4.3
    fi

    mapbox_time "install_awscli" \
    sudo pip install awscli
elif [[ ${TRAVIS_OS_NAME} == "osx" ]]; then
    #
    # install OS X dependencies
    #
    mapbox_time "install_build_tools" \
    brew install git

    mapbox_time "install_awscli" \
    sudo pip install awscli

    mapbox_time "install_xcpretty" \
    gem install xcpretty --no-rdoc --no-ri --no-document --quiet
fi
