# Network contract (v1 & v2)
ReplicatedStorage.MutantLab.Shared contains shared modules. Server creates ReplicatedStorage.MutantLab.Remotes before clients initialize.
RemoteFunctions: GetState() and RequestAction(action, payload).
RemoteEvent: StateChanged(snapshot, notice?), server → owning client only.

## Allowed Actions:
- **v1 Actions**:
  - `CreateBlob` (no payload)
  - `Merge` ({FirstId, SecondId})
  - `StartBattle` ({MutantId})
  - `ReleaseMutant` ({MutantId})
- **v2 Actions (Expeditions & Genetics)**:
  - `BreedMutants` ({FirstId, SecondId}): Risk-based breeding with gene inheritance. One mutant survives, other is consumed.
  - `StartExpedition` ({RoomCount, ActiveIds, ReserveIds?}): Starts an expedition session (3 or 5 rooms).
  - `SelectCombatAction` ({AbilityType, TargetId?}): Submits combat turn intent (Basic, RoleSkill, Ultimate).
  - `SecureLoot` (no payload): Secures all pending room loot into the intermediate terminal capsule.
  - `Evacuate` (no payload): Concludes expedition at a terminal or after boss, claims all secured loot, initiates 2-minute rest cooldown.

Every response: {Ok: boolean, Code: string, State: Snapshot?}. Codes: OK, NOT_READY, RATE_LIMITED, INVALID_REQUEST, INSUFFICIENT_FUNDS, INVENTORY_FULL, INVALID_MERGE, MUTANT_NOT_FOUND, MUTANT_BUSY, BATTLE_RUNNING, TUTORIAL_REQUIRED, LAST_MUTANT, NOT_IN_COMBAT, NOT_AT_TERMINAL, CANNOT_EVACUATE, INTERNAL_ERROR.
Snapshot: {BioCoins, SlotsUnlocked, Mutants = {{Id, Type, Tier, Level, Role?, Genes?, RestUntil?}}, Tutorial, Battle = false | PublicBattle, Expedition = false | ExpeditionSnapshot, Revision: number, PersistenceMode: string}.
No caller-supplied user ID, amount, price, type or reward. Server validates types and lengths. Shared rate limit applies to both functions.


