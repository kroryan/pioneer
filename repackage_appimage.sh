#!/bin/bash
set -euo pipefail

cd /mnt/d/source/Pioneer/pioneer
echo "== Quick AppImage repackage (data-only, no C++ compile) =="
echo "Started: $(date -Is)"

# Copy updated data files into existing appdir
SRC=data
DST=build-appimage/appdir/usr/share/data

echo "Syncing modules..."
cp -v $SRC/modules/BountyBoard.lua         $DST/modules/
cp -v $SRC/modules/CrewInteractions.lua     $DST/modules/
cp -v $SRC/modules/DynamicSystemEvents.lua  $DST/modules/
cp -v $SRC/modules/EconomyEnhancements.lua  $DST/modules/
cp -v $SRC/modules/ExplorationRewards.lua   $DST/modules/
cp -v $SRC/modules/PassengerMissions.lua    $DST/modules/
cp -v $SRC/modules/PersistentNPCTrade.lua   $DST/modules/
cp -v $SRC/modules/QuickTest.lua            $DST/modules/
cp -v $SRC/modules/SmugglingContracts.lua   $DST/modules/
cp -v $SRC/modules/StationServices.lua      $DST/modules/
cp -v $SRC/modules/SupplyChainNetwork.lua   $DST/modules/
cp -v $SRC/modules/SystemNewsFeed.lua       $DST/modules/

echo "Syncing pigui..."
mkdir -p $DST/pigui/modules/info-view
mkdir -p $DST/pigui/modules/station-view
cp -v $SRC/pigui/modules/info-view/07-economy-dashboard.lua  $DST/pigui/modules/info-view/
cp -v $SRC/pigui/modules/station-view/08-economy.lua         $DST/pigui/modules/station-view/

echo "Repackaging AppImage..."
cd build-appimage
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 \
    ../linuxdeploy-x86_64.AppImage --appdir appdir --output appimage

cp Pioneer*.AppImage ..
ls -lh ../Pioneer-x86_64.AppImage

echo "== Repackage finished: $(date -Is) =="
