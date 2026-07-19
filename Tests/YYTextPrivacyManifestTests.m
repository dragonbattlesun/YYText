#import <XCTest/XCTest.h>
#import <YYText/YYText.h>

@interface YYTextPrivacyManifestTests : XCTestCase
@end

@implementation YYTextPrivacyManifestTests

- (void)testFrameworkBundlesANonTrackingPrivacyManifest {
    NSBundle *bundle = [NSBundle bundleForClass:YYTextLayout.class];
    NSURL *manifestURL = [bundle URLForResource:@"PrivacyInfo"
                                  withExtension:@"xcprivacy"];
    XCTAssertNotNil(manifestURL);
    if (!manifestURL) return;

    NSDictionary *manifest = [NSDictionary dictionaryWithContentsOfURL:manifestURL];
    XCTAssertNotNil(manifest);
    XCTAssertEqualObjects(manifest[@"NSPrivacyTracking"], @NO);
    XCTAssertEqualObjects(manifest[@"NSPrivacyTrackingDomains"], @[]);
    XCTAssertEqualObjects(manifest[@"NSPrivacyCollectedDataTypes"], @[]);
    XCTAssertEqualObjects(manifest[@"NSPrivacyAccessedAPITypes"], @[]);
}

@end
