# Inject NativeRPCKit macro flags into all targets that depend on NativeRPCKit.
#
# Usage in Podfile:
#
#   post_install do |installer|
#     inject_nrpc_swift_flags_if_needed(installer)
#   end

require 'set'
require 'pathname'

def inject_nrpc_swift_flags_if_needed(installer)
  dependency_name = 'NativeRPCKit'

  srcroot = find_nrpc_srcroot(installer, dependency_name)
  unless srcroot
    puts "[NRPC_SWIFT_FLAGS] NativeRPCKit not found, skipping."
    return
  end

  macro_binary = File.join(srcroot, 'Prebuilt', 'NativeRPCKitMacros')
  unless File.exist?(macro_binary)
    puts "[NRPC_SWIFT_FLAGS] Macro binary not found at #{macro_binary}, skipping."
    return
  end

  pods_root = installer.sandbox.root.to_s
  relative = Pathname.new(srcroot).relative_path_from(Pathname.new(pods_root)).to_s
  srcroot_ref = "${PODS_ROOT}/#{relative}"

  flags_to_inject = "-load-plugin-executable #{srcroot_ref}/Prebuilt/NativeRPCKitMacros#NativeRPCKitMacros -enable-experimental-feature SymbolLinkageMarkers"

  target_map = {}
  installer.pods_project.targets.each { |t| target_map[t.name] = t }

  installer.pods_project.targets.each do |target|
    next if target.name.start_with?('Pods-')
    next unless depends_on_nrpc_transitively?(target, dependency_name, target_map)

    puts "[NRPC_SWIFT_FLAGS] Injecting flags for target: #{target.name}"
    target.build_configurations.each do |config|
      current_flags = config.build_settings['OTHER_SWIFT_FLAGS'] || '$(inherited)'
      next if current_flags.include?('NativeRPCKitMacros')

      config.build_settings['OTHER_SWIFT_FLAGS'] = "#{current_flags} #{flags_to_inject}"
    end
  end

  installer.aggregate_targets.each do |agg|
    has_nrpc = agg.pod_targets.any? { |pt| pt.pod_name == dependency_name }
    next unless has_nrpc

    user_project = agg.user_project
    agg.user_targets.each do |user_target|
      puts "[NRPC_SWIFT_FLAGS] Injecting flags for app target: #{user_target.name}"
      user_target.build_configurations.each do |config|
        current_flags = config.build_settings['OTHER_SWIFT_FLAGS'] || '$(inherited)'
        next if current_flags.include?('NativeRPCKitMacros')

        config.build_settings['OTHER_SWIFT_FLAGS'] = "#{current_flags} #{flags_to_inject}"
      end
    end
    user_project.save
  end
end

def find_nrpc_srcroot(installer, dependency_name)
  pod_target = installer.pod_targets.find { |pt| pt.pod_name == dependency_name }
  return nil unless pod_target

  sandbox = installer.sandbox
  if sandbox.local?(dependency_name)
    sandbox.local_podspec(dependency_name).dirname.to_s
  else
    File.join(sandbox.root.to_s, dependency_name)
  end
end

def depends_on_nrpc_transitively?(target, dependency_name, target_map, visited = Set.new)
  return false if visited.include?(target.name)
  visited.add(target.name)

  target.dependencies.any? do |dep|
    dep_name = dep.name || (dep.target && dep.target.name)
    next true if dep_name == dependency_name

    dep_target = dep.target || target_map[dep_name]
    next false unless dep_target

    depends_on_nrpc_transitively?(dep_target, dependency_name, target_map, visited)
  end
end
