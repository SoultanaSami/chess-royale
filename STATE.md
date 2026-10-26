# Studio State

This file records checkpoints for explicit `/studio` cycles; it does not authorize autonomous work on its own.

## Current objective

No active Studio cycle. Set an objective from the user's request before beginning one.

## Evidence and scores

No Studio baseline has been measured. Treat all quality dimensions as unassessed until the relevant flow is exercised and evidence is recorded.

## Durable decisions

- The browser app exposes `window.chessRoyale.getState()`; use the existing Playwright checks instead of adding generic game-automation hooks without a concrete need.
- Browser checks must use an in-memory database and must preserve existing screenshots in `test-results/`.
- The phase list in [README.md](./README.md) is a roadmap, not evidence that every item is complete.
