---
name: mutant-lab-rules
description: Architecture rules, security model, and network contract for developing Mutant Lab scripts in Roblox Studio.
enabled: true
---

# Mutant Lab Development Rules for Roblox Studio Assistant

When generating, modifying, or reviewing Luau code for Mutant Lab, strictly follow these project rules:

## 1. Authority & State Invariants
- Currency (BioCoins), inventory, training, and rewards can ONLY be mutated on the server.
- The client sends intent and ID only (never prices, amounts, or rewards).
- Exactly two free tutorial Blobs over the lifetime of a player's profile (persisted count; reconnect is not a new grant).
- State mutations within a single operation must NOT yield (`task.wait` or async calls are forbidden inside state transitions).
- DataStore operations and analytics are strictly outside state mutation transactions.

## 2. Network Contract (ReplicatedStorage.MutantLab.Remotes)
- `GetState()`: Returns client snapshot.
- `RequestAction(action, payload)`: Allowed actions are `CreateBlob`, `Merge` (`{FirstId, SecondId}`), `StartBattle` (`{MutantId}`), `ReleaseMutant` (`{MutantId}`).
- Responses must always follow `{Ok: boolean, Code: string, State: Snapshot?}`.
- Battle timestamps use `workspace:GetServerTimeNow()`. One active battle per player; cancel pending battle on leave.

## 3. Inventory & Release
- Three tiers (Blob -> Toxic Blob -> Plasma Blob). Tutorial battles accept Toxic or Plasma; Blob requires completed tutorial.
- Releasing a mutant frees a slot without refund, requires tutorial completion, and cannot release the last remaining mutant or a mutant currently in battle.

## 4. Luau Conventions
- Use strict typing (`--!strict`) where possible.
- Use `task.spawn`, `task.delay`, and `task.defer` instead of deprecated global `spawn`/`wait`/`delay`.
- ModuleScripts use PascalCase, local variables use camelCase.
