#!/bin/bash

#判断模块是本地模块还是在git上的模块，并提供clone方法
set +e

NAME=$1

usage(){
    echo "[U] usage ./utils.sh [NAME] [islocal|giturl|clone|git2http|addmoduleurl|modulelist|removemodulelist|printmodulelist|removemodule|checkconfigs|addpodrepo|upgradedependency] [其他选项...]
    [options]
    islocal 模块是否在本地
    giturl 获取模块的git地址
    clone 下载模块代码
    git2http 将模块的git@xxxx地址转换为https://地址
    addmoduleurl 将模块及url加入到modle list json的git库中
    modulelist 返回 module list json的内容
    removemodulelist 将模块从module list json中移除
    printmodulelist 打印 module list json的内容
    removemodule 移除module：删除本地目录；从module list json中移除；从pod私有库中移除模块
    checkconfigs 检查config文件是否正确
    addpodrepo 执行pod repo add 命令，将pod私有库添加到本地
    upgradedependency 为模块的某个依赖模块增加版本号
    "
}

# 参数数量要大于1
if [ $# -lt 1 ]; then
    usage 
    exit
fi

shDir=$(cd $(dirname $0) && pwd)

#判断是否是本地模块
isLocalModule(){
    if [ -d $shDir/../modules/$1 ]; then
        echo 1
    fi
}

#获取moduleListJsonFile
moduleListJson(){
    if [ ! -d $shDir/config/modulelistgitaddress ]; then
        $(git clone "$(echo $(cat $shDir/config/modulelistgitaddress.txt))" $shDir/config/modulelistgitaddress)
    fi
    moduleListFile=$shDir/config/modulelistgitaddress/moduleList.json
    if [ -f $moduleListFile ]; then
        content=$(cat $moduleListFile)
        echo $content
    fi
}

#判断是否是自建模块并获取giturl
moduleGitUrl(){
    jsonContent=$(moduleListJson)

    pushd $shDir/config/modulelistgitaddress >/dev/null
    git pull origin master >/dev/null
    popd >/dev/null

    jsonContent=$(moduleListJson)

    if [ -n "$jsonContent" ]; then
        gitUrl=$(ruby $shDir/git/jsonhelper.rb "$jsonContent" get $1)

        echo "$gitUrl";
    else
        echo "{}" > $shDir/config/modulelistgitaddress/moduleList.json
        pushd $shDir/config/modulelistgitaddress >/dev/null
            git add . >/dev/null
            git commit -am "[PACKAGE] AUTO CODE FOR COMMIT config/modulelistgitaddress/moduleList.json" >/dev/null
            git push origin master >/dev/null
        popd >/dev/null
    fi
}

addModuleAndUrl(){
    existsUrl=$(moduleGitUrl $1)
    if [ -z "$existsUrl" ]; then
        pushd $shDir/../modules/$1 >/dev/null
            url=$(git remote get-url --push origin)
            if [ -n "$url" ]; then
                if [ -n "$url" ]; then
                    jsonContent=$(moduleListJson)
                    if [ -n "$jsonContent" ]; then
                        newJson=$(ruby $shDir/git/jsonhelper.rb "$jsonContent" set $1 $url)
                        echo $newJson > $shDir/config/modulelistgitaddress/moduleList.json
                        pushd $shDir/config/modulelistgitaddress >/dev/null
                            git commit -am "[PACKAGE] AUTO PUSH MODULE LIST JSON CONTENT" > /dev/null
                            git push origin master > /dev/null
                            echo 1
                        popd >/dev/null
                    fi
                fi
            fi
        popd >/dev/null
    fi
}

removeModuleInList(){
    existsUrl=$(moduleGitUrl $1)
    if [ -n "$existsUrl" ]; then
        jsonContent=$(moduleListJson)
        if [ -n "$jsonContent" ]; then
            newJson=$(ruby $shDir/git/jsonhelper.rb "$jsonContent" set $1)
            echo oldJson=$jsonContent newJson=$newJson
            echo $newJson > $shDir/config/modulelistgitaddress/moduleList.json
            pushd $shDir/config/modulelistgitaddress >/dev/null
                git commit -am "[PACKAGE] AUTO PUSH MODULE LIST JSON CONTENT" > /dev/null
                git push origin master > /dev/null
                echo 1
            popd >/dev/null
        fi
    fi
}

#若模块在git上有，在本地没有，则下载它
cloneModule(){
    isLocal="$(isLocalModule $1)"
    if [ -z "$isLocal" ]; then
        gitUrl="$(moduleGitUrl $1)"
        if [ -n "$gitUrl" ]; then
            $(git clone $gitUrl $shDir/../modules/$1)
            $(cd $shDir/../modules/$1 && pod install)
            echo 1
        fi
    fi
}

#gitUrl2HttpUrl
gitUrl2HttpUrl(){
    l=$(isLocalModule $1);
    if [ -n "$l" ];then
        if [ -d $shDir/../modules/$1/.git ];then
            pushd $shDir/../modules/$1 >/dev/null
                gitUrl=$(git remote get-url --push origin)
                if [ -n "$gitUrl" ]; then
                    reg=$(cat $shDir/config/sshurl2httpurlreg.txt)
                    url="$(echo $gitUrl | eval $reg)";
                    if [ -n "$url" ]; then
                        echo $url
                    fi
                fi
            popd >/dev/null
        fi
    fi
}

#移除module
removeModule(){
    name=$1
    dir=$shDir/../modules/$name
    #移除本地目录
    echo "[I] 准备移除本地目录 $name"
    if [ -d $dir ]; then
        rm -rf $dir
    fi
    echo "[I] 完成移除本地目录"
    #移除modulelistjson
    echo "[I] 准备移除modulelistjson"
    removeModuleInList $name
    echo "[I] 完成移除modulelistjson"
    #移除podspec
    podspecDir=~/.cocoapods/repos/$(cat $shDir/config/podspecsname.txt)
    echo "[I] 准备移除podspec的内容 $podspecDir"
    if [ -d "$podspecDir" ]; then
        pushd $podspecDir
            rm -rf $name
            git add .
            git commit -am "[Update] use utils.sh remove module $name"
            git push
        popd
    fi
    echo "[I] 完成移除podspec的内容"
}

#检查配置文件是否正确
checkConfigs(){
    cfgDir=$shDir/config
    #检查modulelistgitaddress.txt
    modulelistgitaddress=$(cat $cfgDir/modulelistgitaddress.txt)
    valid=$(echo $modulelistgitaddress | grep -E "^git@.+\.git$");
    if [ -z "$valid" ]; then
        echo "[E] checkConfigs modulelistgitaddress $cfgDir/modulelistgitaddress.txt的内容应该是一个 形如'^git@.+\.git$'的git地址，记录了当前push到私有库中的所有模块的一个git库"
        return 1
    else
        echo "[I] checkConfigs modulelistgitaddress 内容正确：$modulelistgitaddress";
    fi

    #检查podspecsaddr.txt
    podspecsaddr=$(cat $cfgDir/podspecsaddr.txt)
    valid=$(echo $podspecsaddr | grep -E "^git@.+\.git$");
    if [ -z "$valid" ]; then
        echo "[E] checkConfigs podspecsaddr $cfgDir/podspecsaddr.txt的内容应该是一个 形如'^git@.+\.git$'的git地址，表示pod repo的地址"
        return 2
    else
        echo "[I] checkConfigs podspecsaddr 内容正确：$podspecsaddr";
    fi

    #检查podspecsnam
    podspecsname=$(cat $cfgDir/podspecsname.txt)
    valid=$(echo $podspecsname | grep -E "^[A-Za-z][A-Za-z0-9_]+$");
    if [ -z "$valid" ]; then
        echo "[E] checkConfigs podspecsname $cfgDir/podspecsname.txt的内容应该是一个 形如'^[A-Za-z][A-Za-z0-9_]+$'的名字，表示pod repo的名字"
        return 3
    else
        echo "[I] checkConfigs podspecsname 内容正确：$podspecsname";
    fi

    return 0
}

addPodRepo(){
    #获取podspecs
    podspecsaddr="$(cat $shDir/config/podspecsaddr.txt)"
    podspecsname="$(cat $shDir/config/podspecsname.txt)"

    #添加pod
    echo "[I] pod repo add $podspecsname $podspecsaddr"
    echo "[I]检查pod repo是否存在"
    podexists=$(pod repo list | grep -E $podspecsname)
    if [ -z "$podexists" ]; then
        echo "[I]pod repo不存在准备添加"
        pod repo add $podspecsname $podspecsaddr
    else
        echo "[W]pod repo已存在，注意如果是你第一次执行./create.sh命令，那么可能出错了，检查 $shDir/../config/podspecsname.txt 文件是否与本地已存在的pod repo有重名的情况"
    fi
}

upgradeDependency(){
    name=$1
    dName=$2
    dVer=$3
    echo "[I] 模块名：$name 依赖模块：$dName 依赖版本: $dVer"
    moduleDir=$shDir/../modules/$name
    if [ ! -d $moduleDir ]; then
        echo "[C] -> cloneModule $name"
        cloneModule $name
    fi
    if [ ! -d $moduleDir ]; then
        echo "[E] 模块不存在 $name"
        exit
    fi
    pushd $moduleDir > /dev/null

    #判断是否是自建模块，自建模块才会出现在dependency.txt中
    echo "[C] -> isLocalModule $dName"
    isLocal="$(isLocalModule $dName)"
    if [ -z "$isLocal" ]; then
        echo "[C] moduleGitUrl $dName"
        gitUrl="$(moduleGitUrl $dName)"
    fi

    if [ -n "$isLocal" -o -n "$gitUrl" ]; then
        #查找dependency.txt，没有则新建
        if [ -n "$dVer" ]; then
            newDep=$dName@@$dVer
        else
            newDep=$dName
        fi
        dependencyTxt=$moduleDir/dependency.txt
        echo "[C] touch $dependencyTxt"
        touch $dependencyTxt
        echo "[C] cat $dependencyTxt | grep -E \"^$dName$\""
        noVerExists=$(cat $dependencyTxt | grep -E "^$dName$");
        echo "[C] cat $dependencyTxt | grep -E \"^$dName@@(~>)*[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)*$\""
        hasVerExists=$(cat $dependencyTxt | grep -E "^$dName@@(~>)*[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)*$")
        echo dependency.txt noVerExists = $noVerExists
        echo dependency.txt hasVerExists = $hasVerExists
        if [ -n "$noVerExists" ]; then
            #存在则修改版本号
            echo "[C] sed -i \"\" \"s/^$dName$/$newDep/g\" $dependencyTxt"
            sed -i "" "s/^$dName$/$newDep/g" $dependencyTxt
        elif [ -n "$hasVerExists" ]; then
            echo "[C] sed -i \"\" \"s/^$dName@@\(~>\)*[a-zA-Z0-9_-]*\(\.[a-zA-Z0-9_-]*\)*$/$newDep/g\" $dependencyTxt"
            sed -i "" "s/^$dName@@\(~>\)*[a-zA-Z0-9_-]*\(\.[a-zA-Z0-9_-]*\)*$/$newDep/g" $dependencyTxt
        else
            #不存在则添加
            echo "[C] echo $newDep >> $dependencyTxt"
            echo $newDep >> $dependencyTxt
        fi
    fi

    #查找podspec文件
    podspecFile=$moduleDir/$name.podspec
    echo "[C] cat $podspecFile | grep -E \"'$dName'\s*;\""
    noVerExists=$(cat $podspecFile | grep -E "'$dName'\s*;")
    echo "[C] cat $podspecFile | grep -E \"'$dName',\s*'(~>)*[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)*'\""
    hasVerExists=$(cat $podspecFile | grep -E "'$dName',\s*'(~>)*[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)*'")
    echo .podspec noVerExists = $noVerExists
    echo .podspec hasVerExists = $hasVerExists
    if [ -n "$dVer" ]; then
        newDep="'$dName', '$dVer'"
    else
        newDep="'$dName'"
    fi
    if [ -n "$noVerExists" ]; then
        #没有依赖版本号
        echo "[C] sed -i \"\" \"s/'$dName'/$newDep/g\" $podspecFile"
        sed -i "" "s/'$dName'/$newDep/g" $podspecFile
    elif [ -n "$hasVerExists" ]; then
        #存在，修改版本号
        echo "[C] sed -i \"\" \"s/'$dName', '\(~>\)*[a-zA-Z0-9_-]*\(\.[a-zA-Z0-9_-]*\)*'/$newDep/g\" $podspecFile"
        sed -i "" "s/'$dName', '\(~>\)*[a-zA-Z0-9_-]*\(\.[a-zA-Z0-9_-]*\)*'/$newDep/g" $podspecFile
    else
        #不存在，直接插入
        echo "[C] sed -i \"\" \"s/\(.*s.dependency.*\)/\1 s.dependency $newDep;/g\" $podspecFile"
        sed -i "" "s/\(.*s.dependency.*\)/\1 s.dependency $newDep;/g" $podspecFile
    fi

    popd > /dev/null
    echo "[I] 完成"
}

for i in $@
do
    if [ "$i" != "modulelist" -a "$i" != "printmodulelist" -a "$i" != "checkconfigs" -a "$i" != "addpodrepo" -a "$i" != "upgradedependency" ];then
        if [ "$i" == "$NAME" ]; then
            continue
        fi
        if [ $# -lt 2 ]; then
            usage 
            exit
        fi
    fi
    case $i in
        islocal) # 是否在本地已经存在了模块
            isLocalModule $NAME
        ;;
        giturl) # 获取模块的giturl
            moduleGitUrl $NAME
        ;;
        clone) # clone 模块到modules/目录
            cloneModule $NAME
        ;;
        git2http) # 将 ssh@xxx 类型的地址转换成 http://xxx
            gitUrl2HttpUrl $NAME
        ;;
        addmoduleurl) # 记录确认添加到pod中的模块
            addModuleAndUrl $NAME
        ;;
        modulelist) # 获取当前的modulelist内容
            moduleListJson
        ;;
        removemodulelist)
            removeModuleInList $NAME
        ;;
        printmodulelist) # 打印modulelist列表
            jsonContent=$(moduleListJson)
            if [ -n "$jsonContent" ]; then
                ruby $shDir/git/jsonhelper.rb "$jsonContent" print
            else
                echo "module list 为空"
            fi
        ;;
        removemodule) # 删除 module目录；删除moduleListJson中的内容；删除podspec中的内容
            removeModule $NAME
        ;;
        checkconfigs) # 检查配置文件是否正确
            checkConfigs
        ;;
        addpodrepo) # 添加pod私有库
            addPodRepo
        ;;
        upgradedependency) # 升版本号
            dependencyName=$3
            dependencyVer=$4
            if [ $# -lt 3 -o -z "$NAME" -o -z "$dependencyName" ]; then
                echo "[usage] ./utils.sh [模块名] upgradedependency [依赖模块名] [依赖模块新版本号]"
                exit
            fi
            upgradeDependency $NAME $dependencyName $dependencyVer
            exit
        ;;
        *)
            usage
            exit
        ;;
    esac
done
