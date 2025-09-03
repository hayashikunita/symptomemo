import XCTest
@testable import symptomemo

final class AIServiceErrorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Ensure no key present
        AIKeyStore.setAPIKey(nil)
    }

    func testGetAdvice_NoAPIKey_Throws() async {
        let e = SymptomEntry(date: Date(), text: "test", severity: 1, medication: "", isImportant: false)
        do {
            _ = try await AIService.getAdvice(for: [e])
            XCTFail("Expected to throw noAPIKey")
        } catch AIServiceError.noAPIKey {
            // OK
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetShortAdvice_NoAPIKey_Throws() async {
        let e = SymptomEntry(date: Date(), text: "test", severity: 1, medication: "", isImportant: false)
        do {
            _ = try await AIService.getShortAdvice(for: [e], bullets: 5)
            XCTFail("Expected to throw noAPIKey")
        } catch AIServiceError.noAPIKey {
            // OK
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
