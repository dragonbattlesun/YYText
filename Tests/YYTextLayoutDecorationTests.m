#import <XCTest/XCTest.h>
#import <YYText/YYText.h>

@interface YYTextLayoutDecorationTests : XCTestCase
@end

@implementation YYTextLayoutDecorationTests

- (void)testStandardUnderlineRendersVisiblePixels {
    CGSize size = CGSizeMake(220, 64);
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc]
        initWithString:@"Underline"
        attributes:@{
            NSFontAttributeName : [UIFont systemFontOfSize:30],
            NSForegroundColorAttributeName : UIColor.blackColor,
        }];
    [text yy_setUnderlineStyle:NSUnderlineStyleSingle
                         range:NSMakeRange(0, text.length)];
    [text yy_setUnderlineColor:UIColor.redColor
                         range:NSMakeRange(0, text.length)];

    YYTextLayout *layout = [YYTextLayout
        layoutWithContainer:[YYTextContainer containerWithSize:size] text:text];
    XCTAssertNotNil(layout);

    size_t width = (size_t)size.width;
    size_t height = (size_t)size.height;
    NSMutableData *bitmap = [NSMutableData dataWithLength:width * height * 4];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(bitmap.mutableBytes,
                                                 width,
                                                 height,
                                                 8,
                                                 width * 4,
                                                 colorSpace,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedLast |
                                                     kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    XCTAssertNotNil((__bridge id)context);
    if (!context) return;

    CGContextSetFillColorWithColor(context, UIColor.whiteColor.CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
    [layout drawInContext:context size:size debug:nil];
    CGContextRelease(context);

    const uint8_t *pixels = bitmap.bytes;
    NSUInteger redPixelCount = 0;
    for (NSUInteger pixel = 0; pixel < width * height; pixel++) {
        const uint8_t *rgba = pixels + pixel * 4;
        if (rgba[0] > 200 && rgba[1] < 80 && rgba[2] < 80 && rgba[3] > 200) {
            redPixelCount++;
        }
    }
    XCTAssertGreaterThan(redPixelCount, 10u,
                         @"A standard underline should produce visible red pixels");
}

@end
