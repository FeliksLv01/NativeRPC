#
# NativeRPCKit - Standalone Swift SDK for NativeRPC
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint NativeRPCKit.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'NativeRPCKit'
  s.version          = '0.0.1'
  s.summary          = 'Standalone Swift SDK for NativeRPC protocol'
  s.description      = <<-DESC
NativeRPCKit is a standalone Swift SDK for implementing the NativeRPC protocol.
It provides a declarative DSL for defining services and supports multiple transports.
Zero Flutter dependencies - can be used in pure Swift/iOS projects.
                       DESC
  s.homepage         = 'https://github.com/FeliksLv01/NativeRPC'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'FeliksLv01' => 'https://github.com/FeliksLv01' }
  s.source           = { :git => 'https://github.com/FeliksLv01/NativeRPC.git', :tag => s.version.to_s }
  
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '13.0'
  s.watchos.deployment_target = '6.0'
  
  s.swift_version = '5.0'
  
  s.source_files = 'Sources/NativeRPCKit/**/*.swift'
  
  # No external dependencies - pure Swift
  
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES',
    'SWIFT_EMIT_LOC_STRINGS' => 'YES'
  }
  
  # If your SDK requires a privacy manifest, uncomment and update:
  # s.resource_bundles = {'NativeRPCKit_Privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
