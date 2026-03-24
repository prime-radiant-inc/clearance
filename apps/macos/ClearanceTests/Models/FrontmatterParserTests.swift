import XCTest
@testable import Clearance

final class FrontmatterParserTests: XCTestCase {
    func testParsesFrontmatterAndBody() {
        let markdown = """
        ---
        title: Sample
        tags:
          - one
          - two
        ---
        # Heading

        body text
        """

        let parsed = FrontmatterParser().parse(markdown: markdown)

        XCTAssertEqual(parsed.body, "# Heading\n\nbody text")
        XCTAssertEqual(parsed.flattenedFrontmatter["title"], "Sample")
        XCTAssertEqual(parsed.flattenedFrontmatter["tags[0]"], "one")
        XCTAssertEqual(parsed.flattenedFrontmatter["tags[1]"], "two")
    }

    func testLeavesMarkdownUntouchedWhenNoFrontmatter() {
        let markdown = "# Hello\n\nworld"

        let parsed = FrontmatterParser().parse(markdown: markdown)

        XCTAssertEqual(parsed.body, markdown)
        XCTAssertTrue(parsed.flattenedFrontmatter.isEmpty)
        XCTAssertEqual(parsed.headings.map(\.title), ["Hello"])
    }

    func testFlattensNestedObjectsAndArrays() {
        let markdown = """
        ---
        seo:
          title: Deep
          keywords:
            - alpha
            - beta
        nested:
          object:
            value: 12
        ---
        Body
        """

        let parsed = FrontmatterParser().parse(markdown: markdown)

        XCTAssertEqual(parsed.flattenedFrontmatter["seo.title"], "Deep")
        XCTAssertEqual(parsed.flattenedFrontmatter["seo.keywords[0]"], "alpha")
        XCTAssertEqual(parsed.flattenedFrontmatter["seo.keywords[1]"], "beta")
        XCTAssertEqual(parsed.flattenedFrontmatter["nested.object.value"], "12")
    }

    func testParsesHeadingsFromBodyAfterFrontmatter() {
        let markdown = """
        ---
        title: Sample
        ---
        # Top
        ## Child
        """

        let parsed = FrontmatterParser().parse(markdown: markdown)

        XCTAssertEqual(parsed.headings.map(\.title), ["Top", "Child"])
        XCTAssertEqual(parsed.headings.map(\.level), [1, 2])
    }

    func testIgnoresHeadingsInsideFencedCodeBlocks() {
        let markdown = """
        # Keep

        ```md
        # Ignore
        ```

        ## Also Keep
        """

        let parsed = FrontmatterParser().parse(markdown: markdown)

        XCTAssertEqual(parsed.headings.map(\.title), ["Keep", "Also Keep"])
    }
}
