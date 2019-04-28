#!/bin/bash

set -e

NAME=$1

#参数检查
usage(){
    echo '[usage] ./pull.sh [模块名]'
    exit
}

if [ -z "$NAME" ]; then
    usage
fi

shDir=$(cd $(dirname $0) && pwd)

if [ -d $shDir/../modules/$NAME ]; then
    echo "[E] 模块 $NAME 已经存在，无法通过脚本修改，直接去修改工程文件吧";
    exit
fi

echo "[C] -> $shDir/utils.sh $NAME giturl"
gitUrl=$($shDir/utils.sh $NAME giturl)

if [ -z "$gitUrl" ]; then
    echo "[E] 当前模块在pod库中还不存在，请使用./create.sh脚本创建新模块";
    exit
fi

#检查配置文件
echo "[C] -> $shDir/utils.sh checkconfigs"
$shDir/utils.sh checkconfigs

#添加podrepo
echo "[C] -> $shDir/utils.sh addpodrepo"
$shDir/utils.sh addpodrepo

modulesDir=$shDir/../modules

if [ ! -d $modulesDir ]; then
    echo "[C] -> mkdir -p $modulesDir"
    mkdir -p $modulesDir
fi

#clone代码
echo "[C] -> pushd $modulesDir >/dev/null"
pushd $modulesDir >/dev/null
    echo "[C] -> git clone $gitUrl $NAME"
    git clone $gitUrl $NAME
    echo "[C] -> pushd $NAME >/dev/null"
    pushd $NAME >/dev/null
        echo "[C] -> git checkout develop"
        git checkout develop
    echo "[C] -> popd>/dev/null"
    popd>/dev/null
echo "[C] -> popd>/dev/null"
popd>/dev/null

#准备处理依赖，依赖保存在dependency.txt文件中
echo "[C] -> pushd $modulesDir/$NAME >/dev/null"
pushd $modulesDir/$NAME >/dev/null
dependencyFile=$modulesDir/$NAME/dependency.txt
if [ -f $dependencyFile ]; then
    echo "[C] -> cat $dependencyFile | while read line;"
    cat $dependencyFile | while read line;
    do
        #取@@前的部分
        name=${i%@@*}
        #取@@后的部分
        ver=${i#*@@}
        
        #判断是否是本地模块或者git模块
        echo "[C] -> $shDir/utils.sh $name islocal"
        isLocal="$($shDir/utils.sh $name islocal)"
        echo "[C] -> $shDir/utils.sh $name giturl"
        gitUrl="$($shDir/utils.sh $name giturl)"

        if [ -n "$gitUrl" ]; then
            echo "[I] 准备下载依赖模块 $name ..."
            echo "[C] -> $shDir/utils.sh $name clone"
            $shDir/utils.sh $name clone
            echo "[C] -> pushd $modulesDir/$name >/dev/null"
            pushd $modulesDir/$name >/dev/null
                echo "[C] -> git checkout $ver"
                git checkout $ver
            echo "[C] -> popd >/dev/null"
            popd >/dev/null
        elif [ -n "$isLocal" ]; then
            echo "[I] 准备更新依赖模块 $name ..."
            echo "[C] -> pushd $modulesDir/$name >/dev/null"
            pushd $modulesDir/$name >/dev/null
                echo "[C] -> git reset --hard"
                git reset --hard
                echo "[C] -> git pull && git fetch"
                git pull && git fetch
                echo "[C] -> git checkout $ver"
                git checkout $ver
            echo "[C] -> popd >/dev/null"
            popd >/dev/null
        else
            echo "[W] 工程可能出现了问题，请仔细检查一下"
        fi
    done
else
    echo "[W] 工程根目录没有找到dependency.txt文件，可能没有依赖，也可能有错误，请仔细检查工程"
fi

#安装podfile
echo "[I] 准备安装pod依赖..."
echo "[C] -> pod install"
pod install

#打开工程
echo "[C] -> open ./$NAME.xcworkspace"
open ./$NAME.xcworkspace

echo "[C] -> popd >/dev/null"
popd >/dev/null

echo "[I] 完成";