import XCTest
@testable import PackingCore

final class VocabularyTests: XCTestCase {
    func testTheDefaultCategoryIsOneOfTheCategories() {
        XCTAssertTrue(CATEGORIES.contains(CATEGORY_DEFAULT))
    }

    func testNoContainerIsListedTwice() {
        XCTAssertEqual(Set(CONTAINERS).count, CONTAINERS.count)
    }
}
