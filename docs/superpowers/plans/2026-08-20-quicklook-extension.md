# Quick Look Preview Extension — Plan

> **Status**: scoping only. No implementation has started.
> **Reason**: Tasks 1 and 2 modify `project.pbxproj` and create a new target.
> Both are unverifiable without Xcode, and the plan document explicitly asks
> to stop before producing a potentially invalid `.pbxproj`.

## Why this plan exists

Markdown Read-Only is a read-only Markdown reader. Every other reader on the
App Store is a file manager plus a share extension. The only angle where
this app can stand out is **system preview**: tap Space on a `.md` in
Files, or open a Markdown attachment in Mail, and the document renders
without launching the app.

A Quick Look Preview Extension is the supported surface for that. The
existing rendering code (`MarkdownPreviewView`, `MarkdownPreviewTheme`,
`CodeSyntaxHighlighter`, `CodePalette`, `EditorTheme`) is exactly what
the extension needs to host. No duplication, no fork.

## Tâche 0 — Scope decisions (audited, not implemented)

### Step 1 — UTI to declare

**Decision**: `QLSupportedContentTypes = ["net.daringfireball.markdown"]` only.

The app already imports this UTI in `MarkdownReadOnly/Info.plist`:

```xml
<key>UTImportedTypeDeclarations</key>
<array>
  <dict>
    <key>UTTypeConformsTo</key>
    <array><string>public.plain-text</string></array>
    <key>UTTypeIdentifier</key>
    <string>net.daringfireball.markdown</string>
    <key>UTTypeTagSpecification</key>
    <dict>
      <key>public.filename-extension</key>
      <array><string>md</string><string>markdown</string><string>mdown</string></array>
      <key>public.mime-type</key>
      <array><string>text/markdown</string></array>
    </dict>
  </dict>
</array>
```

The extension will reuse the same UTI. Declaring `public.plain-text`
would intercept every `.txt` on the device — iOS already has a sensible
default for plain text, and the user-facing complaint about Markdown
app turf wars is precisely what this avoids.

### Step 2 — Thumbnail extension

**Decision**: out of scope. A Thumbnail Extension is a separate target
that produces the icons in Files' grid view. It would double the debug
surface for a secondary benefit. Re-evaluate once the preview is stable.

### Step 3 — Current system behaviour (NOT verified)

**Status**: cannot be executed on this machine. No Xcode, no iOS
simulator, no physical device.

The current behaviour when the user taps Space on a `.md` in Files is
*"whatever the system provides for the Markdown UTI or for plain text"*.
On a freshly installed build of this app, that is the same as no
extension at all: the generic text rendering. Without a baseline
captured on a real device, the post-implementation verification cannot
prove that the extension *works* rather than just *reproduces the
default*.

This baseline must be captured on hardware before Tasks 1–6 are
executed. The intended workflow is:

1. Install the current build on a test iPhone.
2. Open Files, navigate to a `.md`, tap Space.
3. Record what appears (text-only preview, generic Markdown preview, or
   a real Markdown render).
4. Repeat after implementation, compare.

## Tâche 1 — Target creation (BLOCKED)

Cannot be done without Xcode. The current project layout:

```
project.pbxproj — 21 977 bytes, 3 targets:
  - MarkdownReadOnly         (PBXFileSystemSynchronizedRootGroup → MarkdownReadOnly/)
  - MarkdownReadOnlyTests    (PBXFileSystemSynchronizedRootGroup → MarkdownReadOnlyTests/)
  - MarkdownReadOnlyUITests  (PBXFileSystemSynchronizedRootGroup → MarkdownReadOnlyUITests/)
```

Adding a fourth target requires editing `project.pbxproj` to declare:

- A new `PBXNativeTarget` with `productType = "com.apple.product-type.app-extension"`.
- A new `PBXFileSystemSynchronizedRootGroup` for `MarkdownReadOnlyQuickLook/`.
- A new `PBXBuildFile` entry per shared source file
  (`MarkdownPreviewView.swift`, `MarkdownPreviewTheme.swift`,
  `CodeSyntaxHighlighter.swift`, `CodePalette.swift`, `EditorTheme.swift`).
- A new `PBXBuildFile` entry per font (`JetBrainsMono-{Regular,Italic,
  Bold,BoldItalic}.ttf`) in Copy Bundle Resources.
- A new `PBXContainerItemProxy` and `PBXTargetDependency` linking the
  extension to the host app.
- A new `PBXCopyFilesBuildPhase` with `dstSubfolderSpec = 13` (Plugins)
  on the host app embedding the extension.
- A new `PBXFrameworksBuildPhase` adding the MarkdownUI Swift package
  to the extension target.

Hand-editing `pbxproj` is fragile — the file format is unforgiving and
a single typo or missing UUID regenerates the project on next open in
Xcode. Doing this without `xcodebuild` to validate is reckless.

**Action**: wait for Xcode, then create the target through the File →
New → Target menu so Xcode writes the canonical `.pbxproj` itself.

## Tâche 2 — PreviewViewController (BLOCKED on Tâche 1)

Cannot write code into a target that does not exist. The code proposed
in the plan is correct in shape:

- `UIHostingController<MarkdownPreviewView>` for the SwiftUI bridge.
- `addChild` → `view.addSubview` → `NSLayoutConstraint.activate` →
  `didMove(toParent:)` for the containment dance.
- A `horizontalInset` of 12 pt on leading and trailing to leave the
  Quick Look swipe gesture a target (the bug is real: without the gutter,
  the host view consumes the side-swipe and the user cannot move
  between previews).

But the file is part of the new target, so it stays in the plan, not
on disk.

## Tâche 3 — PreviewLoader (BLOCKED on Tâche 1)

The `PreviewLoader` enum and its test suite are correct in shape. The
implementation is the same UTF-8 / Latin-1 fallback DocumentLibrary
already uses, plus a `droppingPartialScalar` trim to avoid a U+FFFD
artifact at the read boundary.

The plan's own observation is the right one: there are three options for
the duplication today — (a) duplicate, (b) extract `TextDecoding`, (c)
make `DocumentLibrary` a member of the extension. (c) is excluded
because the library is private to the app. (b) is the right move and
should accompany Tâche 3. (a) is acceptable only as an intermediate step.

This is Tasks 3 + 4 combined: extract `TextDecoding` as a shared
nonisolated enum, use it from both targets, and move the UTF-8 trimming
tests over.

## Tâche 4 — Shared TextDecoding (BLOCKED on Tâche 1)

Move `decode(_:)` and `droppingPartialScalar(_:)` from `DocumentLibrary`
to a new `MarkdownReadOnly/TextDecoding.swift`, member of both targets.
The current `DocumentLibraryTests` tests that pin the UTF-8 trimming
behaviour must be moved to a new `TextDecodingTests`, assertions
unchanged.

The tests exist in spirit (the `decode` and `droppingPartialScalar`
helpers are private to DocumentLibrary but the behaviour is exercised by
`readPrefix`-driven tests). They need to be re-nailed as direct
unit tests on `TextDecoding` so they can run against the extension
target too.

## Tâche 5 — Non-regression guard on shared rendering

`SharedRenderingTests.testHighlighterIsDeterministicForSwift` is a
weak guard: it only asserts that running the highlighter twice on the
same input gives the same output. It cannot detect divergence between
the app and the extension if both call the same shared code.

The plan acknowledges this. The real visual identity test is manual
side-by-side comparison in Tâche 6.

## Tâche 6 — Manual verification (BLOCKED on all the above)

This is the only task that proves the extension works. It is not
automatable. It must run on hardware, with a known `.md`, and compare
to the baseline captured in Tâche 0 Step 3.

## Tâche 7 — Documentation (independent of code)

Three changes, all storable in git without Xcode:

- `docs/architecture.md` — new section under "Module map" describing the
  extension target, the exact list of files shared between the two
  targets, and the reason `DocumentLibrary` is excluded.
- `AGENTS.md` — two new rules: (a) new rendering files must be evaluated
  for membership in both targets; (b) any asset used by the extension
  must be declared in its `Info.plist` (`UIAppFonts`, asset catalog).
- `README.md` — feature line: "Quick Look preview: tap Space on a `.md`
  in Files to read it without launching the app."

These can be done at any time. They are not done here because the
feature does not exist yet — writing them now would be premature.

## What this plan explicitly does NOT do

- Modify `project.pbxproj` without Xcode.
- Write `PreviewViewController.swift` or `PreviewLoader.swift` into a
  directory that has no target membership.
- Touch `DocumentLibrary` unless Tâche 4 is being executed alongside
  the new target creation.
- Add any dependency on the extension to the existing build phase.
- Claim the extension works.

## Recommendation

Execute this plan on a Mac with Xcode 26.6 and iOS 26 hardware. The
preview code is short enough to type in one sitting and the verification
is the long pole. Budget: roughly two hours on hardware, one commit
per task, eyes on the device.

**Verification not run: no Xcode environment.**
