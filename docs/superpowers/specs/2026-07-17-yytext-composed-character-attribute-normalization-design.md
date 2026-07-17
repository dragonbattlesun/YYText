# YYText Composed Character Attribute Normalization Design

## Objective

Prevent CoreText from rendering a single user-perceived character as multiple glyphs when an attributed string contains an attribute boundary inside a composed character sequence. The fix must cover emoji variation selectors, zero-width-joiner sequences, skin-tone modifiers, regional-indicator flags, surrogate pairs, and other composed sequences without changing YYText's public API.

## Problem

CoreText shaping depends on attributed-string runs. A sequence such as `🅰️` (`U+1F170 U+FE0F`) can be split into different runs when its UTF-16 units carry different attributes. Older YYText rendering paths may then expose separate text-style or fallback glyphs instead of one emoji.

Callers should not need to sanitize attributed strings before assigning them to `YYLabel`, `YYTextView`, or passing them directly to `YYTextLayout`.

## Chosen Architecture

Normalize only invalid attribute boundaries at the central `YYTextLayout` input boundary. `YYTextLayout` already creates a mutable copy of the caller's attributed string before building CoreText objects, so normalization will modify only that private layout copy.

The implementation will be a private helper in `YYTextLayout.m`; it will not add a public method or alter existing headers.

## Normalization Algorithm

1. Enumerate the effective attribute ranges in the copied attributed string and snapshot each interior range boundary.
2. For each boundary, ask `NSString` for the composed character sequence containing the UTF-16 index at that boundary.
3. Ignore boundaries that are already at the start of a composed sequence.
4. Collect each composed range that contains one or more internal attribute boundaries, deduplicating ranges when a sequence contains several boundaries.
5. For every collected range, copy the complete attribute dictionary from the first UTF-16 unit across the entire composed range.
6. Continue with the existing CoreText framesetter and layout construction.

The first unit wins because it is the base of variation-selector and combining sequences. A semantic or visual attribute boundary inside one grapheme is not meaningful to display, selection, or accessibility.

## Compatibility and Safety

- The source `NSAttributedString` remains unchanged.
- Plain text and composed sequences whose attributes are already uniform are not rewritten.
- Styles on adjacent composed characters remain independent.
- YYText attachments remain intact. Standard attachments use the single-unit `U+FFFC` token, so they contain no internal composed-sequence boundary.
- No Unicode scalar is removed or replaced; `U+FE0F`, joiners, modifiers, and regional indicators remain in the string.
- The implementation uses Foundation composed-character APIs available at the library's current deployment target and introduces no dependency.

## Error Handling

Nil and empty attributed strings continue through the existing validation behavior. The helper returns immediately for strings shorter than two UTF-16 units or for strings with fewer than two effective attribute ranges. Invalid caller-supplied layout ranges continue to be rejected by the existing range validation.

## Tests

Add a small XCTest target that exercises the behavior through `YYTextLayout`, rather than testing the private helper directly.

The regression suite will verify:

- `🅰️` with an attribute boundary before `U+FE0F` becomes one uniformly attributed composed sequence in the layout copy.
- A family ZWJ sequence becomes uniformly attributed.
- A skin-tone sequence becomes uniformly attributed.
- A regional-indicator flag becomes uniformly attributed.
- Adjacent composed characters retain their separate styles.
- A `YYTextAttachment` and its `CTRunDelegate` remain attached to `U+FFFC`.
- The caller's original attributed string retains its deliberately split attributes.
- A CoreText line produced from the normalized layout does not contain a run boundary inside the tested composed sequence.

Each regression test must fail against the current implementation before the production patch is added.

## Out of Scope

- Replacing Unicode emoji with image attachments.
- Removing variation selectors or zero-width joiners.
- Migrating YYText from CoreText to TextKit.
- Changing selection semantics for callers that intentionally address an index inside a grapheme.
- Refactoring unrelated YYText rendering code.
