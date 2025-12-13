import XCTest
@testable import Core

/// Tests for Metric and MetricValue encoding/decoding
final class MetricTests: XCTestCase {

    // MARK: - MetricValue Tests

    func testMetricValue_Double_EncodesAndDecodes() throws {
        let original = MetricValue.double(3.14159)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MetricValue.self, from: encoded)

        XCTAssertEqual(decoded, original, "Double value should roundtrip")
    }

    func testMetricValue_Int_EncodesAndDecodes() throws {
        let original = MetricValue.int(42)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MetricValue.self, from: encoded)

        XCTAssertEqual(decoded, original, "Int value should roundtrip")
    }

    func testMetricValue_String_EncodesAndDecodes() throws {
        let original = MetricValue.string("Hello, SwiftHealth!")

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MetricValue.self, from: encoded)

        XCTAssertEqual(decoded, original, "String value should roundtrip")
    }

    func testMetricValue_Percent_EncodesAndDecodes() throws {
        let original = MetricValue.percent(0.75)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MetricValue.self, from: encoded)

        XCTAssertEqual(decoded, original, "Percent value should roundtrip")
    }

    func testMetricValue_Duration_EncodesAndDecodes() throws {
        let original = MetricValue.duration(123.456)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MetricValue.self, from: encoded)

        XCTAssertEqual(decoded, original, "Duration value should roundtrip")
    }

    // MARK: - Metric Tests

    func testMetric_FullMetric_EncodesAndDecodes() throws {
        let original = Metric(
            id: "test.metric",
            title: "Test Metric",
            category: .code,
            value: .int(100),
            unit: "lines",
            score: 0.85,
            details: nil
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Metric.self, from: encoded)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.category, original.category)
        XCTAssertEqual(decoded.value, original.value)
        XCTAssertEqual(decoded.unit, original.unit)
        XCTAssertEqual(decoded.score, original.score)
    }

    func testMetric_MinimalMetric_EncodesAndDecodes() throws {
        let original = Metric(
            id: "minimal",
            title: "Minimal",
            category: .git,
            value: .int(1)
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Metric.self, from: encoded)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertNil(decoded.unit, "Unit should be nil")
        XCTAssertNil(decoded.score, "Score should be nil")
    }

    // MARK: - MetricCategory Tests

    func testMetricCategory_AllCases_Exist() {
        let expectedCategories: Set<MetricCategory> = [.git, .dependencies, .code, .lint, .test, .build]

        XCTAssertEqual(Set(MetricCategory.allCases), expectedCategories, "All categories should exist")
    }

    func testMetricCategory_EncodesAsRawValue() throws {
        let category = MetricCategory.dependencies

        let encoded = try JSONEncoder().encode(category)
        let jsonString = String(data: encoded, encoding: .utf8)

        XCTAssertEqual(jsonString, "\"dependencies\"", "Should encode as raw string")
    }

    // MARK: - CodableValue Tests

    func testCodableValue_String_EncodesAndDecodes() throws {
        let original = CodableValue.string("test")

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableValue.self, from: encoded)

        XCTAssertEqual(decoded, original)
    }

    func testCodableValue_Int_EncodesAndDecodes() throws {
        let original = CodableValue.int(42)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableValue.self, from: encoded)

        XCTAssertEqual(decoded, original)
    }

    func testCodableValue_Double_EncodesAndDecodes() throws {
        let original = CodableValue.double(3.14)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableValue.self, from: encoded)

        XCTAssertEqual(decoded, original)
    }

    func testCodableValue_Bool_EncodesAndDecodes() throws {
        let original = CodableValue.bool(true)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableValue.self, from: encoded)

        XCTAssertEqual(decoded, original)
    }

    func testCodableValue_Array_EncodesAndDecodes() throws {
        let original = CodableValue.array([.int(1), .int(2), .int(3)])

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableValue.self, from: encoded)

        XCTAssertEqual(decoded, original)
    }

    func testCodableValue_Dictionary_EncodesAndDecodes() throws {
        let original = CodableValue.dictionary(["key": .string("value")])

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableValue.self, from: encoded)

        XCTAssertEqual(decoded, original)
    }

    func testCodableValue_Null_EncodesAndDecodes() throws {
        let original = CodableValue.null

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableValue.self, from: encoded)

        XCTAssertEqual(decoded, original)
    }

    // MARK: - Metric Equatable Tests

    func testMetric_Equatable_SameMetrics() {
        let metric1 = Metric(id: "test", title: "Test", category: .code, value: .int(1))
        let metric2 = Metric(id: "test", title: "Test", category: .code, value: .int(1))

        XCTAssertEqual(metric1, metric2, "Identical metrics should be equal")
    }

    func testMetric_Equatable_DifferentValues() {
        let metric1 = Metric(id: "test", title: "Test", category: .code, value: .int(1))
        let metric2 = Metric(id: "test", title: "Test", category: .code, value: .int(2))

        XCTAssertNotEqual(metric1, metric2, "Different values = not equal")
    }

    func testMetric_Equatable_DifferentIds() {
        let metric1 = Metric(id: "test1", title: "Test", category: .code, value: .int(1))
        let metric2 = Metric(id: "test2", title: "Test", category: .code, value: .int(1))

        XCTAssertNotEqual(metric1, metric2, "Different IDs = not equal")
    }
}
