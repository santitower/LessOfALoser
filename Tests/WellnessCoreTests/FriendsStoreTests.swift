import XCTest
@testable import WellnessCore

final class FriendsStoreTests: XCTestCase {
    func testGeneratedCodeExcludesAmbiguousCharacters() {
        let ambiguous = Set("01OIL")
        for _ in 0..<50 {
            let code = FriendsState.generateCode()
            XCTAssertEqual(code.count, 6)
            XCTAssertTrue(code.allSatisfy { !ambiguous.contains($0) })
        }
    }

    func testFreshStateHasNoFriendsYet() {
        let state = FriendsState()
        XCTAssertTrue(state.addedFriendCodes.isEmpty)
        XCTAssertTrue(state.cachedFriends.isEmpty)
        XCTAssertFalse(state.myCode.isEmpty)
    }
}
