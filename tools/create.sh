#!/bin/bash

set -e

#安装依赖
if [ -z "$(gem)" ]; then
    echo "[E] 需要先安装ruby环境"
    exit;
fi

if [ -z "$(pod)" ]; then
    echo "[E] 需要先安装pod"
    exit;
fi

usage(){
    echo "[U]./create.sh -n=[模块名称] -b=[bundleid] -t=[s|f|r]
    -n 模块名
    -b bundleid
    -t 表示framework的内容类型，s表示src，f表示framework，r表示纯资源
    -h 打印用法
    "
}

#检查参数
for i in $@;
do
    case $i in
        -n=*)
            NAME=${i#*=}
        ;;
        -b=*)
            BUNDLEID=${i#*=};
        ;;
        -t=*)
            CONTENTTYPE=${i#*=};
        ;;
        -h)
            usage
            exit
        ;;
        *)
            usage
            exit
        ;;
    esac
done

echo "[I] NAME = $NAME"
echo "[I] BUNDLEID = $BUNDLEID"
echo "[I] CONTENTTYPE = $CONTENTTYPE"

if [ -z "$NAME" ]; then
    echo "[E][-n=工程名]不能为空"
    usage
    exit
fi

if [ -z "$BUNDLEID" ]; then
    echo "[E][-b=bundleid]不能为空"
    usage
    exit
fi

if [ -z "$CONTENTTYPE" ]; then
    echo "[E][-t=CONTENTTYPE] 不能为空"
    usage
    exit;
fi

case $CONTENTTYPE in
    s)
        echo "[I] 库的内容类型为源码"
    ;;
    f)
        echo "[I] 库的内容类型为framework"
    ;;
    r)
        echo "[I] 库的内容类型为resource"
    ;;
    *)
        echo "[E] [-t=CONTENTTYPE]只能为's','f','r'这3种"
        usage
        exit
    ;;
esac

#获取工作目录
shDir=$(cd $(dirname $0) && pwd)

#检查配置文件
echo "[C] -> $shDir/utils.sh checkconfigs"
$shDir/utils.sh checkconfigs

#添加 pod repo
echo "[C] -> $shDir/utils.sh addpodrepo"
$shDir/utils.sh addpodrepo

#创建目录
baseDir=$shDir/../modules
createDir=$shDir/create

if [ ! -d $baseDir ]; then
    echo "[C] -> mkdir $baseDir"
    mkdir $baseDir;
fi

#检查本地模块是否存在
if [ -d $baseDir/$NAME ]; then
    echo "[E]本地已经有了名为 $NAME 的模块，请换个名字再试试"
    exit
fi

#检查依赖工具是否安装
if [ -z "$(gem list '^xcodeproj$')" ]; then
    #安装Xcodeproj
    echo "[C] -> gem install xcodeproj"
    gem install xcodeproj
fi

if [ -z "$(gem list '^json$')" ]; then
    #安装json
    echo "[C] -> gem install json"
    gem install json
fi

#检查远端模块是否存在
echo "[C] -> $shDir/utils.sh $NAME giturl"
gitUrl="$($shDir/utils.sh $NAME giturl)"
if [ -n "$gitUrl" ];then
    echo "[E]模块 $NAME 已经在git里面存在，请换个名字再试试"
    exit
fi
echo "[I] 模块名输入正确"

#创建工程目录
moduleDir=$baseDir/$NAME
echo "[I] 准备创建目录$moduleDir"
if [ -d $moduleDir ]; then
    echo "[C] -> rm -rf $moduleDir"
    rm -rf $moduleDir
fi
echo "[C] -> mkdir $moduleDir"
mkdir $moduleDir
echo "[I] 创建目录成功$moduleDir"

echo "[C] -> pushd $moduleDir >/dev/null"
pushd $moduleDir >/dev/null

#创建proj
echo "[I]准备创建.xcodeproj文件..."
echo "[C] -> $createDir/createProj.rb $NAME $BUNDLEID"
ruby $createDir/createProj.rb $NAME $BUNDLEID

echo "[I].xcodeproj文件创建完成，准备copy模板文件..."

#动态库copy文件
#copy main target文件
echo "[C] -> cp -r $createDir/template/ModuleLib/Main ./$NAME"
cp -r $createDir/template/ModuleLib/Main ./$NAME
#copy test target文件
echo "[C] -> cp -r $createDir/template/ModuleLib/Tests ./${NAME}Tests"
cp -r $createDir/template/ModuleLib/Tests ./${NAME}Tests
#修改test文件名类名
theTestFile=./${NAME}Tests/${NAME}Tests.swift
echo "[C] -> mv ./${NAME}Tests/Tests.swift $theTestFile"
mv ./${NAME}Tests/Tests.swift $theTestFile
#修改umbrella.h文件的名字
echo "[C] -> mv ./${NAME}/ModuleUmbrella.h ./${NAME}/${NAME}.h"
mv ./${NAME}/ModuleUmbrella.h ./${NAME}/${NAME}.h
#类名替换
echo "[C] -> sed -i \"\" \"s/Tests/${NAME}Tests/g\" $theTestFile"
sed -i "" "s/Tests/${NAME}Tests/g" $theTestFile
echo "[C] -> sed -i \"\" \"s/@testable import .*/@testable import ${NAME}/g\" $theTestFile"
sed -i "" "s/@testable import .*/@testable import ${NAME}/g" $theTestFile

#Demo复制文件
#copy main target文件
echo "[C] -> cp -r $createDir/template/Demo/Main ./Demo/${NAME}Demo"
cp -r $createDir/template/Demo/Main ./Demo/${NAME}Demo
#copy test target文件
echo "[C] -> cp -r $createDir/template/Demo/Tests ./Demo/${NAME}DemoTests"
cp -r $createDir/template/Demo/Tests ./Demo/${NAME}DemoTests
#修改test文件名类名
theTestFile=./Demo/${NAME}DemoTests/${NAME}DemoTests.swift
echo "[C] -> mv ./Demo/${NAME}DemoTests/Tests.swift $theTestFile"
mv ./Demo/${NAME}DemoTests/Tests.swift $theTestFile
#类名替换
echo "[C] -> sed -i \"\" \"s/Tests/${NAME}DemoTests/g\" $theTestFile"
sed -i "" "s/Tests/${NAME}DemoTests/g" $theTestFile
echo "[C] -> sed -i \"\" \"s/@testable import .*//g\" $theTestFile"
sed -i "" "s/@testable import .*//g" $theTestFile
echo "[C] -> sed -i \"\" \"s/#replace#/$NAME/g\" ./Demo/${NAME}Demo/ViewController.swift"
sed -i "" "s/#replace#/$NAME/g" ./Demo/${NAME}Demo/ViewController.swift

#copy gitignore文件
echo "[C] -> cp $createDir/template/Git/gitignore ./.gitignore"
cp $createDir/template/Git/gitignore ./.gitignore

#创建.xcworkspace文件
echo "[C] -> cp -r $createDir/template/template.xcworkspace ./$NAME.xcworkspace"
cp -r $createDir/template/template.xcworkspace ./$NAME.xcworkspace
echo "[C] -> sed -i \"\" \"s/#replace#/\
    <FileRef\
        location = \"group:$NAME.xcodeproj\">\
    <\/FileRef>\
    <FileRef\
        location = \"group:Demo\/${NAME}Demo.xcodeproj\">\
    <\/FileRef>\
/g\" ./$NAME.xcworkspace/contents.xcworkspacedata"
sed -i "" "s/#replace#/\
    <FileRef\
        location = \"group:$NAME.xcodeproj\">\
    <\/FileRef>\
    <FileRef\
        location = \"group:Demo\/${NAME}Demo.xcodeproj\">\
    <\/FileRef>\
/g" ./$NAME.xcworkspace/contents.xcworkspacedata

#创建PodSpec，Podfile文件
echo "[I]开始创建PodSpec文件..."
echo "[C] -> $createDir/createPodSpec.sh $NAME $CONTENTTYPE"
$createDir/createPodSpec.sh "$NAME" "$CONTENTTYPE"

#copy Resource info plist文件
echo "[C] -> cp $createDir/template/Resources/Info.plist ./Demo/${NAME}Demo/Supporting\ Files/ResourceInfo.plist"
cp $createDir/template/Resources/Info.plist ./Demo/${NAME}Demo/Supporting\ Files/ResourceInfo.plist

#执行pod install
echo "[C] -> pod install"
pod install

#打开工程
echo "[C] -> open ./$NAME.xcworkspace"
open ./$NAME.xcworkspace

echo "[C] -> popd"
popd

echo "[I]完成"
