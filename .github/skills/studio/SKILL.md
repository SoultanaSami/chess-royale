---
name: studio
description: "Use when the user invokes /studio or asks for iterative Chess Royale product refinement with evidence-based playtesting, scoring, and safe checkpoints."
argument-hint: "A specific gameplay, UI, accessibility, or reliability objective"
---

# Chess Royale Studio

Run a bounded improve–test–critique loop. This workflow is explicit; do not start it for ordinary coding requests.

## Procedure

1. **Set the objective.** Use the user's stated goal and constraints. If the objective is missing or requires a product decision, ask before editing. Read [workspace guidance](../../copilot-instructions.md), the [project roadmap](../../../README.md), [worker rules](../../../.agent/WORKER_RULES.md), and [STATE.md](../../../STATE.md).
2. **Establish a baseline.** Inspect only the relevant feature and tests. Use current code and reproducible checks; do not treat old screenshots or roadmap headings as proof of completion. The browser interface exposes `window.chessRoyale.getState()`; reuse the existing Playwright checks rather than adding generic `__GAME_STATE__` or `__AUTOPLAY__` hooks.
3. **Choose one bounded change.** Tie it to the objective and the README roadmap. Delegate implementation only when file ownership is independent; give each specialist a clear scope and handoff. Prefer no more than three main-thread edit batches per round.
4. **Implement and verify.** Preserve current behavior outside the objective. Run the smallest relevant checks and use an in-memory database for browser tests. Browser scripts write fixed screenshots under `test-results/`; preserve existing captures and do not include generated images unless requested.
5. **Critique with evidence.** For product-wide refinement, evaluate rules/gameplay, mobile interaction, visual clarity, accessibility, and reliability. Score each from 1–10 only when evidence exists; mark untested dimensions unassessed. For a narrowly scoped task, evaluate only relevant dimensions and do not expand scope just to raise unrelated scores.
6. **Checkpoint and decide.** Update `STATE.md` with the objective, changed paths, evidence, scores, and next step. Continue a product-wide cycle while a relevant score is below 8/10, up to three rounds; then stop and report the remaining gap or ask for direction. Stop sooner if the objective is met, validation is blocked, context is becoming constrained, or further work needs a product decision.

## Validation

- Unit/server suite: `PATH="$PWD/.runtime/bin:$PATH" npm test` when the project runtime exists; otherwise `npm test` with Node.js 24+.
- Browser checks require a server at port 3000. Start `DB_PATH=:memory: PORT=3000 sh scripts/start.sh` in a separate terminal, then run the relevant existing `node scripts/check-ui.mjs`, `node scripts/check-polish.mjs`, or `node scripts/check-frame.mjs` command.
- The browser scripts overwrite same-named images in `test-results/`. Preserve and restore existing captures when they are not part of the requested deliverable. If Chromium or another required tool is unavailable, report that limitation; do not install it as a workaround.

## Safe stops

Stop before touching persistent user data, changing provider configuration, adding dependencies, making a broad gameplay or visual direction choice, or continuing past the stated objective. Report unverified behavior as unverified.
