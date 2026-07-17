import XCTest
import YYText

final class YYTextLayoutSwiftImportTests: XCTestCase {
    func testApprovedSwiftNamesCallLayoutMethods() {
        let size = CGSize(width: 140, height: 80)
        let text = NSAttributedString(
            string: String(repeating: "Text flows through every container. ", count: 20),
            attributes: [.font: UIFont.systemFont(ofSize: 16)]
        )
        let container = YYTextContainer(size: size)
        let containers = [
            container,
            YYTextContainer(size: CGSize(width: 160, height: 100)),
        ]
        let range = NSRange(location: 0, length: text.length)

        let sizeLayout = YYTextLayout.layout(containerSize: size, text: text)
        let containerLayout = YYTextLayout.layout(container: container, text: text)
        let rangedLayout = YYTextLayout.layout(
            container: container,
            text: text,
            range: range
        )
        let layouts = YYTextLayout.layouts(containers: containers, text: text)
        let rangedLayouts = YYTextLayout.layouts(
            containers: containers,
            text: text,
            range: range
        )

        XCTAssertNotNil(sizeLayout)
        XCTAssertNotNil(containerLayout)
        XCTAssertNotNil(rangedLayout)
        XCTAssertEqual(layouts?.count, containers.count)
        XCTAssertEqual(rangedLayouts?.count, containers.count)
    }
}
