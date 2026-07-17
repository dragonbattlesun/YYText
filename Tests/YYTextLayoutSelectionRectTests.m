#import <XCTest/XCTest.h>
#import <YYText/YYText.h>

@interface YYTextLayoutSelectionRectTests : XCTestCase
@end

@implementation YYTextLayoutSelectionRectTests

- (void)testFirstRectIncludesAllFragmentsInStartingVisualRow {
    YYTextContainer *container =
        [YYTextContainer containerWithSize:CGSizeMake(320, 140)
                                     insets:UIEdgeInsetsZero];
    container.exclusionPaths = @[
        [UIBezierPath bezierPathWithRect:CGRectMake(115, 6, 70, 30)],
    ];
    NSAttributedString *text = [[NSAttributedString alloc]
        initWithString:@"abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz"
            attributes:@{
                NSFontAttributeName : [UIFont fontWithName:@"Menlo-Regular"
                                                     size:18],
            }];
    YYTextLayout *layout =
        [YYTextLayout layoutWithContainer:container text:text];
    XCTAssertNotNil(layout);

    YYTextLine *firstFragment = nil;
    YYTextLine *secondFragment = nil;
    YYTextLine *laterLine = nil;
    for (NSUInteger index = 0; index + 1 < layout.lines.count; index++) {
        YYTextLine *first = layout.lines[index];
        YYTextLine *second = layout.lines[index + 1];
        if (first.row != second.row) continue;

        for (NSUInteger laterIndex = index + 2;
             laterIndex < layout.lines.count;
             laterIndex++) {
            YYTextLine *candidate = layout.lines[laterIndex];
            if (candidate.row != first.row) {
                firstFragment = first;
                secondFragment = second;
                laterLine = candidate;
                break;
            }
        }
        if (laterLine) break;
    }

    XCTAssertNotNil(firstFragment,
                    @"Fixture must create consecutive fragments on one row");
    XCTAssertNotNil(secondFragment,
                    @"Fixture must create consecutive fragments on one row");
    XCTAssertNotNil(laterLine,
                    @"Fixture must create a line on a later visual row");
    if (!firstFragment || !secondFragment || !laterLine) return;

    XCTAssertEqual(firstFragment.row, secondFragment.row);
    XCTAssertEqual(NSIntersectionRange(firstFragment.range,
                                       secondFragment.range).length,
                   0u);
    XCTAssertNotEqual(firstFragment.row, laterLine.row);

    YYTextRange *range = [YYTextRange
        rangeWithStart:
            [YYTextPosition positionWithOffset:firstFragment.range.location]
                   end:[YYTextPosition
                           positionWithOffset:NSMaxRange(secondFragment.range)
                                     affinity:YYTextAffinityBackward]];
    CGRect actual = [layout firstRectForRange:range];
    CGRect expected = CGRectUnion(firstFragment.bounds, secondFragment.bounds);
    CGFloat tolerance = 0.01;

    XCTAssertEqualWithAccuracy(actual.origin.x, expected.origin.x, tolerance);
    XCTAssertEqualWithAccuracy(actual.origin.y, expected.origin.y, tolerance);
    XCTAssertEqualWithAccuracy(actual.size.width, expected.size.width, tolerance);
    XCTAssertEqualWithAccuracy(actual.size.height, expected.size.height, tolerance);
}

- (void)testFirstRectRetainsPrecisePartialRectWithinOneFragment {
    NSAttributedString *text = [[NSAttributedString alloc]
        initWithString:@"ordinary single fragment selection"
            attributes:@{NSFontAttributeName : [UIFont systemFontOfSize:18]}];
    YYTextLayout *layout =
        [YYTextLayout layoutWithContainerSize:CGSizeMake(400, 80) text:text];
    XCTAssertNotNil(layout);
    XCTAssertEqual(layout.lines.count, 1u);

    NSUInteger startOffset = 3;
    NSUInteger endOffset = 15;
    YYTextPosition *start =
        [YYTextPosition positionWithOffset:startOffset];
    YYTextPosition *end =
        [YYTextPosition positionWithOffset:endOffset];
    YYTextRange *range = [YYTextRange rangeWithStart:start end:end];
    CGRect actual = [layout firstRectForRange:range];
    CGRect startCaret = [layout caretRectForPosition:start];
    CGRect endCaret = [layout caretRectForPosition:end];
    YYTextLine *line = layout.lines.firstObject;
    CGFloat tolerance = 0.01;

    XCTAssertFalse(CGRectIsNull(actual));
    XCTAssertEqualWithAccuracy(actual.size.height, line.height, tolerance);
    XCTAssertEqualWithAccuracy(CGRectGetMinX(actual),
                               CGRectGetMinX(startCaret),
                               tolerance);
    XCTAssertEqualWithAccuracy(CGRectGetMaxX(actual),
                               CGRectGetMinX(endCaret),
                               tolerance);
}

@end
