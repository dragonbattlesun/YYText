# YYText Layout Issues #1023, #1004, and #1001 Design

**Date:** 2026-07-17

## Goal

Fix three confirmed defects in `YYTextLayout` while preserving the existing
Objective-C API and avoiding a broader layout-engine refactor:

- #1023: invalid chained comparisons break Xcode 26 builds and select the
  wrong text position near composed character sequences.
- #1004: multi-container layout methods return an empty array and collide when
  imported into Swift.
- #1001: `firstRectForRange:` inspects only the first line fragment even when a
  visual row contains multiple fragments.

Each defect will have focused regression coverage and an independent commit.

## Compatibility Boundary

- Keep every existing Objective-C selector unchanged.
- Preserve existing return behavior for invalid arguments and failed layouts.
- Keep the current minimum deployment target and supported text-layout modes.
- Do not change composed-character detection, line construction, or general
  selection geometry beyond the confirmed defects.
- Do not introduce a public wrapper type or refactor the layout pipeline.

## #1023: Composed-Character Caret Position

### Problem

Four branches in `closestPositionToPoint:` use a chained comparison shaped
like this:

```objc
fabs(left - coordinate) < fabs(right - coordinate) < (right ? prev : next)
```

Objective-C evaluates the first comparison to `0` or `1` and then compares
that value with a text position. The final boolean is assigned to `position`.
Newer compilers diagnose the expression, and the result does not represent the
nearest valid text boundary.

### Change

Replace all four expressions with an explicit nearest-edge choice:

```objc
position = fabs(left - coordinate) < fabs(right - coordinate)
         ? prev
         : next;
```

The same correction applies to horizontal and vertical layout branches and to
both the general composed-sequence and emoji-specific paths. A tie continues
to choose `next`, matching the false branch of the comparison.

### Verification

Public API tests will ask `closestPositionToPoint:` for positions near both
visual edges of a composed emoji in horizontal and vertical layouts. Returned
offsets must be the sequence start or end and must never split its UTF-16
representation.

The final framework build will run without the historical
`-Wno-parentheses` workaround so Xcode 26 validates the source directly.

## #1004: Multi-Container Results and Swift Import Names

### Problem

`layoutWithContainers:text:range:` creates each layout and advances its text
range, but never appends the layout to the mutable result array. Valid calls
therefore return an empty array.

In addition, Swift import heuristics can collapse the singular
`layoutWithContainer:...` and plural `layoutWithContainers:...` selectors to
the same Swift base name.

### Runtime Change

Append every successfully created layout to the result array before advancing
to the next visible range. Preserve the current early `nil` return when a
container cannot produce a layout. An empty container array continues to
return an empty array.

The resulting array must:

1. Contain one layout for each processed container.
2. Preserve the input container order.
3. Use the end of each layout's `visibleRange` as the next layout's start.

### Swift Names

Add `NS_SWIFT_NAME` annotations without changing Objective-C selectors:

| Objective-C method family | Swift import name |
| --- | --- |
| container size | `layout(containerSize:text:)` |
| one container | `layout(container:text:)` |
| one container and range | `layout(container:text:range:)` |
| multiple containers | `layouts(containers:text:)` |
| multiple containers and range | `layouts(containers:text:range:)` |

Using the plural Swift base name for array-returning methods makes the two API
families unambiguous while retaining source and binary compatibility for
Objective-C callers.

### Verification

Objective-C tests will verify result count, order, continuous visible ranges,
and the empty-input case. A Swift test source will call all five intended
import names so the compiler guards against future importer collisions or
incorrect annotation spelling.

## #1001: First Rect Across Same-Row Fragments

### Problem

`firstRectForRange:` calculates `startLineIndex` and `endLineIndex`, but its
collection loop is bounded by `i <= startLineIndex`. It can therefore collect
only one line fragment. Existing branches for `lines.count > 1` become
unreachable even when an exclusion path splits one visual row into multiple
fragments.

### Change

Use the calculated end index as the loop bound:

```objc
for (NSUInteger i = startLineIndex; i <= endLineIndex; i++)
```

Keep the existing row check. Collection stops as soon as a fragment belongs to
a different row, so the method combines only the fragments of the first visual
row rather than expanding into later rows.

### Verification

A geometry test will use an exclusion path to split one visual row into
multiple line fragments, select text spanning those fragments, and compare the
returned first rectangle with their expected union. A normal single-fragment
case will remain as a baseline.

## Test and Build Strategy

Tests will exercise public `YYTextLayout` APIs wherever possible. The existing
hostless XCTest target will gain focused Objective-C cases and a small Swift
import test. Project changes will be limited to registering those test sources
and the Swift test-target settings required by Xcode.

Final verification will include:

1. All `YYTextTests` passing.
2. YYText framework building without `-Wno-parentheses`.
3. The demo application building successfully.
4. A clean diff review confirming that only the three fixes, tests, project
   wiring, and planning documents are included.

## Commit Structure

Implementation will use three independently reviewable commits:

1. Fix composed-character caret edge selection (#1023).
2. Restore multi-container results and disambiguate Swift imports (#1004).
3. Include all same-row fragments in `firstRectForRange:` (#1001).

If a test requires shared test infrastructure, that infrastructure will be
introduced with the first commit that needs it and kept narrowly scoped.
