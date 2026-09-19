---
name: mutant-lab-development
description: Continue implementation or acceptance of this Mutant Lab Roblox repository using its saved milestones, network contract, and verification record. Use for this project's code or handoff, not general Roblox market research.
---

# Mutant Lab continuation
Read AGENTS.md and docs/STATUS.md from the repository root, then the current milestone in docs/ROADMAP.md. Read docs/NETWORK.md before changing either client or server. Use docs/HANDOFF.md when taking over or preparing a handoff.

Preserve these project-specific invariants:
- Exactly two tutorial Blobs over the lifetime of a profile. Reconnect is not another grant.
- No yield inside gameplay mutations. Persistence and analytics do not participate in the in-memory transaction.
- Only the server's battle record determines completion and reward. Cancel pending battle on leave.
- Studio memory mode is the default. Persistent tests need a separate test experience; a second place in a production experience is insufficient isolation.
- Failed/corrupt/future-version loads must not be saved as a fresh profile. A stale session must never overwrite a newer owner.
- Two tiers cannot merge forever. Preserve a usable inventory escape via confirmed release, with no refund and no release of the last or battling mutant.
- All delegated subagents use gpt-5.6-sol as requested by the project owner.

Use scripts/check.ps1 for automation. It runs formatting, Lune tests and Rojo build; it does not certify Studio GUI, engine APIs, real DataStore concurrency or analytics delivery. Follow docs/MANUAL_TESTS.md for those checks. Add regression tests for meaningful economy/security changes.

Before ending, update docs/STATUS.md with actual evidence, unverified scenarios and one concrete next task. Keep architectural decisions in docs/ARCHITECTURE.md and changed contracts in docs/NETWORK.md so another agent does not need the chat history. Do not widen v0.1 to paid purchases or trading during routine fixes.
