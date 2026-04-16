#!/bin/bash
set -euo pipefail

cd /mnt/d/source/Pioneer/pioneer
rm -rf build-appimage
: > appimage_build.log

{
    echo "== AppImage build started $(date -Is) =="

    if [ ! -f linuxdeploy-x86_64.AppImage ]; then
        wget -O linuxdeploy-x86_64.AppImage \
            https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
        chmod a+x linuxdeploy-x86_64.AppImage
    fi

    cmake -S . -B build-appimage \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=1 \
        -DPIONEER_DATA_DIR=usr/share/data \
        -DCMAKE_INSTALL_PREFIX=/mnt/d/source/Pioneer/pioneer/build-appimage/appdir/usr \
        -DPIONEER_INSTALL_DATADIR=share \
        -DAPPIMAGE_BUILD=1

    cmake --build build-appimage --target all build-data -j4

    cmake --build build-appimage --target install

    cd build-appimage
    ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 \
        ../linuxdeploy-x86_64.AppImage --appdir appdir --output appimage

    cp Pioneer*.AppImage ..
    ls -lh ../Pioneer*.AppImage

    echo "== AppImage build finished $(date -Is) =="
} 2>&1 | tee -a appimage_build.log
