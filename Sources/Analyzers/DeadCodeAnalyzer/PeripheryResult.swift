import Foundation

/// Represents a single unused code detection from Periphery
struct PeripheryResult: Codable {
    let name: String
    let kind: String
    let hints: [String]
    let location: String
    let accessibility: String
    let modules: [String]?  // Optional - some results don't have modules
    let modifiers: [String]?
    let attributes: [String]?
    let ids: [String]?

    /// Check if this result represents unused code
    var isUnused: Bool {
        hints.contains("unused")
    }

    /// Check if this result represents redundant public accessibility
    var isRedundantPublic: Bool {
        hints.contains("redundantPublicAccessibility")
    }

    /// Extract the file path from location (format: "path/to/file.swift:line:column")
    var filePath: String? {
        location.components(separatedBy: ":").first
    }

    /// Extract line number from location
    var lineNumber: Int? {
        let components = location.components(separatedBy: ":")
        guard components.count >= 2 else { return nil }
        return Int(components[1])
    }

    /// Human-readable description of the kind
    var kindDescription: String {
        switch kind {
        case "var.instance": return "property"
        case "var.parameter": return "parameter"
        case "function.method.instance": return "method"
        case "function.constructor": return "initializer"
        case "struct": return "struct"
        case "class": return "class"
        case "enum": return "enum"
        case "protocol": return "protocol"
        case "typealias": return "typealias"
        case "associatedtype": return "associated type"
        default: return kind
        }
    }
}
