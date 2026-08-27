---
name: doc-comment-wrap
description: Reflow Swift `///` documentation comments and DocC `.md` article prose to a 90-column source style. Use when doc comments or DocC articles have been collapsed to one line per paragraph (for example after copying comments from a SourceKit-generated .swiftinterface) and need to be re-wrapped for source readability, or when adding new public API doc comments or articles that should match the surrounding wrap style.
---

# Doc Comment Wrap

Reflow `///` doc comments and DocC `.md` articles so the source stays readable,
without changing a single rendered character. DocC ignores hard line breaks
inside a paragraph, so this is purely cosmetic: the generated documentation is
byte-for-byte identical before and after.

## Quick Start

From the repo root, dry-run then apply:

```bash
python3 .agents/skills/doc-comment-wrap/scripts/reflow_doc_comments.py Sources/**/*.swift
python3 .agents/skills/doc-comment-wrap/scripts/reflow_doc_comments.py --apply <files...>
```

Pass explicit file paths (or a shell glob). `.swift` files are reflowed in
`///` mode; `.md` files are reflowed in Markdown mode. Without `--apply` it only
reports which files would change.

## The Rule

1. **Max width 90 columns**, measured from column 0 (leading indentation +
   `///␣` + content, or the raw Markdown line). Greedy word wrap: pack words
   onto a line until the next word would exceed 90, then break.
2. **Never split a word.** A line whose content contains a URL or a `<doc:...>`
   link is left unbroken even if it exceeds 90.
3. **Prose** continuation lines use the plain `/// text` prefix (or no prefix in
   Markdown).
4. **List / parameter items** (`- `, `- Parameter x:`, `- Returns:`,
   `- Throws:`, ordered `1.`) hang-indent continuation lines to align under the
   item text:

   ```swift
   /// - Parameter predicate: A closure to evaluate whether two elements are equivalent,
   ///   for purposes of filtering. Return `true` from this closure to indicate that the
   ///   second element is a duplicate of the first.
   ```

   Sub-items nested under `- Parameters:` keep their extra indentation and hang
   relative to it.
5. **Callout asides** (`> Tip:`, `> Note:`, `> Important:`, `> Warning:`) keep
   the `> ` marker on the first line only; continuation lines use lazy
   continuation (no marker), which CommonMark and DocC treat as part of the same
   block quote:

   ```swift
   /// > Tip: The combined publisher doesn't produce elements until each of its upstream
   /// publishers publishes at least one element.
   ```
6. **Preserved verbatim:** blank lines, headings, fenced and indented code
   blocks, table rows (`| ... |`), and any line containing a URL/`<doc:>` link.

## Invariants to Verify

After reflowing, confirm the content is unchanged and the cap holds. The script
tokenizes on ASCII spaces only, so non-breaking spaces (U+00A0) and other
in-word characters are preserved.

- No rendered content changed: concatenate the prose text (excluding fenced code
  blocks), strip all whitespace, and compare against the pre-reflow version.
- No prose/list/aside line exceeds 90 columns (URL and code lines excluded).

A convenient end-to-end check is to build DocC before and after and confirm the
warning set is unchanged:

```bash
xcodebuild docbuild -scheme <Scheme> -destination 'platform=macOS' \
  -derivedDataPath /tmp/docc -quiet
```

## Notes

- Run only on hand-written sources. When a file is generated (for example from a
  `.gyb` template), reflow the template and regenerate rather than editing the
  generated output.
