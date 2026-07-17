#import <XCTest/XCTest.h>
#import <YYText/YYText.h>

@interface YYTextLayoutContainersTests : XCTestCase
@end

@implementation YYTextLayoutContainersTests

- (NSArray<YYTextContainer *> *)containers {
    return @[
        [YYTextContainer containerWithSize:CGSizeMake(120, 54)],
        [YYTextContainer containerWithSize:CGSizeMake(140, 72)],
        [YYTextContainer containerWithSize:CGSizeMake(160, 90)],
    ];
}

- (NSAttributedString *)flowingText {
    NSMutableString *string = [NSMutableString string];
    for (NSUInteger index = 0; index < 40; index++) {
        [string appendFormat:@"Paragraph %lu fills each layout container with text. ",
                             (unsigned long)index];
    }
    return [[NSAttributedString alloc]
        initWithString:string
            attributes:@{NSFontAttributeName : [UIFont systemFontOfSize:16]}];
}

- (void)assertLayouts:(NSArray<YYTextLayout *> *)layouts
       matchContainers:(NSArray<YYTextContainer *> *)containers {
    XCTAssertEqual(layouts.count, containers.count);
    for (NSUInteger index = 0; index < layouts.count; index++) {
        XCTAssertTrue(CGSizeEqualToSize(layouts[index].container.size,
                                        containers[index].size));
        XCTAssertGreaterThan(layouts[index].visibleRange.length, 0u);
        if (index + 1 < layouts.count) {
            XCTAssertEqual(NSMaxRange(layouts[index].visibleRange),
                           layouts[index + 1].visibleRange.location);
        }
    }
}

- (void)testLayoutsFollowContainersInOrderAndAdvanceContinuously {
    NSArray<YYTextContainer *> *containers = [self containers];
    NSArray<YYTextLayout *> *layouts =
        [YYTextLayout layoutWithContainers:containers text:[self flowingText]];

    XCTAssertNotNil(layouts);
    [self assertLayouts:layouts matchContainers:containers];
}

- (void)testRangedLayoutsBeginAtRequestedLocation {
    NSArray<YYTextContainer *> *containers = [self containers];
    NSAttributedString *text = [self flowingText];
    NSRange range = NSMakeRange(11, text.length - 11);
    NSArray<YYTextLayout *> *layouts =
        [YYTextLayout layoutWithContainers:containers text:text range:range];

    XCTAssertNotNil(layouts);
    [self assertLayouts:layouts matchContainers:containers];
    XCTAssertEqual(layouts.firstObject.visibleRange.location, range.location);
}

- (void)testEmptyContainersReturnNonNilEmptyArray {
    NSArray<YYTextLayout *> *layouts =
        [YYTextLayout layoutWithContainers:@[] text:[self flowingText]];

    XCTAssertNotNil(layouts);
    XCTAssertEqual(layouts.count, 0u);
}

@end
