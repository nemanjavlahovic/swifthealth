import Foundation

/// Represents a single health metric measured by an analyzer
public struct Metric: Codable, Equatable {
    /// Unique identifier for the metric (e.g., "git.recency", "deps.outdated")
    public let id: String

    /// Human-readable title (e.g., "Last Commit Recency")
    public let title: String

    /// Category this metric belongs to
    public let category: MetricCategory

    /// The measured value
    public let value: MetricValue

    /// Optional unit (e.g., "days", "count", "percent", "s")
    public let unit: String?

    /// Normalized score [0.0, 1.0] for this metric (1.0 = perfect)
    public let score: Double?

    /// Additional details for JSON consumers (raw data fragments)
    public let details: [String: CodableValue]?

    public init(
        id: String,
        title: String,
        category: MetricCategory,
        value: MetricValue,
        unit: String? = nil,
        score: Double? = nil,
        details: [String: CodableValue]? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.value = value
        self.unit = unit
        self.score = score
        self.details = details
    }
}

/// Category groupings for metrics
public enum MetricCategory: String, Codable, CaseIterable {
    case git
    case dependencies
    case code
    case lint
    case test
    case build
}

/// The actual value of a metric (can be different types)
public enum MetricValue: Codable, Equatable {
    case double(Double)
    case int(Int)
    case string(String)
    case percent(Double)      // 0.0 to 1.0 (will be rendered as %)
    case duration(TimeInterval) // seconds

    // Codable implementation for enum with associated values
    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "double":
            let value = try container.decode(Double.self, forKey: .value)
            self = .double(value)
        case "int":
            let value = try container.decode(Int.self, forKey: .value)
            self = .int(value)
        case "string":
            let value = try container.decode(String.self, forKey: .value)
            self = .string(value)
        case "percent":
            let value = try container.decode(Double.self, forKey: .value)
            self = .percent(value)
        case "duration":
            let value = try container.decode(TimeInterval.self, forKey: .value)
            self = .duration(value)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown metric value type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .double(let value):
            try container.encode("double", forKey: .type)
            try container.encode(value, forKey: .value)
        case .int(let value):
            try container.encode("int", forKey: .type)
            try container.encode(value, forKey: .value)
        case .string(let value):
            try container.encode("string", forKey: .type)
            try container.encode(value, forKey: .value)
        case .percent(let value):
            try container.encode("percent", forKey: .type)
            try container.encode(value, forKey: .value)
        case .duration(let value):
            try container.encode("duration", forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}

/// Type-erased wrapper for any Codable value (used in details dictionary)
public enum CodableValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([CodableValue])
    case dictionary([String: CodableValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([CodableValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: CodableValue].self) {
            self = .dictionary(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode CodableValue"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}
