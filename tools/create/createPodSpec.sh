#!/bin/bash

#此脚本用于为模块创建podspec文件

set -e

NAME=$1
CONTENTTYPE=$2

usage(){
    echo "[usage] ./createPodspec.sh [模块名] [内容类型：s|f|r]"
}

if [ -z "$NAME" ]; then
    usage
    exit
fi

if [ -z "$CONTENTTYPE" ]; then
    usage
    exit
fi

workDir=$(pwd)
modules=$(dirname $workDir)
shDir=$(dirname $0)

if [ "${modules##*/}" != "modules" ]; then
    echo "[E] 错误！请在模块目录内执行此脚本;"
    exit;
fi

FILE=$workDir/$NAME.podspec

#copy pod spec 文件
echo "[C] -> cp $shDir/template/Pods/template.podspec $FILE"
cp $shDir/template/Pods/template.podspec $FILE

# MODULENAME SUMMARY AUTHOR EMAIL PLATFORMVERSION GIT DEPENDENCY

doRead(){
    type=$1;
    echo "[Input] $2:"
    read x;
    eval $type=\"$x\";
}

replace(){
    sed -i "" "s/$1/$2/g" $FILE
}

readAndReplace(){
    TEXT=$1
    MSG=$2
    REG="$3"
    MINLIMIT=$4
    MAXLIMIT=$5
    while ((1)); do
        doRead $TEXT $MSG
        TSTR=$(eval echo \${$TEXT})
        if [ -n "$(echo $TSTR|grep -E $REG)" ];then
            COUNT=${#TSTR}
            if [ $COUNT -ge $MINLIMIT -a $COUNT -le $MAXLIMIT ]; then
                echo "[I] 输入正确：$TSTR"
                break;
            else
                echo "[I] 输入长度 $COUNT 不在 $MINLIMIT - $MAXLIMIT 范围内"
            fi
        else
            echo "[E] 输入错误，请重新输入 $TEXT $REG"
        fi
    done

    #TSTR做反斜杠替换
    replace $TEXT "$(echo $TSTR | sed -e s/\\\//\\\\\\\//g)"

    echo "[I] 已完成 ${TEXT} - "$TSTR"替换"
}

#MODULENAME
replace MODULENAME $NAME
echo "[I] 已完成 MODULENAME - "$NAME" 替换"

#SUMMARY
readAndReplace SUMMARY 输入项目描述 ^.*$ 6 30

#AUTHOR
readAndReplace AUTHOR 输入作者名字 ^.*$ 2 20

#EMAIL
readAndReplace EMAIL 输入EMAIL ^\\w+@\\w+\\.\\w\{1,10\}$ 5 40

#PLATFORMVERSION
readAndReplace PLATFORMVERSION 输入支持的iOS系统版本号 ^[0-9]\{1,2\}\\.[0-9]\{1,2\}$ 1 4

#DEPENDENCY
createPodfileArgs=
echo "[I] 接下来需要输入你依赖的项目名称及版本号，如果没有依赖，直接按回车"

dependencyStr=

while ((1)); do
    if [ -z "$pname" ]; then
        echo "[I] 请输入项目名称，直接回车表示所有依赖输入完成"
        read pname
        if [ -z "$pname" ]; then
            break;
        fi
        if [ -z "$(echo $pname | grep -E '^[a-zA-Z/]+$')" ]; then
            echo "[E] 输入项目名称错误，只支持字母，请重新输入"
            pname=
            continue
        fi
    fi

    echo "[I] 请输入版本号，直接回车表示不输入版本号"
    read pver
    if [ -z "$pver" -o -n "$(echo $pver | grep -E '^(~>)*([a-zA-Z0-9_-]+\.)*[a-zA-Z0-9_-]+$')" ]; then
        if [ -z "$pver" ]; then
            oneLineDependency="s.dependency '$pname'"
            createPodfileArgs="${createPodfileArgs} $pname"
        else
            oneLineDependency="s.dependency '$pname', '$pver'"
            createPodfileArgs="${createPodfileArgs} $pname@@$pver"
        fi
        dependencyStr="$dependencyStr$oneLineDependency; "
    else
        echo "[E] 版本号输入错误，只支持形如：3.4.5 或 ~>3.4.5的格式，不支持带空格"
        continue
    fi

    pname=
    pver=
done

replace DEPENDENCY "$(echo $dependencyStr | sed -e s/\\\//\\\\\\\//g)"
echo "[I] 已完成 DEPENDENCY 替换为 $dependencyStr"

#提供源码还是framework
case $CONTENTTYPE in
    s)
        #源码
        replace "^.*s.vendored_frameworks =.*$" ""
    ;;
    f)
        #framework
        replace "^.*s.source_files =.*$" ""
    ;;
    r)
        #资源
        replace "^.*s.vendored_frameworks =.*$" ""
        replace "^.*s.source_files =.*$" ""
    ;;
    *)
        echo "[E] CONTENTTYPE错误$CONTENTTYPE"
        exit
    ;;
esac

echo "[I] 已完成源码和framework的处理"

echo "[I] 完成Podspec文件生成，准备为 $NAME 模块生成Podfile文件"

echo "[C] -> $shDir/createPodfile.sh $NAME $workDir/ $createPodfileArgs"
$shDir/createPodfile.sh $NAME $workDir/ $createPodfileArgs
