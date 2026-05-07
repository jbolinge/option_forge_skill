#!/usr/bin/env python3
"""Fetch option-forge.com/docs/ and convert to markdown.

Mirrors the page's own "Download Docs as Markdown" button, which walks the
rendered DOM and emits markdown. We replicate the same conversion in Python
so the snapshot at docs/option-forge-docs.md can be refreshed without a
browser.

Usage: python3 tools/fetch_docs.py [out_path]
"""
from __future__ import annotations

import re
import sys
import urllib.request
from html.parser import HTMLParser
from pathlib import Path

DOCS_URL = "https://option-forge.com/docs/"
DEFAULT_OUT = Path(__file__).resolve().parent.parent / "docs" / "option-forge-docs.md"

VOID = {"br", "img", "hr", "meta", "link", "input"}


class Node:
    __slots__ = ("tag", "attrs", "children", "text")

    def __init__(self, tag: str | None, attrs: dict | None = None, text: str | None = None):
        self.tag = tag
        self.attrs = attrs or {}
        self.children: list[Node] = []
        self.text = text

    def classes(self) -> set[str]:
        return set((self.attrs.get("class") or "").split())

    def find_first(self, tag: str) -> "Node | None":
        for c in self.children:
            if c.tag == tag:
                return c
            r = c.find_first(tag)
            if r:
                return r
        return None

    def text_content(self) -> str:
        if self.text is not None:
            return self.text
        return "".join(c.text_content() for c in self.children)


class TreeBuilder(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.root = Node(None)
        self.stack: list[Node] = [self.root]

    def handle_starttag(self, tag, attrs):
        node = Node(tag, dict(attrs))
        self.stack[-1].children.append(node)
        if tag not in VOID:
            self.stack.append(node)

    def handle_endtag(self, tag):
        for i in range(len(self.stack) - 1, 0, -1):
            if self.stack[i].tag == tag:
                del self.stack[i:]
                return

    def handle_startendtag(self, tag, attrs):
        self.stack[-1].children.append(Node(tag, dict(attrs)))

    def handle_data(self, data):
        self.stack[-1].children.append(Node(None, text=data))


WS = re.compile(r"\s+")


def inline_md(node: Node) -> str:
    if node.text is not None:
        return WS.sub(" ", node.text)
    if node.tag is None:
        return "".join(inline_md(c) for c in node.children)

    tag = node.tag
    cls = node.classes()
    inner = "".join(inline_md(c) for c in node.children)

    if tag == "code" or "inline-code" in cls:
        # JS uses node.textContent (no whitespace collapse) for code spans.
        return f"`{node.text_content()}`"
    if tag in ("strong", "b"):
        return f"**{inner}**"
    if tag in ("em", "i"):
        return f"_{inner}_"
    if tag == "a":
        return f"[{inner}]({node.attrs.get('href', '')})"
    return inner


def is_block(child: Node) -> bool:
    return child.tag in ("h1", "h2", "h3", "h4", "p", "ul", "pre", "div", "section")


def block_md(node: Node) -> str:
    if node.tag in ("h1", "h2", "h3", "h4"):
        level = int(node.tag[1])
        return f"{'#' * level} {inline_md(node).strip()}"
    if node.tag == "p":
        return inline_md(node).strip()
    if node.tag == "ul":
        items = [f"- {inline_md(c).strip()}" for c in node.children if c.tag == "li"]
        return "\n".join(items)
    if node.tag == "pre":
        code = node.text_content().rstrip("\n")
        lang = ""
        code_el = node.find_first("code")
        if code_el is not None:
            m = re.search(r"language-(\w+)", code_el.attrs.get("class", ""))
            if m:
                lang = m.group(1)
        return f"```{lang}\n{code}\n```"
    if "download-docs" in node.classes() or node.tag == "script":
        return ""

    blocks: list[str] = []
    inline = ""
    for child in node.children:
        if is_block(child):
            if inline.strip():
                blocks.append(inline.strip())
            inline = ""
            b = block_md(child)
            if b:
                blocks.append(b)
        else:
            inline += inline_md(child)
    if inline.strip():
        blocks.append(inline.strip())
    return "\n\n".join(blocks)


def fetch_html(url: str = DOCS_URL) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "option-forge-skill/fetch_docs"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode("utf-8")


def html_to_md(html: str) -> str:
    builder = TreeBuilder()
    builder.feed(html)
    body = builder.root.find_first("body") or builder.root
    parts = [block_md(c) for c in body.children]
    return "\n\n".join(p for p in parts if p) + "\n"


def main(argv: list[str]) -> int:
    out = Path(argv[1]) if len(argv) > 1 else DEFAULT_OUT
    out.parent.mkdir(parents=True, exist_ok=True)
    md = html_to_md(fetch_html())
    out.write_text(md, encoding="utf-8")
    print(f"Wrote {out} ({len(md):,} chars)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
