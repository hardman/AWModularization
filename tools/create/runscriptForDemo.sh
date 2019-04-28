#脚本用于Demo工程的 Build Phases - run script 模块
#作用是将module静态库中的资源文件copy到demo的bundle中，便于引用资源
#注意在demo的Build Phases中 run script的位置应该在copy resource bundle 之上

productName=${PRODUCT_NAME}
moduleName=${productName%Demo}
outFile=${SRCROOT}/${PRODUCT_NAME}/$moduleName.bundle
moduleOutDir=${CONFIGURATION_BUILD_DIR}/$moduleName.framework

#检查文件后缀是否需要copy
validType(){
    filename=$1
    exts=("nib" "png" "jpg" "jpeg" "gif" "txt" "plist" "bundle" "zip" "car")
    for i in ${exts[*]}
    do
        valid=$(echo $filename | grep -E ".$i$");
        isInfoPlist=$(echo $filename | grep -E "^.*Info\.plist$");
        if [ -n "$valid" -a -z "$isInfoPlist" ];then
            echo $valid
        fi
    done;
}

#创建文件夹
if [ -d $outFile ]; then
    rm -rf $outFile
fi

mkdir -p $outFile

#copy info.plist
#没有Info.plist的bundle无法读取其中的.car文件
cp ${SRCROOT}/${PRODUCT_NAME}/Supporting\ Files/ResourceInfo.plist $outFile/Info.plist

#copy files
for f in $moduleOutDir/*
do
    valid=$(validType $f);
    if [ -n "$valid" ]; then
        cp $f $outFile/
    fi
done

