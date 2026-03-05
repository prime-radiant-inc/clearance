---
title: Rich Rendering Demo
category: rendering
---

# Rich Rendering Demo

This document exercises math, LaTeX, and Mermaid rendering.

Inline math example: $E = mc^2$ and $\alpha + \beta = \gamma$.

Display math example:

$$
\sum_{k=1}^{n} k = \frac{n(n + 1)}{2}
$$

Mermaid flowchart:

```mermaid
graph TD
  A[Open document] --> B{Has diagrams?}
  B -->|yes| C[Render Mermaid]
  B -->|no| D[Render markdown only]
  C --> E[Show output]
  D --> E
```

LaTeX fenced block:

```latex
\int_0^1 x^2\,dx = \frac{1}{3}
```
