# Network contract v1
ReplicatedStorage.MutantLab.Shared contains shared modules. Server creates ReplicatedStorage.MutantLab.Remotes before clients initialize.
RemoteFunctions: GetState() and RequestAction(action, payload).
RemoteEvent: StateChanged(snapshot, notice?), server → owning client only.
Allowed actions: CreateBlob (no payload), Merge ({FirstId, SecondId}), StartBattle ({MutantId}), ReleaseMutant ({MutantId}). Release frees a slot without refund, requires tutorial complete, cannot remove last mutant or battling mutant. UI must confirm release.
Every response: {Ok: boolean, Code: string, State: Snapshot?}. Codes: OK, NOT_READY, RATE_LIMITED, INVALID_REQUEST, INSUFFICIENT_FUNDS, INVENTORY_FULL, INVALID_MERGE, MUTANT_NOT_FOUND, MUTANT_BUSY, BATTLE_RUNNING, TUTORIAL_REQUIRED, LAST_MUTANT, INTERNAL_ERROR.
Snapshot: {BioCoins, SlotsUnlocked, Mutants = {{Id, Type, Tier, Level}}, Tutorial = {Started, FreeBlobsClaimed, FirstBlobCreated, FirstMergeCompleted, FirstBattleStarted, FirstBattleCompleted, FirstBlobPurchased, TutorialCompleted}, Battle = false | {Id, MutantId, StartedAt, EndsAt, Reward}, Revision: number, PersistenceMode: string}.
Battle timestamps use workspace:GetServerTimeNow() seconds; no battle is false. Mutants are ordered arrays. Snapshots are copies; session token and stored lock must never be transmitted.
StateChanged notice: {Code = "BATTLE_COMPLETE", Reward = number}. Revision increases within session. UI ignores older snapshots.
No caller-supplied user ID, amount, price, type or reward. Server validates types and lengths. Shared rate limit applies to both functions.
First two successful creates are free (persisted count), never replenish on reconnect. First battle requires tutorial merge; tutorial completes on ToxicBlob battle reward. No merge/release involving battling mutant. One active battle per player; no client completion remote.

