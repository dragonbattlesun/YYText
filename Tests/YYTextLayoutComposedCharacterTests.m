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
