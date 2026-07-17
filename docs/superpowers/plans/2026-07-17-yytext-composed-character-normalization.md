# YYText Composed Character Normalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent YYText/CoreText from splitting one composed character into multiple rendered glyph runs when its UTF-16 units have different attributed-string attributes.

**Architecture:** Add a private normalization pass at the `YYTextLayout` input boundary. It snapshots effective-attribute boundaries, identifies boundaries inside Foundation composed-character ranges, and applies the base unit's complete attribute dictionary to each affected range on YYText's private mutable copy.

**Tech Stack:** Objective-C, Foundation composed-character APIs, CoreText, UIKit, XCTest, Xcode project files.

## Global Constraints

- Cover emoji variation selectors, zero-width-joiner sequences, skin-tone modifiers, regional-indicator flags, surrogate pairs, and other composed sequences.
- Do not change YYText's public API.
- Do not mutate the caller's `NSAttributedString`.
- Do not remove or replace Unicode scalars.
- Preserve YYText attachments and styles on adjacent composed characters.
- Keep the framework deployment target at iOS 8.0 and add no dependency.
- Select an available iOS Simulator dynamically; do not hardcode a simulator name or UDID in the repository.

---

## File Structure

- Create `Tests/YYTextLayoutComposedCharacterTests.m`: public-behavior regression tests through `YYTextLayout`.
- Create `Tests/Info.plist`: metadata for the hostless XCTest bundle.
- Modify `Framework/YYText.xcodeproj/project.pbxproj`: add the `YYTextTests` unit-test target, link XCTest and YYText, and add target dependencies.
- Modify `Framework/YYText.xcodeproj/xcshareddata/xcschemes/YYText.xcscheme`: build and execute `YYTextTests` from the shared `YYText` scheme.
- Modify `YYText/Component/YYTextLayout.m`: add and invoke the private composed-character normalization helper.

---

### Task 1: Add the regression harness and implement composed-character normalization

**Files:**

- Create: `Tests/YYTextLayoutComposedCharacterTests.m`
- Create: `Tests/Info.plist`
- Modify: `Framework/YYText.xcodeproj/project.pbxproj`
- Modify: `Framework/YYText.xcodeproj/xcshareddata/xcschemes/YYText.xcscheme`
- Modify: `YYText/Component/YYTextLayout.m:345-410`

**Interfaces:**

- Consumes: `+[YYTextLayout layoutWithContainerSize:text:]`, `YYTextLayout.text`, `YYTextLayout.lines`, `YYTextLayout.attachments`, `YYTextAttachmentAttributeName`, and `kCTRunDelegateAttributeName`.
- Produces: private function `static void YYTextNormalizeComposedCharacterAttributes(NSMutableAttributedString *text)` inside `YYTextLayout.m`; no public interface changes.

- [ ] **Step 1: Add a hostless XCTest target to the Framework project**

Create `Tests/Info.plist` with this complete content:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
```

Update `Framework/YYText.xcodeproj/project.pbxproj` with one native target named `YYTextTests` whose product type is `com.apple.product-type.bundle.unit-test`. Configure it as follows:

```text
Product: YYTextTests.xctest
Sources: ../../Tests/YYTextLayoutComposedCharacterTests.m
Linked frameworks: XCTest.framework and YYText.framework
Target dependency: YYText
Debug and Release settings:
  CLANG_ENABLE_MODULES = YES
  CLANG_ENABLE_OBJC_ARC = YES
  CODE_SIGNING_ALLOWED = NO
  INFOPLIST_FILE = "$(SRCROOT)/../Tests/Info.plist"
  IPHONEOS_DEPLOYMENT_TARGET = 12.0
  LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @loader_path/Frameworks"
  PRODUCT_BUNDLE_IDENTIFIER = com.ibireme.YYTextTests
  PRODUCT_NAME = "$(TARGET_NAME)"
  SDKROOT = iphoneos
  TARGETED_DEVICE_FAMILY = "1,2"
```

Add `YYTextTests` to the project `targets` list and Products group. Add a test-only build entry and testable reference to `Framework/YYText.xcodeproj/xcshareddata/xcschemes/YYText.xcscheme`:

```xml
<BuildActionEntry
   buildForTesting = "YES"
   buildForRunning = "NO"
   buildForProfiling = "NO"
   buildForArchiving = "NO"
   buildForAnalyzing = "NO">
   <BuildableReference
      BuildableIdentifier = "primary"
      BlueprintIdentifier = "A17E57010000000000000001"
      BuildableName = "YYTextTests.xctest"
      BlueprintName = "YYTextTests"
      ReferencedContainer = "container:YYText.xcodeproj">
   </BuildableReference>
</BuildActionEntry>
```

```xml
<TestableReference skipped = "NO">
   <BuildableReference
      BuildableIdentifier = "primary"
      BlueprintIdentifier = "A17E57010000000000000001"
      BuildableName = "YYTextTests.xctest"
      BlueprintName = "YYTextTests"
      ReferencedContainer = "container:YYText.xcodeproj">
   </BuildableReference>
</TestableReference>
```

Use `A17E57010000000000000001` as the test target identifier in the project file and both scheme locations.

- [ ] **Step 2: Write the failing public-behavior regression tests**

Create `Tests/YYTextLayoutComposedCharacterTests.m`:

```objc
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
```

- [ ] **Step 3: Verify the regression tests fail for the missing normalization**

First validate the project structure without selecting a device:

```bash
xcodebuild -list \
  -project Framework/YYText.xcodeproj
```

Expected: the target list includes `YYText` and `YYTextTests`; the scheme list includes `YYText`.

Select any currently available simulator dynamically and run the focused suite. The selected identifier remains only in the shell process and is not saved in the repository.

```bash
DESTINATION_ID="$(xcrun simctl list devices available -j | jq -r '[.devices[][] | select(.isAvailable == true)][0].udid')"
test -n "$DESTINATION_ID"
xcodebuild test \
  -project Framework/YYText.xcodeproj \
  -scheme YYText \
  -destination "platform=iOS Simulator,id=$DESTINATION_ID" \
  -derivedDataPath /private/tmp/YYTextDerivedData \
  -only-testing:YYTextTests/YYTextLayoutComposedCharacterTests
```

Expected: the variation-selector, ZWJ, skin-tone, flag, and adjacent-style tests fail because `layout.text` retains internal attribute boundaries. The attachment assertions may already pass. A build error or simulator error is not an acceptable RED state; fix the test target until the behavior assertions fail.

- [ ] **Step 4: Add the minimal private normalization helper**

Add this static helper between the `YYTextLayout` private extension and `@implementation YYTextLayout` in `YYText/Component/YYTextLayout.m`:

```objc
static void YYTextNormalizeComposedCharacterAttributes(NSMutableAttributedString *text) {
    if (text.length < 2) return;

    NSString *string = text.string;
    NSMutableOrderedSet<NSValue *> *ranges = [NSMutableOrderedSet orderedSet];
    NSRange fullRange = NSMakeRange(0, text.length);

    [text enumerateAttributesInRange:fullRange
                             options:0
                          usingBlock:^(NSDictionary *attributes,
                                       NSRange range,
                                       BOOL *stop) {
        (void)attributes;
        (void)stop;
        NSUInteger boundary = NSMaxRange(range);
        if (boundary == 0 || boundary >= text.length) return;

        NSRange composedRange =
            [string rangeOfComposedCharacterSequenceAtIndex:boundary];
        if (composedRange.location < boundary) {
            [ranges addObject:[NSValue valueWithRange:composedRange]];
        }
    }];

    for (NSValue *value in ranges) {
        NSRange range = value.rangeValue;
        NSDictionary *attributes =
            [text attributesAtIndex:range.location effectiveRange:NULL];
        [text setAttributes:attributes range:range];
    }
}
```

Invoke it in `+[YYTextLayout layoutWithContainer:text:range:]` after the existing nil/range validation and before any CoreText workaround or framesetter creation:

```objc
    text = text.mutableCopy;
    container = container.copy;
    if (!text || !container) return nil;
    if (range.location + range.length > text.length) return nil;
    YYTextNormalizeComposedCharacterAttributes((NSMutableAttributedString *)text);
    container->_readonly = YES;
```

- [ ] **Step 5: Verify GREEN for the focused regression suite**

Run the same focused test command with the dynamically selected simulator identifier.

Expected: all six tests in `YYTextLayoutComposedCharacterTests` pass, with no crash, failed assertion, or test bundle loading error.

- [ ] **Step 6: Verify the framework and Demo still compile**

Build the framework for a generic simulator destination without code signing:

```bash
xcodebuild build \
  -project Framework/YYText.xcodeproj \
  -scheme YYText \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/YYTextFrameworkDerivedData \
  CODE_SIGNING_ALLOWED=NO
```

Build the Demo for a generic simulator destination without code signing:

```bash
xcodebuild build \
  -project Demo/YYTextDemo.xcodeproj \
  -scheme YYTextDemo \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/YYTextDemoDerivedData \
  CODE_SIGNING_ALLOWED=NO
```

Expected: both commands end with `** BUILD SUCCEEDED **`. Existing unrelated deprecation warnings may remain, but the changed files must introduce no new compiler warning.

- [ ] **Step 7: Review the final diff and commit the verified fix**

Run:

```bash
git diff --check
git diff -- YYText/Component/YYTextLayout.m Tests Framework/YYText.xcodeproj
git status --short
```

Confirm that the diff contains only the private normalization helper, its invocation, the test target, and the regression tests. Then commit:

```bash
git add YYText/Component/YYTextLayout.m \
  Tests/Info.plist \
  Tests/YYTextLayoutComposedCharacterTests.m \
  Framework/YYText.xcodeproj/project.pbxproj \
  Framework/YYText.xcodeproj/xcshareddata/xcschemes/YYText.xcscheme
git commit -m "fix: preserve composed emoji during layout"
```

Expected: the commit succeeds and `git status --short` is empty.

---

## Plan Self-Review

- The test suite covers every composed-sequence category and safety constraint in the approved design.
- The production function and invocation signatures are consistent throughout the plan.
- The implementation remains private and mutates only the layout copy.
- The plan contains no dependency, migration, public API, or unrelated refactor.
- Simulator selection remains runtime-dynamic and repository-local state is not used to pin a device.
