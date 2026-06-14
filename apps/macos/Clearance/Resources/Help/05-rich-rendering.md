---
title: Rich Markdown Rendering
order: 5
---

# Rich Markdown Rendering

Clearance opens both plain-text and Markdown files, and in **View mode** it renders the full range of Markdown. Here's what you'll see formatted on the page:

- Standard Markdown: headings, lists, links, block quotes, and inline code.
- YAML frontmatter, shown as a tidy summary at the top of the document.
- GitHub-style tables, with column alignment respected.
- Task lists, where `- [ ]` and `- [x]` become checkboxes.
- Fenced code blocks, with syntax highlighting for the language you name.
- Math, typeset with KaTeX.
- Diagrams, drawn with Mermaid and Graphviz.

For the basics of writing Markdown, see [Writing in Markdown](04-writing-in-markdown.md).

For math, Clearance uses KaTeX: write a displayed equation with `$$…$$`, write inline math with `\(…\)`, or put an equation in a ```` ```math ```` code block. For the full list of what KaTeX understands, see the [KaTeX supported functions](https://katex.org/docs/supported.html).

For diagrams, Clearance draws two kinds:

- [Mermaid](https://mermaid.js.org/), in a ```` ```mermaid ```` block.
- [Graphviz](https://graphviz.org/), in a ```` ```dot ```` or ```` ```graphviz ```` block.

Click any diagram to expand it; it opens in a larger overlay so you can see the detail.
