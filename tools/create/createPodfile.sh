#!/bin/bash

#此脚本用于生成Podfile文件

set -e

NAME=$1
DIR=$2

usage(){
    echo "[U] usage: ./createPodfile.sh [moduleName] [PodfileDir] [Dependency libs ...]"
}

if [ -z "$NAME" ]; then
    usage
    exit
fi

if [ ! -d $DIR ]; then
    usage
    exit
fi

#获取工作目录
shDir=$(cd $(dirname $0) && pwd)
workDir=$shDir/../../modules/$NAME

#开始拼接文件内容
CONTENT="inhibit_all_warnings!\n
\n
workspace '$NAME.xcworkspace'\n
\n
"
echo "[C] -> cat $shDir/../config/dependencypodrepos.txt"
dependencyPodRepos=$(cat $shDir/../config/dependencypodrepos.txt)

if [ -n "$dependencyPodRepos" ];then
    for oneRepo in $dependencyPodRepos;
    do
        echo "[C] -> echo $oneRepo | grep -E '(^git@.+\.git$)|(^http(s)*://.+\.git$)'"
        valid=$(echo $oneRepo | grep -E '(^git@.+\.git$)|(^http(s)*://.+\.git$)')
        if [ -n "$valid" ]; then
            CONTENT="${CONTENT}source '${oneRepo}'\n"
        fi
    done
fi

#添加pod repo source
CONTENT="$CONTENT source '$(cat $shDir/../config/podspecsaddr.txt)'\n"

#使用modular headers
CONTENT="${CONTENT}use_modular_headers!\n"

#处理依赖
if [ $# -gt 2 ]; then
    CONTENT="${CONTENT}target '$NAME' do \n"

    MODULECONTENT=

    dependencyFile=$workDir/dependency.txt

    c=0
    for i in $@;
    do
        #过滤掉NAME
        if [ "$i" == "$NAME" ]; then
            if [ $c -gt 1 ]; then
                echo "[E]依赖模块与当前模块重名，也就是依赖自身"
                exit
            fi
            c=$(($c+1))
            continue
        fi

        #过滤掉DIR
        if [ "$i" == "$DIR" ]; then
            continue
        fi

        #取@@前的部分
        name=${i%@@*}
        #取@@后的部分
        ver=${i#*@@}

        #判断是否是本地模块或者git模块
        echo "[C] -> $shDir/../utils.sh $name islocal"
        isLocal="$($shDir/../utils.sh $name islocal)"
        echo "[C] -> $shDir/../utils.sh $name giturl"
        gitUrl="$($shDir/../utils.sh $name giturl)"

        #本地模块
        if [ -n "$isLocal" ]; then
            #保存依赖
            echo "[C] -> echo $i >> $dependencyFile"
            echo $i >> $dependencyFile
            #连接内容
            MODULECONTENT="$MODULECONTENT\tpod '$name', :path => '$shDir/../../modules/$name'\n"
            #git pull
            localModuleDir=$shDir/../../modules/$name
            echo "[C] -> pushd $localModuleDir >/dev/null"
            pushd $localModuleDir >/dev/null
            if [ -d ./.git ]; then
                echo "[C] -> git remote get-url origin"
                remoteUrl=$(git remote get-url origin)
                if [ -n "$remoteUrl" ]; then
                    echo "[C] -> git pull && git fetch"
                    git pull && git fetch
                fi
            fi
            echo "[C] -> popd >/dev/null"
            popd >/dev/null
            #切分支
            if [ "$name" != "$ver" ]; then
                echo "[C] -> echo $ver | sed -e \"s/~>//g\""
                ver="$(echo "$ver" | sed -e "s/~>//g")"
                echo "[C] -> pushd $shDir/../../modules/$name >/dev/null"
                pushd $shDir/../../modules/$name >/dev/null
                echo "[C] -> git checkout $ver"
                git checkout $ver
                echo "[C] -> popd >/dev/null"
                popd >/dev/null
            fi
        elif [ -n "$gitUrl" ]; then
            #保存依赖
            echo "[C] -> echo $i >> $dependencyFile"
            echo $i >> $dependencyFile
            #连接内容
            MODULECONTENT="$MODULECONTENT\tpod '$name', :path => '$shDir/../../modules/$name'\n"
            #下载git
            echo "[C] -> $shDir/../utils.sh $name clone"
            $shDir/../utils.sh $name clone
            #切分支
            echo "[C] -> pushd $shDir/../../modules/$name >/dev/null"
            pushd $shDir/../../modules/$name >/dev/null
            if [ "$name" != "$ver" ]; then
                echo "[C] -> echo $ver | sed -e \"s/~>//g\""
                ver="$(echo "$ver" | sed -e "s/~>//g")"
                echo "[C] -> git checkout $ver"
                git checkout $ver
            else
                echo "[C] -> git checkout develop"
                git checkout develop
            fi
            echo "[C] -> popd >/dev/null"
            popd >/dev/null
        elif [ "$name" != "$ver" ]; then
            MODULECONTENT="$MODULECONTENT\tpod '$name', '$ver'\n"
        else
            MODULECONTENT="$MODULECONTENT\tpod '$name'\n"
        fi
    done

    CONTENT="${CONTENT}${MODULECONTENT}
    end\n
    "

    #moduleDemo target
    CONTENT="${CONTENT}target '${NAME}Demo' do\n
    \tproject 'Demo/${NAME}Demo.xcodeproj'\n
    ${MODULECONTENT}
    end\n
    "
fi

#moduleTest target
CONTENT="${CONTENT}target '${NAME}Tests' do\n
\tinherit! :search_paths\n
\tpod 'Quick'\n
\tpod 'Nimble'\n
end\n
"

#demoTest target
CONTENT="${CONTENT}target '${NAME}DemoTests' do\n
\tinherit! :search_paths\n
\tproject 'Demo/${NAME}Demo.xcodeproj'\n
\tpod 'Quick'\n
\tpod 'Nimble'\n
end\n
"

#将拼接好的内容输出到Podfile中
echo "[C] -> echo -e $CONTENT > $DIR/Podfile"
echo -e $CONTENT > $DIR/Podfile

echo "[I] $DIR/Podfile 创建完成"
