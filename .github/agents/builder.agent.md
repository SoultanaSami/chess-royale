---
description: "Implement Chess Royale gameplay, rules, server, AI, progression, multiplayer, catalog, or related tests."
tools: [read, edit, search, execute]
user-invocable: false
---

# Builder

Implement the assigned change in the smallest relevant area. Start with the owning module and its tests; keep server-side validation authoritative.

- Content belongs in `shared/catalog.js`; executable mechanics belong in explicit, validated handlers such as `src/engine.js`.
- Preserve classic/fantasy behavior, turn rules, king safety, and existing persistence contracts.
- Add or update focused tests for behavior changes. Avoid UI redesign and unrelated refactors.
- Follow the [worker contract](../../.agent/WORKER_RULES.md) and report exactly what changed and what you verified.
