# Chess Royale agent guidelines

## Project map

- Chess Royale is a Node.js 24+ server-authoritative chess game and PWA. See [README.md](../README.md) for setup, rules, and the product roadmap.
- `shared/catalog.js` defines game content; `src/engine.js` owns validated game mechanics. `src/` contains server and game logic, `public/` the browser app, and `test/` the automated suite.
- `scripts/check-ui.mjs`, `scripts/check-polish.mjs`, and `scripts/check-frame.mjs` exercise the browser UI with Playwright.

## Change guardrails

- Treat the server as authoritative. Keep client actions within the server-approved action model.
- Catalog data does not execute arbitrary code. A new mechanic needs an explicit handler and tests; kings cannot be removed by magic or area damage.
- Preserve the classic and fantasy modes as separate behaviors. Avoid unrelated changes to persisted accounts or games in `data/chess-royale.sqlite`.
- There is no frontend build step. Follow existing JavaScript and CSS patterns instead of introducing tooling for convenience.

## Validation

- Run `PATH="$PWD/.runtime/bin:$PATH" npm test` when the local Node runtime exists; otherwise use Node.js 24+ and `npm test`.
- Browser scripts expect a server at port 3000. Start it with an in-memory database using `DB_PATH=:memory: PORT=3000 sh scripts/start.sh`, then run the relevant script in another terminal.
- Those scripts overwrite same-named screenshots in `test-results/`. Preserve existing captures and do not include generated screenshots in changes unless requested.
- Do not run browser checks against the default persistent database. Do not install dependencies unless a manifest changes or a required tool is missing.

## Context discipline

- Keep investigations bounded: search first and read no more than about 120 lines at a time. Prefer concise command output and targeted ranges.
- Reserve roughly 40% of the available context for implementation, validation, and handoff. Prefer at most three main-thread edit batches; split only clearly independent work.
- Use the [worker handoff contract](../.agent/WORKER_RULES.md) when delegating. Do not overlap delegated write scopes.
- Use `STATE.md` only for an explicit `/studio` cycle; never invent scores or claim validation without evidence.

## Copilot workflow

- Use `orchestrator` for coordination. Specialist profiles are hidden from the picker and should be called only for bounded work.
- `/studio` is an explicit iterative improvement workflow, not the default for ordinary requests. `/direction` records an explicitly provided visual direction; it does not authorize unrelated implementation.
- Profiles intentionally omit provider-specific model IDs and apply only to this workspace.
