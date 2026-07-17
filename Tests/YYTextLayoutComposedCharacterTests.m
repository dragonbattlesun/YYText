#import <XCTest/XCTest.h>
#import <YYText/YYText.h>

@interface YYTextLayoutComposedCharacterTests : XCTestCase
@end

@implementation YYTextLayoutComposedCharacterTests

- (NSMutableAttributedString *)splitText:(NSString *)string
                          atUTF16Location:(NSUInteger)location {
    NSDictionary *baseAttributes = @{
        NSFontAttributeName : [UIFont systemFontOfSize:20],
        NSForegroundColorAttributeName : UIColor.whiteColor,
    };
    NSMutableAttributedString *text =
        [[NSMutableAttributedString alloc] initWithString:string
                                               attributes:baseAttributes];
    [text addAttribute:NSForegroundColorAttributeName
                 value:UIColor.grayColor
                 range:NSMakeRange(location, text.length - location)];
    return text;
}

- (YYTextLayout *)layoutForText:(NSAttributedString *)text {
    YYTextLayout *layout =
        [YYTextLayout layoutWithContainerSize:CGSizeMake(500, 500) text:text];
    XCTAssertNotNil(layout);
    return layout;
}

- (YYTextLayout *)layoutForText:(NSAttributedString *)text range:(NSRange)range {
    YYTextContainer *container =
        [YYTextContainer containerWithSize:CGSizeMake(500, 500)];
    YYTextLayout *layout =
        [YYTextLayout layoutWithContainer:container text:text range:range];
    XCTAssertNotNil(layout);
    return layout;
}

- (void)assertLayout:(YYTextLayout *)layout
 hasUniformAttributesInRange:(NSRange)range {
    NSDictionary *expected =
        [layout.text attributesAtIndex:range.location effectiveRange:NULL];
    for (NSUInteger index = range.location + 1;
         index < NSMaxRange(range);
         index++) {
        NSDictionary *actual =
            [layout.text attributesAtIndex:index effectiveRange:NULL];
        XCTAssertEqualObjects(actual, expected,
                              @"Attribute boundary remained at UTF-16 index %lu",
                              (unsigned long)index);
    }
}

- (void)assertLayoutHasNoRunBoundaryInsideRange:(YYTextLayout *)layout
                                           range:(NSRange)range {
    YYTextLine *line = layout.lines.firstObject;
    XCTAssertNotNil(line);
    CFArrayRef runs = CTLineGetGlyphRuns(line.CTLine);
    for (CFIndex index = 0; index < CFArrayGetCount(runs); index++) {
        CTRunRef run = CFArrayGetValueAtIndex(runs, index);
        CFRange runRange = CTRunGetStringRange(run);
        NSUInteger boundary = (NSUInteger)(runRange.location + runRange.length);
        BOOL boundaryIsInside = range.location < boundary && boundary < NSMaxRange(range);
        XCTAssertFalse(boundaryIsInside,
                       @"CoreText run boundary remained at UTF-16 index %lu",
                       (unsigned long)boundary);
    }
}

- (YYTextLayout *)assertNormalizesSource:(NSMutableAttributedString *)source
                           composedRange:(NSRange)range
                sourceAttributeLocations:(NSArray<NSNumber *> *)locations
                             layoutRange:(NSRange)layoutRange {
    NSString *originalString = [source.string copy];
    NSData *originalScalars =
        [originalString dataUsingEncoding:NSUTF32LittleEndianStringEncoding];
    NSDictionary *firstAttributes =
        [source attributesAtIndex:range.location effectiveRange:NULL];
    NSMutableArray<NSDictionary *> *originalAttributes =
        [NSMutableArray arrayWithCapacity:locations.count];
    BOOL hasDifferentAttributes = NO;
    for (NSNumber *location in locations) {
        NSDictionary *attributes =
            [source attributesAtIndex:location.unsignedIntegerValue
                       effectiveRange:NULL];
        [originalAttributes addObject:attributes];
        if (![attributes isEqual:firstAttributes]) {
            hasDifferentAttributes = YES;
        }
    }

    YYTextLayout *layout = [self layoutForText:source range:layoutRange];

    XCTAssertTrue(hasDifferentAttributes);
    XCTAssertEqualObjects([layout.text attributesAtIndex:range.location
                                           effectiveRange:NULL],
                          firstAttributes);
    [self assertLayout:layout hasUniformAttributesInRange:range];
    [self assertLayoutHasNoRunBoundaryInsideRange:layout range:range];

    [locations enumerateObjectsUsingBlock:^(NSNumber *location,
                                             NSUInteger index,
                                             BOOL *stop) {
        (void)stop;
        XCTAssertEqualObjects(
            [source attributesAtIndex:location.unsignedIntegerValue
                       effectiveRange:NULL],
            originalAttributes[index],
            @"YYTextLayout must not mutate source attributes");
    }];
    XCTAssertEqualObjects(source.string, originalString);
    XCTAssertEqualObjects(layout.text.string, originalString);
    XCTAssertEqualObjects(
        [source.string dataUsingEncoding:NSUTF32LittleEndianStringEncoding],
        originalScalars);
    XCTAssertEqualObjects(
        [layout.text.string dataUsingEncoding:NSUTF32LittleEndianStringEncoding],
        originalScalars);
    return layout;
}

- (void)assertNormalizesSplitComposedString:(NSString *)string
                            atUTF16Location:(NSUInteger)location {
    NSMutableAttributedString *source =
        [self splitText:string atUTF16Location:location];
    NSRange range =
        [string rangeOfComposedCharacterSequenceAtIndex:0];

    XCTAssertTrue(NSEqualRanges(range, NSMakeRange(0, string.length)));
    [self assertNormalizesSource:source
                  composedRange:range
       sourceAttributeLocations:@[@0, @(location)]
                    layoutRange:NSMakeRange(0, source.length)];
}

- (void)testNormalizesAttributeBoundaryInsideSurrogatePair {
    [self assertNormalizesSplitComposedString:@"😀" atUTF16Location:1];
}

- (void)testNormalizesDecomposedCharacterSequence {
    [self assertNormalizesSplitComposedString:@"e\u0301" atUTF16Location:1];
}

- (void)testNormalizesEmojiVariationSelectorSequence {
    NSMutableAttributedString *source = [self splitText:@"🅰️" atUTF16Location:2];
    YYTextLayout *layout = [self layoutForText:source];

    NSRange range = [source.string rangeOfComposedCharacterSequenceAtIndex:0];
    [self assertLayout:layout hasUniformAttributesInRange:range];
    [self assertLayoutHasNoRunBoundaryInsideRange:layout range:range];

    XCTAssertNotEqualObjects([source attribute:NSForegroundColorAttributeName
                                       atIndex:0
                                effectiveRange:NULL],
                             [source attribute:NSForegroundColorAttributeName
                                       atIndex:2
                                effectiveRange:NULL],
                             @"YYTextLayout must not mutate the source string");
}

- (void)testNormalizesJoinedEmojiWorkaroundBoundaryAcrossTrailingVariationSelector {
    NSString *string = @"👨‍👩‍👧‍👦️";
    NSMutableAttributedString *source = [self splitText:string atUTF16Location:2];
    [source yy_setClearColorToJoinedEmoji];
    [source setAttributes:@{
        NSFontAttributeName : [UIFont systemFontOfSize:18],
        NSForegroundColorAttributeName : UIColor.grayColor,
        NSBackgroundColorAttributeName : UIColor.yellowColor,
    } range:NSMakeRange(2, 3)];
    [source setAttributes:@{
        NSFontAttributeName : [UIFont systemFontOfSize:24],
        NSForegroundColorAttributeName : UIColor.blueColor,
        NSKernAttributeName : @2,
    } range:NSMakeRange(7, 2)];

    NSRange range = [string rangeOfComposedCharacterSequenceAtIndex:0];
    XCTAssertEqual(string.length, 12u);
    XCTAssertTrue(NSEqualRanges(range, NSMakeRange(0, string.length)));
    XCTAssertEqualObjects([source attribute:NSForegroundColorAttributeName
                                    atIndex:0
                             effectiveRange:NULL],
                          UIColor.clearColor);
    XCTAssertNotEqualObjects([source attribute:NSForegroundColorAttributeName
                                       atIndex:11
                                effectiveRange:NULL],
                             UIColor.clearColor);

    [self assertNormalizesSource:source
                  composedRange:range
       sourceAttributeLocations:@[@0, @2, @5, @7, @9, @11]
                    layoutRange:NSMakeRange(0, source.length)];
}

- (void)testNormalizesZeroWidthJoinerSequence {
    NSMutableAttributedString *source =
        [self splitText:@"👨‍👩‍👧‍👦" atUTF16Location:2];
    YYTextLayout *layout = [self layoutForText:source];
    NSRange range = [source.string rangeOfComposedCharacterSequenceAtIndex:0];

    [self assertLayout:layout hasUniformAttributesInRange:range];
    [self assertLayoutHasNoRunBoundaryInsideRange:layout range:range];
}

- (void)testNormalizesSkinToneModifierSequence {
    NSMutableAttributedString *source = [self splitText:@"👍🏽" atUTF16Location:2];
    YYTextLayout *layout = [self layoutForText:source];
    NSRange range = [source.string rangeOfComposedCharacterSequenceAtIndex:0];

    [self assertLayout:layout hasUniformAttributesInRange:range];
    [self assertLayoutHasNoRunBoundaryInsideRange:layout range:range];
}

- (void)testNormalizesRegionalIndicatorFlagSequence {
    NSMutableAttributedString *source = [self splitText:@"🇨🇳" atUTF16Location:2];
    YYTextLayout *layout = [self layoutForText:source];
    NSRange range = [source.string rangeOfComposedCharacterSequenceAtIndex:0];

    [self assertLayout:layout hasUniformAttributesInRange:range];
    [self assertLayoutHasNoRunBoundaryInsideRange:layout range:range];
}

- (void)testPreservesStylesBetweenAdjacentComposedCharacters {
    NSString *string = @"🅰️👍🏽";
    NSMutableAttributedString *source =
        [[NSMutableAttributedString alloc] initWithString:string
                                               attributes:@{
        NSFontAttributeName : [UIFont systemFontOfSize:20],
        NSForegroundColorAttributeName : UIColor.whiteColor,
    }];
    NSRange first = [string rangeOfComposedCharacterSequenceAtIndex:0];
    NSRange second = [string rangeOfComposedCharacterSequenceAtIndex:NSMaxRange(first)];
    [source addAttribute:NSForegroundColorAttributeName
                   value:UIColor.grayColor
                   range:NSMakeRange(first.location + 2, first.length - 2)];
    [source addAttribute:NSForegroundColorAttributeName
                   value:UIColor.blueColor
                   range:NSMakeRange(second.location, 2)];
    [source addAttribute:NSForegroundColorAttributeName
                   value:UIColor.grayColor
                   range:NSMakeRange(second.location + 2, second.length - 2)];

    YYTextLayout *layout = [self layoutForText:source];
    [self assertLayout:layout hasUniformAttributesInRange:first];
    [self assertLayout:layout hasUniformAttributesInRange:second];

    XCTAssertEqualObjects([layout.text attribute:NSForegroundColorAttributeName
                                          atIndex:first.location
                                   effectiveRange:NULL],
                          UIColor.whiteColor);
    XCTAssertEqualObjects([layout.text attribute:NSForegroundColorAttributeName
                                          atIndex:second.location
                                   effectiveRange:NULL],
                          UIColor.blueColor);
}

- (void)testNormalizesComposedSequenceInBoundaryAlignedNonFullRange {
    NSString *string = @"A🅰️B";
    NSRange range = [string rangeOfComposedCharacterSequenceAtIndex:1];
    NSMutableAttributedString *source =
        [self splitText:string atUTF16Location:range.location + 2];

    YYTextLayout *layout =
        [self assertNormalizesSource:source
                       composedRange:range
            sourceAttributeLocations:@[@(range.location),
                                       @(range.location + 2)]
                         layoutRange:range];

    XCTAssertTrue(NSEqualRanges(layout.range, range));
    XCTAssertTrue(NSEqualRanges(layout.visibleRange, range));
}

- (void)testEmptyTextPassesThroughLayoutRange {
    NSAttributedString *source =
        [[NSAttributedString alloc] initWithString:@""];
    YYTextLayout *layout = [self layoutForText:source range:NSMakeRange(0, 0)];

    XCTAssertEqualObjects(layout.text.string, source.string);
    XCTAssertEqual(layout.text.length, 0u);
    XCTAssertEqual(layout.lines.count, 0u);
    XCTAssertTrue(NSEqualRanges(layout.range, NSMakeRange(0, 0)));
}

- (void)testSingleUTF16UnitPassesThroughLayoutRange {
    NSMutableAttributedString *source =
        [self splitText:@"A" atUTF16Location:1];
    NSDictionary *sourceAttributes =
        [source attributesAtIndex:0 effectiveRange:NULL];
    YYTextLayout *layout = [self layoutForText:source range:NSMakeRange(0, 1)];

    XCTAssertEqualObjects(layout.text.string, source.string);
    XCTAssertEqualObjects([layout.text attributesAtIndex:0 effectiveRange:NULL],
                          sourceAttributes);
    XCTAssertEqualObjects([source attributesAtIndex:0 effectiveRange:NULL],
                          sourceAttributes);
    XCTAssertTrue(NSEqualRanges(layout.range, NSMakeRange(0, 1)));
}

- (void)testPreservesYYTextAttachmentAttributes {
    UIImage *image = [[UIImage alloc] init];
    NSMutableAttributedString *source =
        [NSMutableAttributedString yy_attachmentStringWithContent:image
                                                       contentMode:UIViewContentModeCenter
                                                             width:12
                                                            ascent:10
                                                           descent:2];
    [source appendAttributedString:
        [self splitText:@"🅰️" atUTF16Location:2]];

    YYTextLayout *layout = [self layoutForText:source];

    XCTAssertEqual(layout.attachments.count, 1u);
    XCTAssertNotNil([layout.text attribute:YYTextAttachmentAttributeName
                                  atIndex:0
                           effectiveRange:NULL]);
    XCTAssertNotNil([layout.text attribute:(id)kCTRunDelegateAttributeName
                                  atIndex:0
                           effectiveRange:NULL]);
}

@end
