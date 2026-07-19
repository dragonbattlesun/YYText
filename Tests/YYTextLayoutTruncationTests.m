#import <XCTest/XCTest.h>
#import <YYText/YYText.h>

@interface YYTextLayoutTruncationTests : XCTestCase
@end

@implementation YYTextLayoutTruncationTests

- (void)testTruncationContainerForcesTextLineBreakModeToWrap {
    // Reproduce issue #1018: when the container uses YYText truncation, the
    // attributed string's own truncation lineBreakMode must not cause CoreText
    // to add a second truncation marker.
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc]
        initWithString:@"This is a long string that should be truncated in the middle."
        attributes:@{
            NSFontAttributeName : [UIFont systemFontOfSize:16],
            NSParagraphStyleAttributeName : ({
                NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
                style.lineBreakMode = NSLineBreakByTruncatingTail;
                style;
            })
        }];
    XCTAssertEqual(text.yy_lineBreakMode, NSLineBreakByTruncatingTail);

    YYTextContainer *container = [YYTextContainer containerWithSize:CGSizeMake(120, 80)];
    container.maximumNumberOfRows = 1;
    container.truncationType = YYTextTruncationTypeMiddle;

    YYTextLayout *layout = [YYTextLayout layoutWithContainer:container text:text];
    XCTAssertNotNil(layout);
    XCTAssertEqual(layout.container.truncationType, YYTextTruncationTypeMiddle);
    XCTAssertEqual(layout.text.yy_lineBreakMode, NSLineBreakByWordWrapping);
}

- (void)testNonTruncationContainerPreservesTextLineBreakMode {
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc]
        initWithString:@"Short text."
        attributes:@{
            NSFontAttributeName : [UIFont systemFontOfSize:16],
            NSParagraphStyleAttributeName : ({
                NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
                style.lineBreakMode = NSLineBreakByTruncatingTail;
                style;
            })
        }];

    YYTextContainer *container = [YYTextContainer containerWithSize:CGSizeMake(120, 80)];
    container.truncationType = YYTextTruncationTypeNone;

    YYTextLayout *layout = [YYTextLayout layoutWithContainer:container text:text];
    XCTAssertNotNil(layout);
    XCTAssertEqual(layout.text.yy_lineBreakMode, NSLineBreakByTruncatingTail);
}

@end
