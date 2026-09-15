---
title: Writing in Markdown
order: 4
---

# Writing in Markdown

In **Edit mode**, you write Markdown — plain text with a few additions for formatting. In **View mode**, Clearance shows it formatted. Here's the syntax you'll reach for most.

## Headings

Start a line with one to six `#` characters and a space. More hashes means a smaller heading, from `#` down to `######`.

```
# Title
## Section
### Subsection
```

## Emphasis

Wrap text in `**bold**` for bold, `*italic*` for italic, and `~~strikethrough~~` for strikethrough.

## Line breaks

A blank line starts a new paragraph. To force a line break within a paragraph, end a line with two spaces, or with a backslash `\`.

## Lists

Start each item with `-` and a space for an unordered list:

```
- First
- Second
```

Use `1.` (and so on) for an ordered list:

```
1. First
2. Second
```

## Links

Write the link text in square brackets, then the address in parentheses: `[text](https://example.com)`. To link to another file, point at its path instead: `[the welcome topic](01-welcome.md)`.

## Images

To insert an image, write a link with a `!` in front: `![description](path/to/image.png)`. The text in brackets is the image's alternative text, describing it for anyone who can't see it.

## Code

For a few words of code, wrap them in single backticks: `` `code` ``. For a whole block, fence it between lines of triple backticks. Name the language after the opening fence to get syntax highlighting:

````
```swift
let greeting = "Hello"
```
````

Fenced code blocks get syntax highlighting for common languages — Swift, JavaScript/TypeScript, JSON, shell, and YAML — with basic highlighting for others.

## Blockquotes

Start a line with `>` to quote it:

```
> A quoted line.
```

## Horizontal rule

Put `---` on its own line to draw a divider across the page.

## Tables

Separate columns with pipes `|`, then add a `|---|---|` row to mark the header:

```
| Name  | Role   |
|-------|--------|
| Ada   | Author |
```

To align a column, add colons to its cell in the separator row: `:---` for left, `:---:` for center, and `---:` for right.

When you're ready for more, [Rich Markdown Rendering](05-rich-rendering.md) covers the richer features Clearance renders — math, diagrams, task lists, and frontmatter.
