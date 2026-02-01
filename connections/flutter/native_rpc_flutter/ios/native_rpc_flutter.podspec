#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint native_rpc_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'native_rpc_flutter'
  s.version          = '0.0.1'
  s.summary          = 'NativeRPC Flutter plugin - MethodChannel transport for NativeRPC'
  s.description      = <<-DESC
NativeRPC Flutter plugin provides MethodChannel-based transport for the NativeRPC protocol.
Depends on NativeRPCKit standalone Swift SDK.
                       DESC
  s.homepage         = 'https://github.com/FeliksLv01/NativeRPC'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'FeliksLv01' => 'https://github.com/FeliksLv01' }
  s.source           = { :path => '.' }
  
  # Only plugin glue code - NativeRPCKit is a separate dependency
  s.source_files = 'Classes/**/*'
  
  s.dependency 'Flutter'
  # Depend on NativeRPCKit via local path
  s.dependency 'NativeRPCKit'
  
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'native_rpc_flutter_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
