import XCTest
@testable import Clearance

@MainActor
final class HelpViewModelTests: XCTestCase {
    private func topic(_ slug: String, _ order: Int) -> HelpTopic {
        HelpTopic(
            slug: slug,
            title: slug.capitalized,
            order: order,
            fileURL: URL(fileURLWithPath: "/Help/\(slug).md"),
            body: "body \(slug)"
        )
    }

    func testStartsOnFirstTopic() {
        let vm = HelpViewModel(topics: [topic("welcome", 1), topic("opening", 2)])
        XCTAssertEqual(vm.currentTopic?.slug, "welcome")
        XCTAssertFalse(vm.canGoBack)
    }

    func testSelectPushesBackHistory() {
        let vm = HelpViewModel(topics: [topic("welcome", 1), topic("opening", 2)])
        vm.select(topic("opening", 2))
        XCTAssertEqual(vm.currentTopic?.slug, "opening")
        XCTAssertTrue(vm.canGoBack)
        vm.goBack()
        XCTAssertEqual(vm.currentTopic?.slug, "welcome")
        XCTAssertTrue(vm.canGoForward)
    }

    func testOpenLinkNavigatesToMatchingTopicByPath() {
        let topics = [topic("welcome", 1), topic("opening", 2)]
        let vm = HelpViewModel(topics: topics)
        let handled = vm.openLink(URL(fileURLWithPath: "/Help/opening.md"))
        XCTAssertTrue(handled)
        XCTAssertEqual(vm.currentTopic?.slug, "opening")
    }

    func testOpenLinkIgnoresUnknownAndNonFileLinks() {
        let vm = HelpViewModel(topics: [topic("welcome", 1)])
        XCTAssertFalse(vm.openLink(URL(fileURLWithPath: "/Help/missing.md")))
        XCTAssertFalse(vm.openLink(URL(string: "https://example.com")!))
        XCTAssertEqual(vm.currentTopic?.slug, "welcome")
    }

    func testRunSearchPopulatesResultsAndClearWhenBlank() {
        let vm = HelpViewModel(topics: [topic("welcome", 1), topic("opening", 2)])
        vm.searchQuery = "opening"
        vm.runSearch()
        XCTAssertEqual(vm.results.map(\.topic.slug), ["opening"])
        vm.searchQuery = "   "
        vm.runSearch()
        XCTAssertTrue(vm.results.isEmpty)
    }

    func testOpenLinkToCurrentTopicReturnsTrueWithoutGrowingHistory() {
        let vm = HelpViewModel(topics: [topic("welcome", 1), topic("opening", 2)])
        XCTAssertTrue(vm.openLink(URL(fileURLWithPath: "/Help/welcome.md")))
        XCTAssertEqual(vm.currentTopic?.slug, "welcome")
        XCTAssertFalse(vm.canGoBack)
    }

    func testEmptyTopicsIsSafe() {
        let vm = HelpViewModel(topics: [])
        XCTAssertNil(vm.currentTopic)
        XCTAssertFalse(vm.canGoBack)
        XCTAssertFalse(vm.canGoForward)
        vm.goBack()
        vm.goForward()
        XCTAssertNil(vm.currentTopic)
        vm.searchQuery = "anything"
        vm.runSearch()
        XCTAssertTrue(vm.results.isEmpty)
        XCTAssertFalse(vm.openLink(URL(fileURLWithPath: "/Help/x.md")))
    }
}
