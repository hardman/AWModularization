#参考 https://www.cnblogs.com/hello-LJ/p/4515641.html
require 'xcodeproj'
require 'fileutils'
require 'digest'

DIR = File.dirname(__FILE__)
NAME = ARGV.at(0);
BUNDLEID = ARGV.at(1);

#创建.xcodeproj
def createProjObj(name, dir)
    #创建xcodeproj文件
    projname = "#{dir}/#{name}.xcodeproj"
    Xcodeproj::Project.new(projname).save

    #打开文件
    return Xcodeproj::Project.open(projname)
end

#创建main target
def createMainTarget(type, proj, mainGroup, name, dir, bundleid, filesInTarget)
    #Support files
    supportFilesGroup = mainGroup.new_group("Supporting Files", "Supporting Files");
    supportFilesGroup.new_reference("Info.plist");

    #target
    mainTarget = proj.new_target(type, "#{name}", :ios, "8.0");

    sourceFiles = Array.new
    #将bundle加入到copy resources中
    for fr in filesInTarget do
        #.bundle文件需要加入到 Build Phases - Copy Resource Bundle中
        #.h文件需要加入到 Build Phase - Headers中
        if fr.path.include?(".bundle") then
            if not mainTarget.resources_build_phase.include?(fr) then
                build_file = proj.new(Xcodeproj::Project::Object::PBXBuildFile)
                build_file.file_ref = fr
                mainTarget.resources_build_phase.files << build_file
            end
        elsif fr.path.include?(".h") then
            headerPhase = mainTarget.headers_build_phase
            unless build_file = headerPhase.build_file(fr)
              build_file = proj.new(Xcodeproj::Project::Object::PBXBuildFile)
              build_file.file_ref = fr
              build_file.settings = { 'ATTRIBUTES' => ['Public'] }
              headerPhase.files << build_file
            end
        else 
            sourceFiles << fr
        end
    end

    #加入source files
    mainTarget.add_file_references(sourceFiles);

    #target build settiing设置
    mainTarget.build_configuration_list.set_setting("INFOPLIST_FILE", "${SRCROOT}/#{name}/Supporting Files/Info.plist");
    mainTarget.build_configuration_list.set_setting("PRODUCT_BUNDLE_IDENTIFIER", bundleid);
    mainTarget.build_configuration_list.set_setting("VALID_ARCHS", "$(ARCHS_STANDARD)");
    mainTarget.build_configuration_list.set_setting("SWIFT_VERSION", "4.0");

    #使用静态库
    if type == :framework then
        mainTarget.build_configuration_list.set_setting("MACH_O_TYPE", "staticlib");
    end

    mainTarget
end

#创建test target
def createTestTarget(proj, name, dir, bundleid)
    # 创建group并加入文件引用
    testGroup = proj.main_group.new_group("#{name}Tests", "#{name}Tests");
    fileInTestTarget = Array[
        testGroup.new_reference("#{name}Tests.swift")
    ]
    testGroup.new_reference("Info.plist")
    
    #创建target
    testTarget = proj.new_target(:unit_test_bundle, "#{name}Tests", :ios, "8.0", proj.products_group);
    testTarget.product_reference.set_explicit_file_type("wrapper.cfbundle");
    testTarget.product_reference.name = "#{name}Tests.xctest";
    testTarget.add_file_references(fileInTestTarget);

    #tests build settiing
    testTarget.build_configuration_list.set_setting("INFOPLIST_FILE", "${SRCROOT}/#{name}Tests/Info.plist");
    testTarget.build_configuration_list.set_setting("PRODUCT_BUNDLE_IDENTIFIER", "#{bundleid}.test");
    testTarget.build_configuration_list.set_setting("LD_RUNPATH_SEARCH_PATHS", "$(inherited) @executable_path/Frameworks @loader_path/Frameworks");
    testTarget.build_configuration_list.set_setting("VALID_ARCHS", "armv7 arm64");
    testTarget.build_configuration_list.set_setting("SWIFT_VERSION", "4.0");
    
    testTarget
end

#创建demo工程
def createDemo
    name = "#{NAME}Demo";
    dir = "./Demo";
    FileUtils.mkdir_p(dir);
    bundleid = "#{BUNDLEID}demo";
    filesInTarget = Array[
        "AppDelegate.swift",
        "ViewController.swift",
        "Assets.xcassets",
        "Base.lproj/LaunchScreen.storyboard",
        "Base.lproj/Main.storyboard",
        "#{NAME}.bundle"
    ];
    type = :application;
    
    mainTarget = createProjectFile(type, name, dir, bundleid, filesInTarget);

    #创建runscript build phase
    shellScriptPhase = mainTarget.new_shell_script_build_phase();
    shellScriptFile = File.new("#{DIR}/runscriptForDemo.sh");
    shellScript = shellScriptFile.read
    shellScriptPhase.shell_script = shellScript

    #交换 shell script 与 copy bundle resource的位置，令shell script在前
    shellScriptIdx = -1
    copyBundleResourceIdx = -1
    idx = 0
    for phase in mainTarget.build_phases do
        if "#{phase}" == "ResourcesBuildPhase" then
            copyBundleResourceIdx = idx;
        elsif "#{phase}" == "ShellScriptBuildPhase" then
            shellScriptIdx = idx;
        end
        idx = idx + 1;
    end

    if shellScriptIdx >= 0 and copyBundleResourceIdx >= 0 and shellScriptIdx > copyBundleResourceIdx then
        tmp = mainTarget.build_phases[shellScriptIdx];
        mainTarget.build_phases[shellScriptIdx] = mainTarget.build_phases[copyBundleResourceIdx];
        mainTarget.build_phases[copyBundleResourceIdx] = tmp;
    else
        puts "[E] 没有找到ResourcesBuildPhase和ShellScriptBuildPhase";
    end

    #添加#{NAME}framework
    group = mainTarget.project.frameworks_group['iOS'] || mainTarget.project.frameworks_group.new_group('iOS')
    ref = group.new_file("#{NAME}.framework", :built_products);
    mainTarget.frameworks_build_phase.add_file_reference(ref, true);
    mainTarget.project.save
end

#创建模块工程
def createModuleLib
    name = NAME;
    dir = "./";
    bundleid = BUNDLEID;
    filesInTarget = Array[
        "SampleViewController.swift",
        "SampleViewController.xib",
        "Assets.xcassets",
        "#{NAME}.h"
    ];
    type = :framework;

    createProjectFile(type, name, dir, bundleid, filesInTarget);
end

#创建任意工程
def createProjectFile(type, name, dir, bundleid, filesInTarget)
    #打开文件
    proj = createProjObj(name, dir);

    #创建主分组
    mainGroup = proj.main_group.new_group(name, "#{name}");

    #创建target
    mainTarget = createMainTarget(type, proj, mainGroup, name, dir, bundleid, filesInTarget.map{|f| mainGroup.new_reference(f)});

    #创建测试分组
    createTestTarget(proj, name, dir, bundleid)

    #保存
    proj.save;

    #返回值
    mainTarget
end

#脚本入口
def execute
    createModuleLib
    createDemo
end

execute