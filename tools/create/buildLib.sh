#!/bin/bash

#此脚本用于将模块打包成静态库，提供真机和模拟器支持
set -e

NAME=$1
CONFIGURATION=$2
HASSIMULATOR=$3

#参数检查
usage(){
    echo "[U] usage ./buildLib.sh [模块名] [Debug|Release] [是否包含模拟器：可空]";
}

if [ -z "$NAME" -o -z "$CONFIGURATION" ]; then
    usage
    exit
fi

if [ $CONFIGURATION != "Debug" -a $CONFIGURATION != "Release" ]; then
    usage
    exit
fi

#获取工作目录
shDir=$(cd $(dirname $0) && pwd)
workDir=$shDir/../.build
rm -rf $workDir
mkdir $workDir

echo "[I] 已完成创建工作目录 $workDir"

deviceDir=$workDir/$CONFIGURATION-iphoneos
simulatorDir=$workDir/$CONFIGURATION-iphonesimulator

#进入工程目录
echo "[C] -> pushd $shDir/../../modules/$NAME >/dev/null"
pushd $shDir/../../modules/$NAME >/dev/null

echo "[I] 已进入工作目录$(pwd) 即将开始xcodebuild device"

#创建frameworks
echo "[C] -> xcodebuild -target $NAME \
-configuration $CONFIGURATION \
-sdk iphoneos ONLY_ACTIVE_ARCH=NO \
BUILD_DIR=$workDir"
xcodebuild -target $NAME \
-configuration $CONFIGURATION \
-sdk iphoneos ONLY_ACTIVE_ARCH=NO \
BUILD_DIR=$workDir
#-UseModernBuildSystem=NO

echo "[I] xcodebuild device 完成"

if [ -n "$HASSIMULATOR" ]; then
    echo "[I] 即将开始 xcodebuild simulator"
    echo "[C] -> xcodebuild -target $NAME \
    -configuration $CONFIGURATION \
    -arch x86_64 \
    -sdk iphonesimulator \
    BUILD_DIR=$workDir "
    xcodebuild -target $NAME \
    -configuration $CONFIGURATION \
    -arch x86_64 \
    -sdk iphonesimulator \
    BUILD_DIR=$workDir 
#   -UseModernBuildSystem=NO
    echo "[C] -> cp -r $deviceDir/$NAME.framework $workDir/$NAME.framework"
    cp -r $deviceDir/$NAME.framework $workDir/$NAME.framework
    echo "[I] xcodebuild simulator完成"
    echo "[I] 准备合并 device 与 simulator 2个版本的framework";
    #合并
    echo "[C] -> lipo -create -output $workDir/$NAME.framework/$NAME $deviceDir/$NAME.framework/$NAME $simulatorDir/$NAME.framework/$NAME"
    lipo -create -output $workDir/$NAME.framework/$NAME $deviceDir/$NAME.framework/$NAME $simulatorDir/$NAME.framework/$NAME
    echo "[I] 完成合并";
else
    echo "[C] -> cp -r $deviceDir/$NAME.framework $workDir/"
    cp -r $deviceDir/$NAME.framework $workDir/
fi

#退出工程目录
echo "[C] -> popd >/dev/null"
popd >/dev/null

echo "[I] 已完成xcodebuild 并回到工作目录 $workdir"

#移除framework中的资源文件
needRemoveFile(){
    file=$1
    exts=("nib" "png" "jpg" "jpeg" "gif" "txt" "plist" "bundle" "zip" "car")
    for i in ${exts[*]}
    do
        needRemove=$(echo $file | grep -E "^.+\.$i$");
        isInfoPlist=$(echo $file | grep -E "^.*Info\.plist$");
        if [ -n "$needRemove" -a -z "$isInfoPlist" ]; then
            echo 1
        fi
    done
}

echo "[I] 准备移除framework中的资源文件"
for f in $workDir/$NAME.framework/*
do
    echo "[C] -> needRemoveFile $f"
    r=$(needRemoveFile $f)
    if [ -n "$r" ]; then
        echo "[I] 移除framework中的资源文件 $f"
        echo "[C] -> rm -rf $f"
        rm -rf $f
    fi
done
echo "[I] 已完成移除资源文件"

#copy到目标目录
outdir=$shDir/../../modules/$NAME/frameworks
echo "[I] 准备将生成的framework文件copy到模块目录 $outdir"
if [ -d $outdir ]; then
    echo "[C] -> rm -rf $outdir"
    rm -rf $outdir
fi
echo "[C] -> mkdir -p $outdir"
mkdir -p $outdir
echo "[C] -> cp -r $workDir/$NAME.framework $outdir/"
cp -r $workDir/$NAME.framework $outdir/

#移除module目录生成的build目录
echo "[C] -> rm -rf $shDir/../../modules/$NAME/build"
rm -rf $shDir/../../modules/$NAME/build

echo "[I] 完成创建framework 文件已输出为：$outdir/$NAME.framework"
