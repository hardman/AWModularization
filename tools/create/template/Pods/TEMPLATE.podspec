Pod::Spec.new do |s|
    s.name         = 'MODULENAME'
    s.version      = '0.0.1'
    s.summary      = 'SUMMARY'
    s.homepage     = 'https://www.awstar.cn'
    s.license      = 'MIT'
    s.authors      = {'AUTHOR' => 'EMAIL'}
    s.platform     = :ios, 'PLATFORMVERSION'
    s.swift_version = '4.0'
    s.source       = {:git => 'REPLACEGIT', :tag => s.version}
    s.source_files = 'MODULENAME/**/*.{h,m,swift}'
    s.vendored_frameworks = 'frameworks/**/*.framework'
    s.resource_bundle = {
	"MODULENAME" => ['MODULENAME/**/Assets.xcassets', 'MODULENAME/**/*.{nib,png,jpg,jpeg,gif,txt,plist,bundle,zip}']
    }
    s.exclude_files = 'MODULENAME/**/Info.plist'
    s.requires_arc = true
    DEPENDENCY
end
