//
//  NativeRPCServiceScanner.swift
//  NativeRPCKit
//

import Foundation
import MachO

/// Function pointer type stored in Mach-O section.
/// Returns the service metatype as UnsafeRawPointer.
private typealias ServiceMetatypeGetter = @convention(c) () -> UnsafeRawPointer

/// Scans the Mach-O `__DATA_CONST,__nrpc_service` section to discover services
/// registered with the `@NativeRPCService` macro.
///
/// - Note: Internal implementation detail. Use `NativeRPCServiceAutoRegistrar.registerAll()` instead.
enum NativeRPCServiceScanner {
    
    /// Scans the main executable for registered service types.
    /// - Returns: An array of service metatypes
    static func scan() -> [Any.Type] {
        var header: UnsafePointer<mach_header_64>?
        
        #if DEBUG
        // In debug builds, check for .debug.dylib first (for hot reload scenarios)
        if let mainName = mainExecutableName() {
            let debugName = mainName + ".debug.dylib"
            if let debugHeader = findImageHeader(named: debugName) {
                header = debugHeader
            }
        }
        #endif
        
        if header == nil, let mainName = mainExecutableName() {
            header = findImageHeader(named: mainName)
        }
        
        guard let hdr = header else {
            return []
        }
        
        return readSection(header: hdr)
    }
    
    // MARK: - Private
    
    private static func mainExecutableName() -> String? {
        Bundle.main.executableURL?.lastPathComponent
    }
    
    private static func findImageHeader(named executableName: String) -> UnsafePointer<mach_header_64>? {
        let count = _dyld_image_count()
        for idx in 0..<count {
            if let namePtr = _dyld_get_image_name(idx) {
                let name = String(cString: namePtr)
                if name.hasSuffix("/" + executableName) || name == executableName {
                    if let rawHeader = _dyld_get_image_header(idx) {
                        return UnsafePointer<mach_header_64>(OpaquePointer(rawHeader))
                    }
                }
            }
        }
        return nil
    }
    
    private static func readSection(header: UnsafePointer<mach_header_64>) -> [Any.Type] {
        var size: UInt = 0
        guard let sectionData = getsectiondata(header, "__DATA_CONST", "__nrpc_service", &size),
              size > 0 else {
            return []
        }
        
        // Each entry is a raw function pointer
        let itemSize = MemoryLayout<ServiceMetatypeGetter>.stride
        let count = Int(size) / itemSize
        let rawPtr = UnsafeRawPointer(sectionData)
        
        var results: [Any.Type] = []
        results.reserveCapacity(count)
        
        for idx in 0..<count {
            let getter = rawPtr.load(fromByteOffset: idx * itemSize, as: ServiceMetatypeGetter.self)
            let typePtr = getter()
            let serviceType = unsafeBitCast(typePtr, to: Any.Type.self)
            results.append(serviceType)
        }
        
        return results
    }
}
