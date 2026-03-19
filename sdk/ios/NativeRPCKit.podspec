Pod::Spec.new do |s|
  s.name             = 'NativeRPCKit'
  s.version          = '0.0.6'
  s.summary          = 'Standalone Swift SDK for NativeRPC protocol'
  s.description      = <<-DESC
NativeRPCKit is a standalone Swift SDK for implementing the NativeRPC protocol.
It provides a declarative DSL for defining services and supports multiple transports.
Zero Flutter dependencies - can be used in pure Swift/iOS projects.
                       DESC
  s.homepage         = 'https://code.devops.xiaohongshu.com/RedCity-iOS/NativeRPC/NativeRPCKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Hi Developer' => 'hi_dev@xiaohongshu.com' }
  s.source           = { :git => 'git@code.devops.xiaohongshu.com:RedCity-iOS/NativeRPC/NativeRPCKit.git', :tag => s.version.to_s }  
  s.ios.deployment_target = '13.0'
  
  s.swift_version = '5.9'

  s.source_files = 'Sources/NativeRPCKit/**/*.swift'

  s.preserve_paths = 'Prebuilt/NativeRPCKitMacros', 'scripts/nrpc_swift_flags.rb'

  s.pod_target_xcconfig = {
    'OTHER_SWIFT_FLAGS' => '-load-plugin-executable ${PODS_TARGET_SRCROOT}/Prebuilt/NativeRPCKitMacros#NativeRPCKitMacros'
  }
end
