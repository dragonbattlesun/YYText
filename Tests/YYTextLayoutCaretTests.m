#import <XCTest/XCTest.h>
#import <YYText/YYText.h>

@interface YYTextLayoutCaretTests : XCTestCase
@end

@implementation YYTextLayoutCaretTests

- (void)assertClosestPositionUsesNearestComposedCharacterEdgeInVerticalForm:(BOOL)verticalForm {
    // The spacing mark remains in one composed sequence while exposing an
    // internal CoreText hit position on current SDKs.
    NSString *string = @"A😀\u0903B";
    NSMutableDictionary *attributes = [@{
        NSFontAttributeName : [UIFont systemFontOfSize:24],
    } mutableCopy];
    if (verticalForm) {
        attributes[NSVerticalGlyphFormAttributeName] = @YES;
    }
    NSAttributedString *text =
        [[NSAttributedString alloc] initWithString:string
                                       attributes:attributes];
    CGSize containerSize = verticalForm
        ? CGSizeMake(YYTextContainerMaxSize.width, 500)
        : CGSizeMake(500, 500);
    YYTextContainer *container =
        [YYTextContainer containerWithSize:containerSize];
    container.verticalForm = verticalForm;
    container.isAutoLayout = verticalForm;
    YYTextLayout *layout =
        [YYTextLayout layoutWithContainer:container text:text];
    XCTAssertNotNil(layout);

    NSRange range =
        [string rangeOfComposedCharacterSequenceAtIndex:1];
    XCTAssertGreaterThan(range.length, 1u);

    CGRect leadingRect =
        [layout caretRectForPosition:
            [YYTextPosition positionWithOffset:range.location]];
    CGRect trailingRect =
        [layout caretRectForPosition:
            [YYTextPosition positionWithOffset:NSMaxRange(range)]];
    XCTAssertFalse(CGRectIsNull(leadingRect));
    XCTAssertFalse(CGRectIsNull(trailingRect));

    CGFloat leadingCoordinate = verticalForm ? CGRectGetMinY(leadingRect)
                                             : CGRectGetMinX(leadingRect);
    CGFloat trailingCoordinate = verticalForm ? CGRectGetMinY(trailingRect)
                                              : CGRectGetMinX(trailingRect);
    XCTAssertNotEqual(leadingCoordinate, trailingCoordinate);

    CGFloat leadingQueryCoordinate =
        leadingCoordinate + (trailingCoordinate - leadingCoordinate) * 0.4;
    CGFloat trailingQueryCoordinate =
        leadingCoordinate + (trailingCoordinate - leadingCoordinate) * 0.6;
    CGPoint leadingQueryPoint = verticalForm
        ? CGPointMake(CGRectGetMidX(leadingRect), leadingQueryCoordinate)
        : CGPointMake(leadingQueryCoordinate, CGRectGetMidY(leadingRect));
    CGPoint trailingQueryPoint = verticalForm
        ? CGPointMake(CGRectGetMidX(trailingRect), trailingQueryCoordinate)
        : CGPointMake(trailingQueryCoordinate, CGRectGetMidY(trailingRect));

    YYTextPosition *leadingResult =
        [layout closestPositionToPoint:leadingQueryPoint];
    YYTextPosition *trailingResult =
        [layout closestPositionToPoint:trailingQueryPoint];

    XCTAssertEqual(leadingResult.offset, range.location);
    XCTAssertEqual(trailingResult.offset, NSMaxRange(range));
    XCTAssertFalse(range.location < leadingResult.offset &&
                   leadingResult.offset < NSMaxRange(range));
    XCTAssertFalse(range.location < trailingResult.offset &&
                   trailingResult.offset < NSMaxRange(range));
}

- (void)testClosestPositionUsesNearestComposedCharacterEdgeHorizontally {
    [self assertClosestPositionUsesNearestComposedCharacterEdgeInVerticalForm:NO];
}

- (void)testClosestPositionUsesNearestComposedCharacterEdgeVertically {
    [self assertClosestPositionUsesNearestComposedCharacterEdgeInVerticalForm:YES];
}

@end
