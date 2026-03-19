# Inject NativeRPCKit macro flags into all targets that depend on NativeRPCKit.
#
# Usage in Podfile:
#
#   post_install do |installer|
#     inject_nrpc_swift_flags_if_needed(installer)
#   end

require 'set'

def inject_nrpc_swift_flags_if_needed(installer)
  flags_to_inject = '-load-plugin-executable ${PODS_ROOT}/NativeRPCKit/Prebuilt/NativeRPCKitMacros#NativeRPCKitMacros -enable-experimental-feature SymbolLinkageMarkers'
  dependency_name = 'NativeRPCKit'

  target_map = {}
  installer.pods_project.targets.each do |t|
    target_map[t.name] = t
  end

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
