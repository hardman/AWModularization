#!/bin/bash

#开发完了准备提交了
set -e

NAME=$1
TAG=$2

usage(){
    echo '[usage] ./push.sh [模块名] [git tag]'
    exit
}

#检查参数
if [ -z "$NAME" ]; then
    usage
fi

if [ -z "$TAG" ]; then
    usage
fi

echo "[C] -> echo $TAG | grep -E \"^[0-9](\.[0-9]+)*$\""
validTag=$(echo $TAG | grep -E "^[0-9](\.[0-9]+)*$")

if [ -z "$validTag" ];then
    echo "[E] 输入的tag格式不对，请输入类似: 1.2.3 的tag"
    exit
fi

#获取相关工作目录
echo "[C] -> cd $(dirname $0) && pwd"
shDir="$(cd $(dirname $0) && pwd)"
moduleDir=$shDir/../modules/$NAME

#检查配置文件
echo "[C] -> $shDir/utils.sh checkconfigs"
$shDir/utils.sh checkconfigs

#添加podrepo
echo "[C] -> $shDir/utils.sh addpodrepo"
$shDir/utils.sh addpodrepo

#检查模块目录是否存在
if [ ! -d $moduleDir ]; then
    echo "[E] 模块 $NAME 不存在"
    exit
fi

#查看是否有git
if [ ! -d $moduleDir/.git ]; then
    echo "[E] 请先将工程提交至git再执行脚本"
    exit
fi

echo "[C] -> cd $moduleDir && git remote get-url --push origin"
gitUrl=$(cd $moduleDir && git remote get-url --push origin)
if [ -z "$gitUrl" ];then
    echo "[E] 请将工程push至git服务器再执行脚本"
    exit
fi

echo "[C] -> pushd $moduleDir >/dev/null"
pushd $moduleDir >/dev/null

#查看当前所在分支是否正确
echo "[C] -> git status | grep -E develop"
if [ -z "$(git status | grep -E develop)" ]; then
    echo "[E] 当前的分支不是'develop'。请将所有待提交代码合并至develop分支，develop分支的内容总应该是最新的，每次开发需以develop为基础创建开发分支"
    exit
fi

#看下当前tag是否存在
echo "[C] -> git tag | grep $TAG"
tagExists=$(echo $(git tag | grep "$TAG"))
if [ -n "$tagExists" ]; then
    echo "[E] 输入的tag已经存在了，请重新输入一个"
    echo "[E] 删除tag的方法："
    echo "[E] 1. 删除本地tag: git tag -d $TAG"
    echo "[E] 2. 删除远端tag【慎重，别误删了线上版本】: git push origin :refs/tags/$TAG"
    echo "[E] 注意，原则上禁止删除远程tag，只可删除本地tag"
    exit
fi

echo "[C] -> popd >/dev/null"
popd >/dev/null

#参数检查完毕，初始化工作目录
tmpModuleDir=$shDir/.tmp/modules
tmpDir=$tmpModuleDir/$NAME

if [ ! -d $tmpModuleDir ]; then
    echo "[C] -> mkdir -p $tmpModuleDir"
    mkdir -p $tmpModuleDir
elif [ -d $tmpDir ]; then
    echo "[C] -> rm -rf $tmpDir"
    rm -rf $tmpDir
fi

#将工程文件copy到临时目录进行处理
echo "[C] -> cp -r $moduleDir $tmpModuleDir/"
cp -r $moduleDir $tmpModuleDir/

moduleDir=$tmpModuleDir/$NAME

echo "[I] 准备替换podspec gitUrl=${gitUrl}"
#替换podspec文件中的git地址
gitUrl=$(echo $gitUrl | sed -e s/\\\//\\\\\\\//g)
set +e
echo "[C] -> sed -i \"\" \"s/REPLACEGIT/$gitUrl/g\" $moduleDir/$NAME.podspec >/dev/null"
sed -i "" "s/REPLACEGIT/$gitUrl/g" $moduleDir/$NAME.podspec >/dev/null

#替换版本号
echo "[C] -> sed -i \"\" \"s/\s*s.version.*=.*'.*'/s.version = '$TAG'/g\" $moduleDir/$NAME.podspec >/dev/null"
sed -i "" "s/\s*s.version.*=.*'.*'/s.version = '$TAG'/g" $moduleDir/$NAME.podspec >/dev/null

echo "[I] 替换podspec完成"

echo "[I] 检查是否需要支持framework"
#检查podspec文件是否需要提供framework
echo "[C] -> cat $moduleDir/$NAME.podspec | grep s.vendored_frameworks"
supportFramework=$(cat $moduleDir/$NAME.podspec | grep "s.vendored_frameworks")
if [ -n "$supportFramework" ]; then
    echo "[C] -> $shDir/create/buildLib.sh $NAME Release Y"
    $shDir/create/buildLib.sh $NAME Release Y # release模式，包含模拟器
fi
echo "[I] 检查是否需要支持framework完成"

echo "[C] -> pushd $moduleDir >/dev/null"
pushd $moduleDir >/dev/null

echo "[I] 准备打tag $TAG"
#打tag
echo "[C] -> git add ."
git add .
echo "[C] -> git commit -am \"[PACKAGE] PODSPEC AUTO MODIFIED\""
git commit -am "[PACKAGE] PODSPEC AUTO MODIFIED"
echo "[C] -> git tag $TAG -m \"Release $TAG\""
git tag $TAG -m "Release $TAG"
echo "[C] -> git push origin --tags"
git push origin --tags
set -e

echo "[I] 打tag完成"

#先看一下pod是否正确
echo "[C] -> cat $shDir/config/podspecsaddr.txt"
repoUrl=$(cat $shDir/config/podspecsaddr.txt)
echo "[C] -> cat $shDir/config/dependencypodrepos.txt"
dependencyReposFile=$(cat $shDir/config/dependencypodrepos.txt)
dependencyRepos="$repoUrl"
for oneDependencyRepo in $dependencyReposFile;
do
        echo "[C] -> echo $oneDependencyRepo | grep -E '(^git@.+\.git$)|(^http(s)*://.+\.git$)'"
        valid=$(echo $oneDependencyRepo | grep -E '(^git@.+\.git$)|(^http(s)*://.+\.git$)')
        if [ -n "$valid" ]; then
            dependencyRepos="${dependencyRepos},$oneDependencyRepo"
        fi
done

echo "[C] -> pod lib lint --allow-warnings --sources=$dependencyRepos"
pod lib lint --allow-warnings --sources=$dependencyRepos --use-libraries --skip-import-validation
if [ $? -ne 0 ]; then
    echo "[E] \"pod lib lint --allow-warnings\" 执行失败，请检查 $NAME.podspec 文件"
    exit
fi

echo "[C] -> pod repo push $(cat $shDir/config/podspecsname.txt) --allow-warnings"
pod repo push $(cat $shDir/config/podspecsname.txt) --allow-warnings --use-libraries --skip-import-validation

#将当前模块记录到模块列表中
echo "[C] -> $shDir/utils.sh $NAME addmoduleurl"
$shDir/utils.sh $NAME addmoduleurl

echo "[C] -> popd > /dev/null"
popd > /dev/null

#clean
echo "[C] -> pushd $shDir/../modules/$NAME >/dev/null"
pushd $shDir/../modules/$NAME >/dev/null
echo "[C] -> git pull origin develop && git fetch"
git pull origin develop && git fetch
echo "[C] -> popd >/dev/null"
popd >/dev/null

echo "[C] -> rm -rf $tmpDir"
rm -rf $tmpDir

echo "[I] 完成"