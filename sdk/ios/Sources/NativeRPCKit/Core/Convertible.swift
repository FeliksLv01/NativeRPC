// Convertible.swift
// NativeRPC v2
//
// Type conversion system for automatic conversion of JSON values to Swift types.
// Inspired by Expo Modules' Convertible protocol.
//
// Usage:
// ```swift
// // Use built-in conversions
// Function("setDate") { (date: Date) -> Void in
//     print(date)  // Automatically converted from ISO8601 string or timestamp
// }
//
// // Define custom conversions
// extension MyCustomType: Convertible {
//     static func convert(from value: Any?) throws -> Self {
//         guard let dict = value as? [String: Any] else {
//             throw ConversionError.typeMismatch(expected: "Dictionary", got: type(of: value))
//         }
//         return MyCustomType(from: dict)
//     }
// }
// ```

import Foundation
import CoreGraphics

// MARK: - Conversion Error

/// Errors that can occur during type conversion
public enum ConversionError: Error, LocalizedError {
    case typeMismatch(expected: String, got: Any.Type)
    case invalidValue(message: String)
    case missingKey(String)
    case nullValue
    
    public var errorDescription: String? {
        switch self {
        case .typeMismatch(let expected, let got):
            return "Type mismatch: expected \(expected), got \(got)"
        case .invalidValue(let message):
            return "Invalid value: \(message)"
        case .missingKey(let key):
            return "Missing required key: \(key)"
        case .nullValue:
            return "Unexpected null value"
        }
    }
}

// MARK: - Convertible Protocol

/// Protocol for types that can be converted from JSON values.
///
/// Implement this protocol to allow your custom types to be used as
/// function arguments in NativeRPC services.
///
/// Example:
/// ```swift
/// struct User {
///     let id: String
///     let name: String
/// }
///
/// extension User: Convertible {
///     static func convert(from value: Any?) throws -> User {
///         guard let dict = value as? [String: Any],
///               let id = dict["id"] as? String,
///               let name = dict["name"] as? String else {
///             throw ConversionError.typeMismatch(expected: "User dictionary", got: type(of: value))
///         }
///         return User(id: id, name: name)
///     }
/// }
/// ```
public protocol Convertible {
    /// Convert from a raw value (typically from JSON) to this type
    static func convert(from value: Any?) throws -> Self
    
    /// Convert this type back to a JSON-serializable value
    /// Default implementation returns self
    static func convertResult(_ result: Any) throws -> Any
}

extension Convertible {
    public static func convertResult(_ result: Any) throws -> Any {
        return result
    }
}

// MARK: - ArgumentConverter

/// Type-erased converter for use in function definitions
public enum ArgumentConverter {
    /// Attempt to convert a value to the specified type
    public static func convert<T>(_ value: Any?, to type: T.Type) throws -> T {
        // If already the correct type, return as-is
        if let typed = value as? T {
            return typed
        }
        
        // If type conforms to Convertible, use its converter
        if let convertibleType = T.self as? Convertible.Type {
            if let converted = try convertibleType.convert(from: value) as? T {
                return converted
            }
        }
        
        // Handle optionals
        if value == nil || value is NSNull {
            if let optionalType = T.self as? ExpressibleByNilLiteral.Type,
               let nilValue = optionalType.init(nilLiteral: ()) as? T {
                return nilValue
            }
            throw ConversionError.nullValue
        }
        
        // Handle numeric conversions
        if let converted = convertNumeric(value, to: type) {
            return converted
        }
        
        throw ConversionError.typeMismatch(expected: String(describing: T.self), got: Swift.type(of: value!))
    }
    
    /// Convert numeric types
    private static func convertNumeric<T>(_ value: Any?, to type: T.Type) -> T? {
        guard let value = value else { return nil }
        
        // NSNumber can be converted to various numeric types
        if let number = value as? NSNumber {
            switch type {
            case is Int.Type: return number.intValue as? T
            case is Int8.Type: return number.int8Value as? T
            case is Int16.Type: return number.int16Value as? T
            case is Int32.Type: return number.int32Value as? T
            case is Int64.Type: return number.int64Value as? T
            case is UInt.Type: return number.uintValue as? T
            case is UInt8.Type: return number.uint8Value as? T
            case is UInt16.Type: return number.uint16Value as? T
            case is UInt32.Type: return number.uint32Value as? T
            case is UInt64.Type: return number.uint64Value as? T
            case is Float.Type: return number.floatValue as? T
            case is Double.Type: return number.doubleValue as? T
            case is CGFloat.Type: return CGFloat(number.doubleValue) as? T
            case is Bool.Type: return number.boolValue as? T
            default: return nil
            }
        }
        
        // Direct numeric type conversions
        if let intValue = value as? Int {
            switch type {
            case is Double.Type: return Double(intValue) as? T
            case is Float.Type: return Float(intValue) as? T
            case is CGFloat.Type: return CGFloat(intValue) as? T
            default: return nil
            }
        }
        
        if let doubleValue = value as? Double {
            switch type {
            case is Int.Type: return Int(doubleValue) as? T
            case is Float.Type: return Float(doubleValue) as? T
            case is CGFloat.Type: return CGFloat(doubleValue) as? T
            default: return nil
            }
        }
        
        return nil
    }
}

// MARK: - Built-in Convertibles

// MARK: URL

extension URL: Convertible {
    public static func convert(from value: Any?) throws -> URL {
        // Already a URL
        if let url = value as? URL {
            return url
        }
        
        guard let string = value as? String else {
        throw ConversionError.typeMismatch(expected: "String", got: Swift.type(of: value as Any))
        }
        
        // Check for file paths first (before trying URL(string:))
        if string.hasPrefix("/") || string.hasPrefix("~") {
            return URL(fileURLWithPath: (string as NSString).expandingTildeInPath)
        }
        
        // Try as-is for regular URLs
        if let url = URL(string: string) {
            return url
        }
        
        // Try percent-encoding
        if let encoded = string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: encoded) {
            return url
        }
        
        throw ConversionError.invalidValue(message: "Cannot create URL from: \(string)")
    }
    
    public static func convertResult(_ result: Any) throws -> Any {
        if let url = result as? URL {
            return url.absoluteString
        }
        return result
    }
}

// MARK: Date

extension Date: Convertible {
    public static func convert(from value: Any?) throws -> Date {
        // Already a Date
        if let date = value as? Date {
            return date
        }
        
        // From ISO8601 string
        if let string = value as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let date = formatter.date(from: string) {
                return date
            }
            
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) {
                return date
            }
            
            throw ConversionError.invalidValue(message: "Cannot parse date from: \(string)")
        }
        
        // From timestamp (milliseconds since 1970)
        if let timestamp = value as? Double {
            return Date(timeIntervalSince1970: timestamp / 1000.0)
        }
        
        if let timestamp = value as? Int {
            return Date(timeIntervalSince1970: Double(timestamp) / 1000.0)
        }
        
        throw ConversionError.typeMismatch(expected: "String or Number", got: Swift.type(of: value as Any))
    }
    
    public static func convertResult(_ result: Any) throws -> Any {
        if let date = result as? Date {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.string(from: date)
        }
        return result
    }
}

// MARK: Data

extension Data: Convertible {
    public static func convert(from value: Any?) throws -> Data {
        // Already Data
        if let data = value as? Data {
            return data
        }
        
        // From Base64 string
        if let string = value as? String {
            guard let data = Data(base64Encoded: string) else {
                throw ConversionError.invalidValue(message: "Invalid Base64 string")
            }
            return data
        }
        
        // From byte array
        if let bytes = value as? [UInt8] {
            return Data(bytes)
        }
        
        if let numbers = value as? [Int] {
            return Data(numbers.map { UInt8(clamping: $0) })
        }
        
        throw ConversionError.typeMismatch(expected: "String or Array", got: Swift.type(of: value as Any))
    }
    
    public static func convertResult(_ result: Any) throws -> Any {
        if let data = result as? Data {
            return data.base64EncodedString()
        }
        return result
    }
}

// MARK: - CoreGraphics Convertibles

extension CGPoint: Convertible {
    public static func convert(from value: Any?) throws -> CGPoint {
        if let point = value as? CGPoint {
            return point
        }
        
        // From array [x, y]
        if let array = value as? [Double], array.count >= 2 {
            return CGPoint(x: array[0], y: array[1])
        }
        
        if let array = value as? [Int], array.count >= 2 {
            return CGPoint(x: Double(array[0]), y: Double(array[1]))
        }
        
        // From dictionary {x, y}
        if let dict = value as? [String: Any] {
            guard let x = (dict["x"] as? Double) ?? (dict["x"] as? Int).map(Double.init),
                  let y = (dict["y"] as? Double) ?? (dict["y"] as? Int).map(Double.init) else {
                throw ConversionError.missingKey("x or y")
            }
            return CGPoint(x: x, y: y)
        }
        
        throw ConversionError.typeMismatch(expected: "Array or Dictionary", got: Swift.type(of: value as Any))
    }
    
    public static func convertResult(_ result: Any) throws -> Any {
        if let point = result as? CGPoint {
            return ["x": point.x, "y": point.y]
        }
        return result
    }
}

extension CGSize: Convertible {
    public static func convert(from value: Any?) throws -> CGSize {
        if let size = value as? CGSize {
            return size
        }
        
        // From array [width, height]
        if let array = value as? [Double], array.count >= 2 {
            return CGSize(width: array[0], height: array[1])
        }
        
        if let array = value as? [Int], array.count >= 2 {
            return CGSize(width: Double(array[0]), height: Double(array[1]))
        }
        
        // From dictionary {width, height}
        if let dict = value as? [String: Any] {
            guard let w = (dict["width"] as? Double) ?? (dict["width"] as? Int).map(Double.init),
                  let h = (dict["height"] as? Double) ?? (dict["height"] as? Int).map(Double.init) else {
                throw ConversionError.missingKey("width or height")
            }
            return CGSize(width: w, height: h)
        }
        
        throw ConversionError.typeMismatch(expected: "Array or Dictionary", got: Swift.type(of: value as Any))
    }
    
    public static func convertResult(_ result: Any) throws -> Any {
        if let size = result as? CGSize {
            return ["width": size.width, "height": size.height]
        }
        return result
    }
}

extension CGRect: Convertible {
    public static func convert(from value: Any?) throws -> CGRect {
        if let rect = value as? CGRect {
            return rect
        }
        
        // From array [x, y, width, height]
        if let array = value as? [Double], array.count >= 4 {
            return CGRect(x: array[0], y: array[1], width: array[2], height: array[3])
        }
        
        if let array = value as? [Int], array.count >= 4 {
            return CGRect(x: Double(array[0]), y: Double(array[1]), 
                         width: Double(array[2]), height: Double(array[3]))
        }
        
        // From dictionary {x, y, width, height}
        if let dict = value as? [String: Any] {
            guard let x = (dict["x"] as? Double) ?? (dict["x"] as? Int).map(Double.init),
                  let y = (dict["y"] as? Double) ?? (dict["y"] as? Int).map(Double.init),
                  let w = (dict["width"] as? Double) ?? (dict["width"] as? Int).map(Double.init),
                  let h = (dict["height"] as? Double) ?? (dict["height"] as? Int).map(Double.init) else {
                throw ConversionError.missingKey("x, y, width, or height")
            }
            return CGRect(x: x, y: y, width: w, height: h)
        }
        
        throw ConversionError.typeMismatch(expected: "Array or Dictionary", got: Swift.type(of: value as Any))
    }
    
    public static func convertResult(_ result: Any) throws -> Any {
        if let rect = result as? CGRect {
            return ["x": rect.minX, "y": rect.minY, "width": rect.width, "height": rect.height]
        }
        return result
    }
}

// MARK: - Color (Platform-specific)

#if canImport(UIKit)
import UIKit

extension UIColor: Convertible {
    public static func convert(from value: Any?) throws -> Self {
        if let color = value as? Self {
            return color
        }
        
        // From hex string "#RRGGBB" or "#RRGGBBAA"
        if let string = value as? String {
            var hex = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if hex.hasPrefix("#") {
                hex.removeFirst()
            }
            
            guard hex.count == 6 || hex.count == 8 else {
                throw ConversionError.invalidValue(message: "Invalid hex color: \(string)")
            }
            
            var rgbValue: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&rgbValue)
            
            if hex.count == 6 {
                let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
                let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
                let b = CGFloat(rgbValue & 0x0000FF) / 255.0
                return Self(red: r, green: g, blue: b, alpha: 1.0)
            } else {
                let r = CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0
                let g = CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0
                let b = CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0
                let a = CGFloat(rgbValue & 0x000000FF) / 255.0
                return Self(red: r, green: g, blue: b, alpha: a)
            }
        }
        
        // From dictionary {r, g, b, a?} (0-255)
        if let dict = value as? [String: Any] {
            guard let r = (dict["r"] as? Double) ?? (dict["r"] as? Int).map(Double.init),
                  let g = (dict["g"] as? Double) ?? (dict["g"] as? Int).map(Double.init),
                  let b = (dict["b"] as? Double) ?? (dict["b"] as? Int).map(Double.init) else {
                throw ConversionError.missingKey("r, g, or b")
            }
            let a = (dict["a"] as? Double) ?? (dict["a"] as? Int).map(Double.init) ?? 255.0
            return Self(red: CGFloat(r/255), green: CGFloat(g/255), blue: CGFloat(b/255), alpha: CGFloat(a/255))
        }
        
        throw ConversionError.typeMismatch(expected: "String or Dictionary", got: Swift.type(of: value as Any))
    }
    
    public static func convertResult(_ result: Any) throws -> Any {
        if let color = result as? UIColor {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            
            let ri = Int(r * 255)
            let gi = Int(g * 255)
            let bi = Int(b * 255)
            let ai = Int(a * 255)
            
            if ai == 255 {
                return String(format: "#%02X%02X%02X", ri, gi, bi)
            } else {
                return String(format: "#%02X%02X%02X%02X", ri, gi, bi, ai)
            }
        }
        return result
    }
}
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

extension NSColor: Convertible {
    public static func convert(from value: Any?) throws -> Self {
        if let color = value as? Self {
            return color
        }
        
        // From hex string
        if let string = value as? String {
            var hex = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if hex.hasPrefix("#") {
                hex.removeFirst()
            }
            
            guard hex.count == 6 || hex.count == 8 else {
                throw ConversionError.invalidValue(message: "Invalid hex color: \(string)")
            }
            
            var rgbValue: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&rgbValue)
            
            if hex.count == 6 {
                let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
                let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
                let b = CGFloat(rgbValue & 0x0000FF) / 255.0
                return Self(red: r, green: g, blue: b, alpha: 1.0)
            } else {
                let r = CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0
                let g = CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0
                let b = CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0
                let a = CGFloat(rgbValue & 0x000000FF) / 255.0
                return Self(red: r, green: g, blue: b, alpha: a)
            }
        }
        
        throw ConversionError.typeMismatch(expected: "String", got: Swift.type(of: value as Any))
    }
}
#endif
