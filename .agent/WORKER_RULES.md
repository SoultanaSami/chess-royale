# Delegated task contract

- Work only on the stated objective and assigned paths. Ask the orchestrator before expanding scope or changing a shared file outside that boundary.
- Read only the code needed for the task; prefer searches and ranges of at most about 120 lines. Refer to files in handoffs instead of pasting large source blocks.
- Do not overlap another agent's write scope. Preserve existing work and avoid unrelated formatting or refactors.
- Never reset or modify the persistent database. Browser checks must use an in-memory server and must preserve existing `test-results/` screenshots.
- Run only the smallest relevant existing validation. Do not reinstall dependencies or repeat a check that already has a clear result.

## Handoff

Report the outcome, changed paths, validation command and result (or why it was not run), and any remaining risk. Keep it concise and do not claim unverified behavior.
