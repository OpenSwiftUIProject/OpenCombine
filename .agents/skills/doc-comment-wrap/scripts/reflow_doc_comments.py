#!/usr/bin/env python3
"""Reflow Swift `///` doc comments to a 90-column width.

Cosmetic only: rewraps prose and list-item text so no line exceeds 90 columns
(indentation + `///` + content). Rendered DocC output is unchanged.

Rules (see SKILL.md):
  - Max line width 90 columns, measured from column 0.
  - Greedy word wrap; never split a word.
  - Lines that contain a URL are left unbroken (matches swiftlint ignores_urls).
  - Prose continuation: `/// text`.
  - List / parameter item continuation hangs to align under the item text: the
    marker (`- `, `- Parameter x: `, `- Returns: `, `- foo:`) sets the hang;
    continuation lines are indented with spaces to that column after `///`.
  - Blank `///` lines, indented code-example lines (>= 4 spaces after `///`),
    and content inside fenced/`> ` asides' code are preserved verbatim.
"""
from __future__ import annotations
import re
import sys

MAX = 90


def leading_spaces(text: str) -> int:
    return len(text) - len(text.lstrip(" "))


def is_doc(line: str) -> bool:
    return line.lstrip().startswith("///")


def doc_indent(line: str) -> str:
    """The whitespace before `///`."""
    return line[: len(line) - len(line.lstrip(" "))]


def content_after_marker(line: str) -> str:
    """Everything after the leading `///` (including the usual single space)."""
    idx = line.index("///")
    return line[idx + 3 :]


URL_RE = re.compile(r"https?://|<doc:|www\.")

# A list/param item marker like "- ", "- Parameter foo: ", "- Returns: ".
ITEM_RE = re.compile(r"^(\s*)-\s+(?:(?:Parameter\s+\w+|Returns|Throws|Parameters)\s*:\s*)?")


def split_words(text: str) -> list[str]:
    """Tokenize on ASCII spaces only, preserving non-breaking spaces (U+00A0)
    and other in-word whitespace so reflow never rewrites content characters."""
    return [w for w in text.split(" ") if w != ""]


def strip_ascii(text: str) -> str:
    return text.strip(" \t")


def wrap_words(words: list[str], first_prefix: str, cont_prefix: str) -> list[str]:
    """Greedy-wrap words. `first_prefix`/`cont_prefix` are full column-0 prefixes."""
    lines: list[str] = []
    cur = first_prefix.rstrip()
    cur_has_word = False
    prefix = first_prefix
    for w in words:
        candidate = (prefix if not cur_has_word else cur + " ") + w
        if not cur_has_word:
            candidate = prefix + w
        if len(candidate) <= MAX or not cur_has_word:
            cur = candidate
            cur_has_word = True
        else:
            lines.append(cur)
            cur = cont_prefix + w
            prefix = cont_prefix
            cur_has_word = True
    if cur_has_word:
        lines.append(cur)
    return lines


def reflow_paragraph(block: list[str]) -> list[str]:
    """block: consecutive `///` lines forming one paragraph (no blank ///)."""
    indent = doc_indent(block[0])
    base_prefix = f"{indent}/// "

    first_content = content_after_marker(block[0])
    m = ITEM_RE.match(first_content)
    aside_m = re.match(r"^\s*>\s*", first_content)
    if m:
        # list/param item: preserve the item's own leading indentation (nested
        # sub-items under `- Parameters:` sit at +2), and hang continuation lines to
        # align under the text following the `- ` marker (the repo's convention).
        raw_leading = first_content[: len(first_content) - len(first_content.lstrip(" "))]
        extra = max(0, len(raw_leading) - 1)  # indentation beyond the standard `/// `
        first_prefix = base_prefix + " " * extra
        cont_prefix = base_prefix + " " * extra + "  "  # +2 to clear the `- `
        item_text = strip_ascii(first_content)  # e.g. "- Parameter foo: bar baz"
        rest = [strip_ascii(content_after_marker(l)) for l in block[1:]]
        words = split_words(" ".join([item_text] + rest))
        return wrap_words(words, first_prefix, cont_prefix)
    elif aside_m:
        # callout aside (`> Tip:`, `> Note:`, ...): keep `> ` on the first line only;
        # continuation lines are plain `/// text` (matches the repo convention).
        first_prefix = f"{indent}/// > "
        cont_prefix = f"{indent}/// "
        body = strip_ascii(first_content[aside_m.end():])
        rest = [strip_ascii(content_after_marker(l)) for l in block[1:]]
        words = split_words(" ".join([body] + rest))
        return wrap_words(words, first_prefix, cont_prefix)
    else:
        # plain prose
        words = split_words(" ".join(strip_ascii(content_after_marker(l)) for l in block))
        if not words:
            return [f"{indent}///"]
        return wrap_words(words, base_prefix, base_prefix)


def is_code_line(line: str) -> bool:
    """Indented code example: `///` followed by >= 5 spaces (i.e. 4+ after the space)."""
    c = content_after_marker(line)
    return c.startswith("     ") or c.startswith("\t") or c.startswith("    \t")


def has_url(line: str) -> bool:
    return bool(URL_RE.search(line))


def reflow_doc_group(group: list[str]) -> list[str]:
    """Process one run of consecutive `///` lines."""
    out: list[str] = []
    i = 0
    n = len(group)
    while i < n:
        line = group[i]
        c = content_after_marker(line)
        stripped = c.strip()
        # blank /// line
        if stripped == "":
            out.append(f"{doc_indent(line)}///")
            i += 1
            continue
        # preserved lines: code examples, table rows, or URL-bearing lines
        if is_code_line(line) or stripped.startswith("|") or has_url(line):
            out.append(line.rstrip())
            i += 1
            continue
        # gather this paragraph: consecutive non-blank prose/list/aside lines that
        # are not themselves preserved. A paragraph starts at a prose line, a list
        # item (`- `), or an aside (`> `), and continues through plain wrapped lines.
        para = [line]
        j = i + 1
        while j < n:
            nl = group[j]
            nc = content_after_marker(nl)
            ns = nc.strip()
            if ns == "":
                break
            if is_code_line(nl) or ns.startswith("|") or has_url(nl):
                break
            # a new list item or a new aside starts a new paragraph
            if ITEM_RE.match(nc) or ns.startswith(">"):
                break
            para.append(nl)
            j += 1
        out.extend(reflow_paragraph(para))
        i = j
    return out


def process(text: str) -> str:
    lines = text.split("\n")
    out: list[str] = []
    i = 0
    n = len(lines)
    while i < n:
        if is_doc(lines[i]):
            j = i
            while j < n and is_doc(lines[j]):
                j += 1
            out.extend(reflow_doc_group(lines[i:j]))
            i = j
        else:
            out.append(lines[i])
            i += 1
    return "\n".join(out)


# --- Markdown mode (.docc articles) -----------------------------------------

MD_ITEM_RE = re.compile(r"^(\s*)([-*+]\s+|\d+\.\s+)")
MD_ASIDE_RE = re.compile(r"^\s*>\s*")


def md_wrap(words: list[str], first_prefix: str, cont_prefix: str) -> list[str]:
    lines: list[str] = []
    cur = ""
    has = False
    prefix = first_prefix
    for w in words:
        candidate = (prefix + w) if not has else (cur + " " + w)
        if len(candidate) <= MAX or not has:
            cur = candidate
            has = True
        else:
            lines.append(cur)
            cur = cont_prefix + w
            has = True
    if has:
        lines.append(cur)
    return lines


def process_markdown(text: str) -> str:
    lines = text.split("\n")
    out: list[str] = []
    i = 0
    n = len(lines)
    in_fence = False
    while i < n:
        line = lines[i]
        stripped = line.strip()
        # fenced code blocks: pass through untouched
        if stripped.startswith("```") or stripped.startswith("~~~"):
            in_fence = not in_fence
            out.append(line)
            i += 1
            continue
        if in_fence:
            out.append(line)
            i += 1
            continue
        # preserved: blank, headings, tables, URL-bearing lines, indented code
        if (
            stripped == ""
            or stripped.startswith("#")
            or stripped.startswith("|")
            or has_url(line)
            or (line.startswith("    ") and not MD_ITEM_RE.match(line))
        ):
            out.append(line.rstrip())
            i += 1
            continue
        item = MD_ITEM_RE.match(line)
        aside = MD_ASIDE_RE.match(line)
        if item:
            lead = item.group(1)
            marker = item.group(2)
            first_prefix = f"{lead}{marker}"
            cont_prefix = f"{lead}{' ' * len(marker)}"
            body = strip_ascii(line[item.end():])
            words = split_words(body)
            # gather continuation lines belonging to this item (plain wrapped prose)
            j = i + 1
            while j < n:
                nl = lines[j]
                ns = nl.strip()
                if ns == "" or nl.strip().startswith("#") or MD_ITEM_RE.match(nl) \
                        or MD_ASIDE_RE.match(nl) or has_url(nl) or ns.startswith("```"):
                    break
                words += split_words(strip_ascii(nl))
                j += 1
            out.extend(md_wrap(words, first_prefix, cont_prefix))
            i = j
        elif aside:
            # blockquote / callout: keep `> ` on the first line; wrapped lines use
            # CommonMark lazy continuation (no marker) so the content is unchanged.
            first_prefix = "> "
            cont_prefix = ""
            words = split_words(strip_ascii(line[aside.end():]))
            j = i + 1
            while j < n:
                nl = lines[j]
                ns = nl.strip()
                if ns == "" or nl.strip().startswith("#") or MD_ITEM_RE.match(nl) \
                        or has_url(nl) or ns.startswith("```"):
                    break
                m2 = MD_ASIDE_RE.match(nl)
                words += split_words(strip_ascii(nl[m2.end():] if m2 else nl))
                j += 1
            out.extend(md_wrap(words, first_prefix, cont_prefix))
            i = j
        else:
            # plain prose paragraph
            words = split_words(strip_ascii(line))
            j = i + 1
            while j < n:
                nl = lines[j]
                ns = nl.strip()
                if ns == "" or nl.strip().startswith("#") or MD_ITEM_RE.match(nl) \
                        or MD_ASIDE_RE.match(nl) or has_url(nl) or ns.startswith("```") \
                        or nl.startswith("    "):
                    break
                words += split_words(strip_ascii(nl))
                j += 1
            out.extend(md_wrap(words, "", ""))
            i = j
    return "\n".join(out)


def main() -> int:
    apply = "--apply" in sys.argv
    paths = [a for a in sys.argv[1:] if not a.startswith("--")]
    changed = 0
    for path in paths:
        original = open(path, encoding="utf-8").read()
        if path.endswith(".md"):
            updated = process_markdown(original)
        else:
            updated = process(original)
        if updated != original:
            changed += 1
            if apply:
                open(path, "w", encoding="utf-8").write(updated)
                print(f"reflowed {path}")
            else:
                print(f"would reflow {path}")
    print(f"{changed} file(s) {'changed' if apply else 'to change'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
