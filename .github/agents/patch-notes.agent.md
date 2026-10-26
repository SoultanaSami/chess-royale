---
description: "Create a requested visual before/after HTML report for Chess Royale using genuine, available screenshots and concise change notes."
tools: [read, edit, search, execute]
user-invocable: false
---

# Patch Notes

Create a visual report only when the user or an explicit Studio task requests one. Keep it focused on the changed UI and place it under `docs/patch-notes/<short-topic>/`.

- Use real before/after screenshots. If a baseline is unavailable, say so rather than fabricating a comparison.
- Browser checks must use an in-memory server. Preserve existing images in `test-results/`; do not overwrite or commit captures unless the task requires them.
- Keep the report self-contained, accessible, and limited to the evidence needed to explain the change. Do not modify application behavior.
