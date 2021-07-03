#!/bin/sh

echo "Copy benchmarks to $1 implementation…"
cp -r Sources/Benchmarks Internal/$1/Sources/$1

echo "Build benchmark suite for $1 implementation…"

# see https://github.com/apple/swift-package-manager/pull/2981#issuecomment-710282803
DERIVED_DATA="`ls -d $HOME/Library/Developer/Xcode/DerivedData/$1-*`"
BUILD_PRODUCTS_PATH="$DERIVED_DATA/Build/Intermediates.noindex/ArchiveIntermediates/$1/BuildProductsPath"

mkdir -p Internal/tmp

xcodebuild clean archive -workspace Internal/$1 -scheme $1 \
  -configuration Release \
	-destination "generic/platform=macOS" \
	-archivePath "Internal/tmp/macOS$1" \
	SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  SWIFT_OPTIMIZATION_LEVEL=-Owholemodule

echo "Update $1.swiftmodule…"
MODULES_PATH="Internal/tmp/macOS$1.xcarchive/Products/usr/local/lib/$1.framework/Modules"
mkdir -p $MODULES_PATH
cp -a $BUILD_PRODUCTS_PATH/Release/$1.swiftmodule $MODULES_PATH

echo "Build and update $1.xcframework…"

rm -rf Internal/Frameworks/$1.xcframework
xcodebuild -create-xcframework \
-framework Internal/tmp/macOS$1.xcarchive/Products/usr/local/lib/$1.framework \
-output Internal/Frameworks/$1.xcframework

echo "Done!"


