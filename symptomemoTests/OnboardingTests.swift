import XCTest
@testable import symptomemo

final class OnboardingTests: XCTestCase {
    func testClamp() {
        XCTAssertEqual(1.5.clamped(to: 0.8...1.4), 1.4)
        XCTAssertEqual(0.6.clamped(to: 0.8...1.4), 0.8)
        XCTAssertEqual(1.0.clamped(to: 0.8...1.4), 1.0)
    }
}
