// RPCAnyCodable.swift
// NativeRPC v2
//
// Type-erased Codable wrapper for dynamic JSON values

import Foundation

/// A type-erased Codable value that can hold any JSON-compatible type
///
/// Note: Marked `@unchecked Sendable` because `value` is `Any`.
/// Safety invariant: Only JSON-compatible values are stored (Bool, Int, Double,
/// String, NSNull, Array, Dictionary) which are all value types or immutable.
@dynamicMemberLookup
public struct RPCAnyCodable: Codable, @unchecked Sendable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    // MARK: - Decodable
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([RPCAnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: RPCAnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
    
    // MARK: - Encodable
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { RPCAnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { RPCAnyCodable($0) })
        case let codable as Encodable:
            try codable.encode(to: encoder)
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "Unsupported type: \(type(of: value))"
            ))
        }
    }
    
    // MARK: - Dynamic Member Lookup
    
    public subscript(dynamicMember member: String) -> RPCAnyCodable? {
        guard let dict = value as? [String: Any] else { return nil }
        return dict[member].map { RPCAnyCodable($0) }
    }
    
    public subscript(index: Int) -> RPCAnyCodable? {
        guard let array = value as? [Any], index < array.count else { return nil }
        return RPCAnyCodable(array[index])
    }
    
    // MARK: - Type Accessors
    
    public var isNull: Bool { value is NSNull }
    public var boolValue: Bool? { value as? Bool }
    public var intValue: Int? { value as? Int }
    public var doubleValue: Double? { value as? Double }
    public var stringValue: String? { value as? String }
    public var arrayValue: [Any]? { value as? [Any] }
    public var dictValue: [String: Any]? { value as? [String: Any] }
}

// MARK: - ExpressibleBy Literals

extension RPCAnyCodable: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self.value = NSNull()
    }
}

extension RPCAnyCodable: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.value = value
    }
}

extension RPCAnyCodable: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.value = value
    }
}

extension RPCAnyCodable: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.value = value
    }
}

extension RPCAnyCodable: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.value = value
    }
}

extension RPCAnyCodable: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Any...) {
        self.value = elements
    }
}

extension RPCAnyCodable: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        self.value = Dictionary(uniqueKeysWithValues: elements)
    }
}

// MARK: - Equatable (limited)

extension RPCAnyCodable: Equatable {
    public static func == (lhs: RPCAnyCodable, rhs: RPCAnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (is NSNull, is NSNull):
            return true
        case let (l as Bool, r as Bool):
            return l == r
        case let (l as Int, r as Int):
            return l == r
        case let (l as Double, r as Double):
            return l == r
        case let (l as String, r as String):
            return l == r
        default:
            return false
        }
    }
}
